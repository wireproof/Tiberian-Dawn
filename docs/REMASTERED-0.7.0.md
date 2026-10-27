# Private Remastered integration — 0.7.0 (700)

2026-10-26. Private device-test build; not published.

## Scope

Shared Apple Metal renderer reconstructs the battlefield in engine draw order using real Collection artwork: terrain in three theaters, structures, infantry, vehicles, aircraft, effects, shroud and 51 buildable sidebar cameos. Original mode remains available. Save format, simulation and touch layout are unchanged. Menus, movies, sidebar chrome and text retain the classic presentation; this is not a replacement of the entire Collection UI.

The private importer reads installed MEGs, tileset metadata, TGA ZIPs, DDS and the command-bar atlas. It produces 24,700 game frames, 24 intentional blank frames and 51 cameos in 146 atlas pages (~393 MiB). SOURCE pixels are recolored with the Collection team-color parameters at runtime. Frame pivots, animation indices, logical terrain icons and per-object ownership are retained. Unsupported engine shapes retain indexed fallback; legacy ghost-table effects use approximate alpha shading in that fallback.

## Private packaging

Run `scripts/import-remastered-graphics.py --help` for import arguments. Put its output in `RemasteredArt` beside the iOS executable, or `Contents/Resources/RemasteredArt` on macOS before signing. Never commit or publish extracted assets or the resulting private bundles. The importer and renderer contain no game image payloads. Private full bundles omit the earlier ModernArt preview pack.

## Verification

- 27 host tests, including ordered-scene capture, remap/alpha, clipping and health lifecycle.
- iOS unsigned compilation and developer-signed device build; Universal 2 Mac packaging.
- All extracted page hashes/bounds checked; representative output pixels compared against source art, no decode failures.
- Offscreen Metal render: actual terrain, building, infantry, vehicle and team-color samples.
- Isolated live Mac run loaded a copy of the existing iCloud save; visually checked real terrain/trees/cliffs, construction yard, infantry/vehicles, sidebar cameos, selection and health bars.
- Sidebar placement uses source framebuffer width, not tactical viewport width; world pass and final health pass are separate to avoid covering selection overlays.

Physical Duo performance, every unit animation, combat effect, and all missions remain device-test coverage, not claims established by host tests. Installation does not launch the app. No GitHub release is authorized for these assets.
