#!/usr/bin/env python3
"""Import authentic, privately owned C&C Remastered TD artwork.

Requires Pillow (including DDS decoding). Art is never downloaded. Output contains
proprietary game artwork and MUST NOT be committed or published. Metadata follows
EA's bundled Map Editor Tileset/TextureManager/TeamColor interpretation. Atlas
rectangles retain native crops; restore at crop_x/y in canvas_w/h (128 native pixels
per classic 24-pixel cell). SOURCE pixels and exact original team parameters are
retained for runtime remapping; no generated frames or inferred animation order.
"""
import argparse
import collections
import csv
import hashlib
import io
import json
import pathlib
import struct
import xml.etree.ElementTree as ET
import zipfile
from PIL import Image


def norm(name):
    return name.replace('\\', '/').upper()


def meg_index(path):
    result = {}
    size = path.stat().st_size
    with path.open('rb') as f:
        magic, = struct.unpack('<I', f.read(4))
        f.seek(12 if magic in (0xffffffff, 0x8fffffff) else 4)
        count, strings, length = struct.unpack('<III', f.read(12))
        raw = f.read(length)
        names, pos = [], 0
        for _ in range(strings):
            n, = struct.unpack_from('<H', raw, pos)
            pos += 2
            names.append(raw[pos:pos+n].decode('utf-8'))
            pos += n
        if pos != length:
            raise ValueError('Invalid MEG string table: ' + str(path))
        for _ in range(count):
            flags, crc, idx, length, offset, ni = struct.unpack('<HIiIIH', f.read(20))
            if ni >= len(names) or offset + length > size:
                raise ValueError('Invalid MEG bounds: ' + str(path))
            result[norm(names[ni])] = (offset, length)
    return result


class Collection:
    def __init__(self, installation):
        data = next(p for p in installation.iterdir() if p.name.upper() == 'DATA')
        files = {p.name.upper(): p for p in data.iterdir() if p.is_file()}
        # Preserve the installation's MEGAFILES.XML precedence, excluding unrelated
        # movies/music, and retain later texture patch overrides.
        order = [norm(x.text.strip()).split('/')[-1] for x in ET.parse(files['MEGAFILES.XML']).getroot().findall('File')]
        wanted = [n for n in order if n == 'CONFIG.MEG' or n.startswith('TEXTURES') or n == 'UI.MEG']
        self.entries, self.handles, self.receipts = {}, {}, {}
        for name in wanted:
            if name not in files:
                continue
            path = files[name]
            self.handles[name] = path.open('rb')
            for key, location in meg_index(path).items():
                self.entries[key] = (name, location)
        self.zips = collections.OrderedDict()
        self.decode_modes = collections.Counter()

    def read(self, name):
        name = norm(name)
        archive, (offset, length) = self.entries[name]
        f = self.handles[archive]
        f.seek(offset)
        raw = f.read(length)
        if len(raw) != length:
            raise ValueError('Short MEG payload: ' + name)
        self.receipts[name] = {'archive': archive, 'offset': offset, 'bytes': length,
                               'sha256': hashlib.sha256(raw).hexdigest()}
        return raw

    def texture(self, path):
        path = norm(path)
        parent, leaf = path.rsplit('/', 1)
        archive = parent + '.ZIP'
        meta = None
        if archive in self.entries:
            if archive not in self.zips:
                z = zipfile.ZipFile(io.BytesIO(self.read(archive)))
                self.zips[archive] = (z, {norm(n): n for n in z.namelist()})
                if len(self.zips) > 4:
                    self.zips.popitem(last=False)[1][0].close()
            self.zips.move_to_end(archive)
            z, members = self.zips[archive]
            image_key = leaf if leaf in members else path
            if image_key in members:
                raw = z.read(members[image_key])
                meta_key = image_key.rsplit('.', 1)[0] + '.META'
                if meta_key in members:
                    meta = json.loads(z.read(members[meta_key]))
                mode = 'zip'
            else:
                raw = None
        else:
            raw = None
        if raw is None:
            if path in self.entries:
                raw, mode = self.read(path), 'direct'
            else:
                dds = path.rsplit('.', 1)[0] + '.DDS'
                raw, mode = self.read(dds), 'dds'
        image = Image.open(io.BytesIO(raw)).convert('RGBA')
        if meta:
            cw, ch = map(int, meta['size'])
            x, y, right, bottom = map(int, meta['crop'])
            if image.size != (right-x, bottom-y) or x < 0 or y < 0 or right > cw or bottom > ch:
                raise ValueError('Invalid native crop: ' + path)
        else:
            cw, ch = image.size
            x = y = 0
        if cw <= 0 or ch <= 0:
            raise ValueError('Empty native canvas: ' + path)
        # Retain full source crop; no alpha trimming/recentering changes pivots.
        self.decode_modes[mode] += 1
        return image, (cw, ch, x, y), mode


