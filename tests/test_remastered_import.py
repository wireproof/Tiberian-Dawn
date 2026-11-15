"""Asset-free regression tests for private TD/RA artwork importing.

Run with a Python interpreter that has Pillow:
    python -m unittest discover -s tests -p 'test_remastered_import.py'
"""
import csv
import importlib.util
import io
import pathlib
import struct
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    'remastered_import', pathlib.Path(__file__).resolve().parents[1] / 'scripts/import-remastered-graphics.py')
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


class Collection:
    def __init__(self, entries):
        self.entries = entries

    def read(self, name):
        return self.entries[name]


class ImportTests(unittest.TestCase):
    def test_game_tilesets_are_isolated_and_frames_keep_order(self):
        entries = {}
        for game in ('TD', 'RA'):
            entries['DATA/XML/TILESETS/' + game + '_UNITS.XML'] = (f'''
                <Root><TilesetTypeClass name="{game}_Units">
                <RootTexturePath>{game}\\Units</RootTexturePath><Tiles><Tile>
                <Key><Name>tank</Name><Shape>7</Shape></Key>
                <Value><AnimationData><FPS>12</FPS></AnimationData>
                <Frames><Frame>first.tga</Frame><Frame/><Frame>last.tga</Frame></Frames></Value>
                </Tile></Tiles></TilesetTypeClass></Root>''').encode()
        c = Collection(entries)
        for game in ('td', 'ra'):
            rows = IMPORTER.mappings(c, game)
            self.assertEqual(len(rows), 3)
            self.assertEqual([row[3] for row in rows], [0, 1, 2])
            self.assertTrue(all(row[0] == game.upper() + '_Units' for row in rows))
            self.assertEqual(rows[0][1:3], ('TANK', 7))
            self.assertEqual(rows[0][4], 12)
            self.assertEqual(rows[1][5], '')
            self.assertEqual(rows[2][5], 'DATA/ART/TEXTURES/SRGB/' + game.upper() + '/UNITS/LAST.TGA')
        self.assertEqual(IMPORTER.mappings(c), IMPORTER.mappings(c, 'td'))

    def test_team_xml_selection_and_inheritance(self):
        xml = b'''<Teams><Team Name="BASE"><HSVShift><X>.2</X><Y>.3</Y><Z>.4</Z></HSVShift></Team>
                  <Team Name="USSR" Variant="BASE"><Fudge>.1</Fudge></Team></Teams>'''
        with tempfile.TemporaryDirectory() as directory:
            out = pathlib.Path(directory)
            IMPORTER.teams(Collection({'DATA/XML/CNCRATEAMCOLORS.XML': xml}), out, 'ra')
            self.assertEqual((out / 'CNCRATEAMCOLORS.XML').read_bytes(), xml)
            with (out / 'teams.tsv').open() as f:
                rows = list(csv.DictReader(f, delimiter='\t'))
            self.assertEqual(rows[1]['team'], 'USSR')
            self.assertEqual(float(rows[1]['HSVShift.Y']), .3)
            self.assertEqual(float(rows[1]['Fudge']), .1)

    def test_ui_uses_ra_buildables_and_exact_mtd_crop(self):
        key = b'BUILDICON_RA_TANK.TGA\0'
        mtd = struct.pack('<iiI', -2, 1, len(key)) + key + struct.pack('<8IB', 1, 2, 3, 4, 5, 6, 10, 12, 0)
        image = IMPORTER.Image.new('RGBA', (8, 8), (10, 20, 30, 255))
        raw = io.BytesIO(); image.save(raw, format='TGA')
        c = Collection({
            'DATA/ART/TEXTURES/SRGB/MT_COMMANDBAR_COMMON.MTD': mtd,
            'DATA/ART/TEXTURES/SRGB/MT_COMMANDBAR_COMMON.TGA': raw.getvalue(),
            'DATA/XML/OBJECTS/UNITS/RABUILDABLES.XML': b'''<Objects>
              <ObjectTypeClass Name="RA_2TNK"><CNCEncyclopediaComponent><BuildIcon>BuildIcon_RA_Tank</BuildIcon></CNCEncyclopediaComponent></ObjectTypeClass>
              <ObjectTypeClass Name="TD_HTNK"><CNCEncyclopediaComponent><BuildIcon>BuildIcon_RA_Tank</BuildIcon></CNCEncyclopediaComponent></ObjectTypeClass>
              </Objects>'''
        })
        with tempfile.TemporaryDirectory() as directory:
            rows, pages, errors, unmapped = IMPORTER.import_ui(c, pathlib.Path(directory), 1024, 'ra')
            self.assertFalse(errors or unmapped)
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0][:2], ['RA_UI', 'ICON.2TNK'])
            self.assertEqual(rows[0][9:15], [3, 4, 10, 12, 5, 6])
            self.assertEqual(pages[0]['file'], 'ra_ui-0000.png')

    def test_append_cannot_cross_game_packs(self):
        IMPORTER.require_game({'tilesets': {'RA_Units': {}}}, 'ra')
        with self.assertRaises(ValueError):
            IMPORTER.require_game({'tilesets': {'TD_Units': {}}}, 'ra')


if __name__ == '__main__':
    unittest.main()
