#!/usr/bin/env python3
"""Import a private three-vehicle preview from an owned Remastered installation.
Requires Pillow and numpy. No game artwork is downloaded or distributed.
"""
import argparse, colorsys, hashlib, io, json, pathlib, struct, zipfile
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

def index(path):
    result = {}
    with path.open('rb') as f:
        magic, = struct.unpack('<I', f.read(4)); f.seek(12 if magic in (0xffffffff, 0x8fffffff) else 4)
        count, strings, size = struct.unpack('<III', f.read(12)); data = f.read(size); names = []; pos = 0
        for _ in range(strings):
            n, = struct.unpack_from('<H', data, pos); pos += 2
            names.append(data[pos:pos+n].decode()); pos += n
        if pos != size: raise ValueError('Invalid MEG string table')
        for _ in range(count):
            flags, crc, idx, length, offset, ni = struct.unpack('<HIiIIH', f.read(20))
            if ni >= len(names) or offset+length > path.stat().st_size: raise ValueError('Invalid MEG entry')
            result[names[ni].replace('\\','/').upper()] = (offset, length)
    return result

def read(path, entry):
    with path.open('rb') as f:
        f.seek(entry[0]); return f.read(entry[1])

def recolor(image, team):
    def vec(tag, keys): return np.array([float(team.findtext(tag+'/'+k)) for k in keys])
    rgba=np.array(image); rgb=rgba[:,:,:3].astype(float)/255
    rgb=np.where(rgb<.04045,rgb*25/323,((200*rgb+11)/211)**2.4)
    flat=rgb.reshape(-1,3); hsv=np.array([colorsys.rgb_to_hsv(*x) for x in flat]).reshape(rgb.shape)
    lo=colorsys.rgb_to_hsv(*(np.floor(vec('LowerBounds','RGB')*255)/255))[0]
    hi=colorsys.rgb_to_hsv(*(np.floor(vec('UpperBounds','RGB')*255)/255))[0]
    mask=(hsv[:,:,0]>=lo)&(hsv[:,:,0]<=hi)
    adjusted=hsv[mask].copy(); fudge=float(team.findtext('Fudge'))
    adjusted[:,0]*=((hi+fudge)-(lo-fudge))/(hi-lo); adjusted+=vec('HSVShift','XYZ')
    h,s,v=adjusted.T
    m=np.abs(((h[:,None]+np.array([1,2/3,1/3]))%1)*6-3)
    value=v[:,None]*(1+(np.clip(m-1,0,1)-1)*s[:,None])
    def levels(v, inp, out):
        a=vec(inp,'XYZ'); b=vec(out,'XY'); n=np.clip((v-a[0])/(a[2]-a[0]),0,1)**a[1]
        return b[0]+(b[1]-b[0])*n
    rgb[mask]=levels(value,'InputLevels','OutputLevels')
    rgb=levels(rgb,'OverallInputLevels','OverallOutputLevels')
    rgb=np.where(rgb<.0031308,rgb*323/25,(np.maximum(rgb,0)**(5/12)*211-11)/200)
    rgba[:,:,:3]=np.clip(rgb*255,0,255).astype(np.uint8)
    return Image.fromarray(rgba)

def main():
    p=argparse.ArgumentParser(); p.add_argument('installation',type=pathlib.Path); p.add_argument('output',type=pathlib.Path); a=p.parse_args()
    data=a.installation/'Data'
    if not data.exists(): data=a.installation/'DATA'
    archives=[data/n for n in ['CONFIG.MEG','TEXTURES_TD_SRGB.MEG','TEXTURES_PATCHES_SRGB.MEG']]
    indices={f:index(f) for f in archives}; receipts={}
    def asset(name):
        name=name.replace('\\','/').upper()
        for f in reversed(archives):
            if name in indices[f]:
                raw=read(f,indices[f][name]); receipts[name]={'archive':f.name,'sha256':hashlib.sha256(raw).hexdigest()}; return raw
        raise ValueError('Missing '+name)
    colors=ET.fromstring(asset('DATA/XML/CNCTDTEAMCOLORS.XML'))
    teams=[colors.find("TeamColorTypeClass[@Name='%s']"%n) for n in ['GOOD','BAD_UNIT']]
    mappings={}
    for name in indices[archives[0]]:
        if '/TILESETS/TD_' not in name or not name.endswith('.XML'): continue
        root=ET.fromstring(asset(name))
        for ts in root.findall('TilesetTypeClass'):
            for tile in ts.findall('Tiles/Tile'):
                key=tile.findtext('Key/Name')
                if key and key.upper() in ['MTNK','JEEP','BGGY']:
                    frames=[x.text for x in tile.findall('Value/Frames/Frame')]
                    if len(frames)!=1: raise ValueError('Unexpected animated vehicle mapping')
                    mappings.setdefault(key.upper(),{})[int(tile.findtext('Key/Shape'))]='DATA/ART/TEXTURES/SRGB/'+ts.findtext('RootTexturePath').replace('\\','/')+'/'+frames[0].replace('\\','/')
    a.output.mkdir(parents=True,exist_ok=True); manifest=['[pack]','format=1','id=org.tiberiandawn.remastered-local','name=Remastered local vehicle preview','scale=4','','[assets]']
    for name,ident in [('MTNK','mtnk'),('JEEP','humvee'),('BGGY','buggy')]:
        shapes=mappings[name]
        if set(shapes)!=set(range(64)): raise ValueError(f'{name}: expected 64 classic shapes, found {len(shapes)}')
        atlas=Image.new('RGBA',(1536,3072)); zips={}
        for shape,path in sorted(shapes.items()):
            parent,leaf=path.rsplit('/',1); archive=parent+'.ZIP'
            if archive not in zips: zips[archive]=zipfile.ZipFile(io.BytesIO(asset(archive)))
            z=zips[archive]; members={x.upper():x for x in z.namelist()}
            raw=z.read(members[leaf.upper()]); meta=json.loads(z.read(members[(leaf.rsplit('.',1)[0]+'.meta').upper()]))
            if meta['size'] not in ([192,192],[128,128]): raise ValueError(f'{name}: unsupported canvas {meta}')
            im=Image.open(io.BytesIO(raw)).convert('RGBA'); x,y,r,b=meta['crop']
            if im.size!=(r-x,b-y): raise ValueError('Crop does not match image')
            canvas=Image.new('RGBA',(192,192)); canvas.paste(im,(x+(192-meta['size'][0])//2,y+(192-meta['size'][1])//2))
            for variant,team in enumerate(teams): atlas.paste(recolor(canvas,team),((shape%8)*192,(shape//8+variant*8)*192))
        filename=name.lower()+'.png'; atlas.save(a.output/filename); manifest.append(f'unit.{ident}={filename}')
        receipts[filename]={'sha256':hashlib.sha256((a.output/filename).read_bytes()).hexdigest(),'shapes':64,'canvas':[192,192],'variants':['GOOD','BAD_UNIT']}
        print(name,'64 shapes, original crop offsets, GOOD/BAD_UNIT',flush=True)
    (a.output/'manifest.ini').write_text('\n'.join(manifest)+'\n')
    (a.output/'provenance.json').write_text(json.dumps(receipts,indent=2)+'\n')
if __name__=='__main__': main()