class Atlas:
    def __init__(self, output, prefix, edge):
        self.output, self.prefix, self.edge = output, prefix, edge
        self.pages, self.image = [], None
        self.x = self.y = self.row_h = self.used_w = self.used_h = 0

    def flush(self):
        if self.image is None:
            return
        name = f'{self.prefix}-{len(self.pages):04d}.png'
        image = self.image.crop((0, 0, self.used_w, self.used_h))
        target = self.output / name
        image.save(target, compress_level=3)
        self.pages.append({'file': name, 'width': image.width, 'height': image.height,
                           'bytes': target.stat().st_size,
                           'sha256': hashlib.sha256(target.read_bytes()).hexdigest()})
        self.image = None
        self.x = self.y = self.row_h = self.used_w = self.used_h = 0

    def add(self, image):
        w, h = image.size
        if w + 2 > self.edge or h + 2 > self.edge:
            raise ValueError(f'Texture {w}x{h} exceeds atlas {self.edge}')
        if self.x + w + 2 > self.edge:
            self.x, self.y, self.row_h = 0, self.y + self.row_h, 0
        if self.y + h + 2 > self.edge:
            self.flush()
        if self.image is None:
            self.image = Image.new('RGBA', (self.edge, self.edge))
        name = f'{self.prefix}-{len(self.pages):04d}.png'
        x, y = self.x + 1, self.y + 1
        self.image.paste(image, (x, y))
        self.x += w + 2
        self.row_h = max(self.row_h, h + 2)
        self.used_w, self.used_h = max(self.used_w, x+w+1), max(self.used_h, y+h+1)
        return name, x, y, w, h


FIELDS = ['tileset', 'asset', 'shape', 'animation_index', 'fps', 'team', 'page', 'x', 'y', 'w', 'h',
          'canvas_w', 'canvas_h', 'crop_x', 'crop_y', 'source_filename']
TEAM_FIELDS = [('LowerBounds', 'RGB'), ('UpperBounds', 'RGB'), ('Fudge', ''), ('HSVShift', 'XYZ'),
               ('InputLevels', 'XYZ'), ('OutputLevels', 'XY'), ('OverallInputLevels', 'XYZ'),
               ('OverallOutputLevels', 'XY')]


def teams(collection, output):
    raw = collection.read('DATA/XML/CNCTDTEAMCOLORS.XML')
    (output / 'CNCTDTEAMCOLORS.XML').write_bytes(raw)
    root = ET.fromstring(raw)
    by_name = {n.attrib['Name']: n for n in root}
    def value(name, tag, keys):
        node = by_name[name]
        element = node.find(tag)
        if element is None:
            parent = node.get('Variant')
            return value(parent, tag, keys) if parent else [0.] * (len(keys) or 1)
        return [float(element.findtext(k)) for k in keys] if keys else [float(element.text)]
    with (output / 'teams.tsv').open('w', newline='') as f:
        writer = csv.writer(f, delimiter='\t', lineterminator='\n')
        writer.writerow(['team'] + [tag + ('.' + k if k else '') for tag, keys in TEAM_FIELDS for k in (keys or [''])])
        for name in by_name:
            writer.writerow([name] + [v for tag, keys in TEAM_FIELDS for v in value(name, tag, keys)])


def mappings(collection):
    result = []
    names = sorted(n for n in collection.entries if '/TILESETS/TD_' in n and n.endswith('.XML'))
    for name in names:
        root = ET.fromstring(collection.read(name))
        for tileset in root.findall('TilesetTypeClass'):
            prefix = 'DATA/ART/TEXTURES/SRGB/' + norm(tileset.findtext('RootTexturePath')).strip('/') + '/'
            for tile in tileset.findall('Tiles/Tile'):
                asset = tile.findtext('Key/Name').upper()
                shape = int(tile.findtext('Key/Shape'))
                fps = float(tile.findtext('Value/AnimationData/FPS') or 0)
                frames = [n.text or '' for n in tile.findall('Value/Frames/Frame')]
                for i, frame in enumerate(frames):
                    result.append((tileset.attrib['name'], asset, shape, i, fps, prefix + norm(frame) if frame else ''))
    return sorted(result, key=lambda x: (x[0], x[1], x[2], x[3]))


