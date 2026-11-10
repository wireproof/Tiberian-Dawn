# Private Red Alert Remastered artwork

Both Apple targets use the shared Metal renderer and frame-capture interface.
Red Alert selects its own pack before video initialization. `RemasteredArtRA`
is separate from Tiberian Dawn's `RemasteredArt`, including texture caches,
tilesets, theater enums and team-color interpretation. Never copy RA frames
into the TD directory: names such as CLEAR1 and FACT overlap.

## Import and package

Use a locally owned, installed Remastered Collection directory containing Data:

```sh
python3 scripts/import-remastered-graphics.py /path/to/installation /private/ra-art --game ra
cmake ... -DRED_ALERT_REMASTERED_ART_DIR=/private/ra-art
```

Pillow with DDS decoding is required. The importer preserves the Collection's
XML frame order, native crop metadata, intentional blank frames and team-color
parameters. `coverage.json` and `provenance.json` record coverage and source
hashes. The importer refuses to replace an existing frame import. Output is
proprietary artwork: keep it outside the repository and do not redistribute it.

The RA pack covers temperate, snow and interior terrain, units (including naval
units), structures, VFX and exact XML-mapped sidebar icons. The runtime keeps
classic fallback pixels when an imported frame is unavailable or requires an
engine-transformed image (for example, a rotated projectile). Cloaking and
shadow effects retain their original drawing semantics. Health bars, selection
brackets and building placement remain visible over HD artwork.

The source sidebar chrome is imported for future layout work; the current
sidebar retains its original control layout and chrome, with Remastered build
icons, progress shading and readiness indicators. UI menus, videos, fonts and
the chronal vortex's procedural drawing are not replaced by this importer.
The map temporarily uses original graphics while a chronal vortex is active,
so HD terrain cannot conceal its destination-pixel distortion.

## Verification

`python3 tests/test_remastered_import.py` exercises importer isolation and
mapping with synthetic, non-proprietary fixtures. `test_remastered_scene`
exercises captures, clipping metadata, copied fallback pixels, fog, health and
selection lifetime. `tests/verify_remastered_apple.mm` is an optional Apple integration smoke test
against a private Resources directory with both packs. It checks game isolation,
theater lookup, icons and owner colors. Apple build and on-device visual checks
are still required:
allied/soviet missions, all theaters, owner colors, naval units, cloaking,
shroud, moving/rotated effects, sidebar scrolling, placement, selection and
Original/Remastered switching. A metadata or compile check is not a rendered
visual acceptance test.