def import_ui(collection, output, edge):
    """Decode original MTD atlas geometry and XML build-icon assignments."""
    atlas_name = 'DATA/ART/TEXTURES/SRGB/MT_COMMANDBAR_COMMON.TGA'
    raw = collection.read(atlas_name.rsplit('.', 1)[0] + '.MTD')
    version, count = struct.unpack_from('<ii', raw)
    if version != -2:
        raise ValueError('Unsupported MTD version')
    pos, records = 8, {}
    for _ in range(count):
        length, = struct.unpack_from('<I', raw, pos)
        pos += 4
        name = norm(raw[pos:pos+length].split(b'\0', 1)[0].decode())
        pos += length
        vals = struct.unpack_from('<8I', raw, pos)
        pos += 32
        flag = raw[pos]
        pos += 1
        records[name] = (*vals, flag)
    if pos != len(raw):
        raise ValueError('MTD trailing bytes')
    # Pillow normalizes TGA bottom-left origin to top-left. MTD y is top-left.
    source = Image.open(io.BytesIO(collection.read(atlas_name))).convert('RGBA')
    root = ET.fromstring(collection.read('DATA/XML/OBJECTS/UNITS/CNCBUILDABLES.XML'))
    atlas = Atlas(output, 'td_ui', edge)
    rows, mapped, errors = [], set(), []
    for node in root.findall('ObjectTypeClass'):
        classic = node.get('Name', '')
        icon = node.findtext('CNCEncyclopediaComponent/BuildIcon')
        if not classic.startswith('TD_') or not icon:
            continue
        key = norm(icon) + '.TGA'
        if key not in records:
            errors.append({'asset': classic, 'error': 'Build icon absent from MTD: ' + key})
            continue
        x, y, w, h, cx, cy, cw, ch, flag = records[key]
        if x+w > source.width or y+h > source.height or cx+w > cw or cy+h > ch:
            raise ValueError('MTD crop outside bounds: ' + key)
        rect = atlas.add(source.crop((x, y, x+w, y+h)))
        rows.append(['TD_UI', 'ICON.' + classic[3:].upper(), 0, 0, 0, 'SOURCE',
                     *rect, cw, ch, cx, cy, atlas_name + '#' + key])
        mapped.add(key)
    atlas.flush()
    return rows, atlas.pages, errors, sorted(k for k in records if k.startswith('BUILDICON_TD_') and k not in mapped)


def append_ui(collection, output, edge):
    report_path = output / 'coverage.json'
    report = json.loads(report_path.read_text())
    if 'TD_UI' in report['tilesets']:
        raise ValueError('Sidebar has already been imported')
    rows, pages, errors, unmapped = import_ui(collection, output, edge)
    with (output / 'frames.tsv').open('a', newline='') as f:
        csv.writer(f, delimiter='\t', lineterminator='\n').writerows(rows)
    report['pages'].extend(pages)
    report['tilesets']['TD_UI'] = {'references': len(rows) + len(errors), 'mapped': len(rows), 'unresolved': len(errors)}
    report['totals']['mapped'] += len(rows)
    report['totals']['unique_decoded'] += len(rows)
    report['references'] += len(rows) + len(errors)
    report['unresolved'].extend(errors)
    report['sidebar_icons_without_buildable_mapping'] = unmapped
    report['scope'] = 'All TD Map Editor tilesets and XML-mapped sidebar build icons. Original UI layout retained.'
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    provenance_path = output / 'provenance.json'
    provenance = json.loads(provenance_path.read_text())
    provenance.update(collection.receipts)
    provenance_path.write_text(json.dumps(provenance, indent=2) + '\n')
    print('Sidebar:', len(rows), 'exact XML mappings;', len(errors), 'unresolved;', len(unmapped), 'unassigned source icons', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation', type=pathlib.Path)
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--atlas-size', type=int, choices=[1024, 2048, 4096], default=2048)
    parser.add_argument('--metadata-only', action='store_true')
    parser.add_argument('--append-ui', action='store_true', help='Add exact sidebar mappings to a completed private tileset import')
    parser.add_argument('--tileset', action='append', help='Optional exact tileset filter for bounded validation')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.append_ui:
        append_ui(Collection(args.installation), args.output, args.atlas_size)
        return
    if (args.output / 'frames.tsv').exists():
        parser.error('Output already contains frames.tsv; choose a fresh directory to preserve prior assets')
    collection = Collection(args.installation)
    rows = mappings(collection)
    if args.tileset:
        rows = [r for r in rows if r[0] in args.tileset]
    teams(collection, args.output)
    with (args.output / 'mapping.tsv').open('w', newline='') as f:
        w = csv.writer(f, delimiter='\t', lineterminator='\n')
        w.writerow(['tileset', 'asset', 'shape', 'animation_index', 'fps', 'source_filename'])
        w.writerows(rows)
    if args.metadata_only:
        print(json.dumps({'references': len(rows), 'tilesets': sorted({r[0] for r in rows})}))
        return
    missing, pages, totals = [], [], collections.Counter()
    cached, atlas, previous = {}, None, None
    per_tileset = {}
    with (args.output / 'frames.tsv').open('w', newline='') as f:
        writer = csv.writer(f, delimiter='\t', lineterminator='\n')
        writer.writerow(FIELDS)
        for tileset, asset, shape, ai, fps, path in rows:
            if tileset != previous:
                if atlas:
                    atlas.flush()
                    pages.extend(atlas.pages)
                    print(previous, dict(per_tileset[previous]), flush=True)
                atlas = Atlas(args.output, tileset.lower(), args.atlas_size)
                cached, previous = {}, tileset
                per_tileset[tileset] = collections.Counter()
            count = per_tileset[tileset]
            count['references'] += 1
            if not path:
                totals['intentional_blank'] += 1
                count['intentional_blank'] += 1
                writer.writerow([tileset, asset, shape, ai, fps, 'SOURCE', '-', 0, 0, 0, 0, 0, 0, 0, 0, ''])
                continue
            try:
                if path not in cached:
                    image, crop, mode = collection.texture(path)
                    cached[path] = (*atlas.add(image), *crop)
                    count['unique_decoded'] += 1
                    totals['unique_decoded'] += 1
                writer.writerow([tileset, asset, shape, ai, fps, 'SOURCE', *cached[path], path])
                totals['mapped'] += 1
                count['mapped'] += 1
            except (KeyError, ValueError, OSError, zipfile.BadZipFile) as exc:
                missing.append({'tileset': tileset, 'asset': asset, 'shape': shape, 'animation_index': ai,
                                'source_filename': path, 'error': str(exc)})
                totals['unresolved'] += 1
                count['unresolved'] += 1
    if atlas:
        atlas.flush()
        pages.extend(atlas.pages)
        print(previous, dict(per_tileset[previous]), flush=True)
    report = {'format': 1, 'private_artwork': True, 'references': len(rows), 'totals': totals,
              'decode_modes': collection.decode_modes, 'tilesets': per_tileset, 'pages': pages,
              'unresolved': missing, 'scope': 'All TD Map Editor tilesets; sidebar/UI require separate UI mappings.',
              'native_pixels_per_cell': 128, 'classic_pixels_per_cell': 24,
              'animation': 'Original FPS and ordered Frame list retained, including intentional empty entries.',
              'atlas': 'Native crop pixels, 1px transparent gutters, top-left origin; lazy-load pages at runtime.'}
    (args.output / 'coverage.json').write_text(json.dumps(report, indent=2) + '\n')
    (args.output / 'provenance.json').write_text(json.dumps(collection.receipts, indent=2) + '\n')
    (args.output / 'manifest.ini').write_text('[pack]\nformat=2\nid=org.tiberiandawn.remastered-local-full\nname=Private Remastered Collection\nframes=frames.tsv\nteams=teams.tsv\nnative_cell=128\nclassic_cell=24\n')
    print(json.dumps({'references': len(rows), **totals, 'pages': len(pages), 'unresolved': len(missing)}), flush=True)
    if not args.tileset:
        append_ui(collection, args.output, args.atlas_size)
    if missing:
        raise SystemExit(2)


if __name__ == '__main__':
    main()
