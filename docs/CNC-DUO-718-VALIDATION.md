# C&C Duo build 718 validation

## Implemented

- Separate Red Alert remastered world, team-color and cameo artwork, loaded from `RemasteredArtRA`. Tiberian Dawn keeps its own pack.
- Red Alert native command/build/radar/cheat controls, nine control groups, unit queues, persistent rallies, joystick settings, laptop layout, RA-specific Workshop, safe backup transfer, and opt-in iCloud snapshots.
- A persistent game-library loop, reusable engine sessions, and explicit rendering/audio visibility changes instead of falling out of SDL startup on Exit Game.
- Tyson's supplied launcher artwork, unchanged, with functional native hit targets and responsive portrait panel layout.
- Packaging overlays the complete new app and signs its nested engine, rather than accidentally retaining an old Red Alert dylib.

The `Artwork` control in each game's native Options panel selects classic or remastered rendering. Original menu/sidebar chrome is retained. Red Alert's Chronal Vortex temporarily uses classic world rendering for its distortion effect.

## Checks completed on 2026-11-10 UTC

- Combined arm64 iOS simulator build: succeeded, including reference launcher.
- Combined unsigned arm64 iOS device build: succeeded, including RA iCloud integration.
- Host tests: 27/27 passed after final remastered scene changes.
- Shared Apple parity source checks: passed.
- Focus/visibility regression using the current helper: passed 10 TD and 10 RA hide/show cycles, stale events and null-window handling.
- Final combined simulator/device builds after focus and partial-startup cleanup: succeeded.
- TD backup regression and RA backup/cloud schema, validation, isolation and rollback fixtures: passed.
- RA Workshop metadata/batch-edit fixtures: passed.
- Real TD/RA remastered pack lookup, separation, theater, team-color and icon smoke tests: passed.
- RA importer fixtures and full pack manifest/image-bound/hash checks: passed.
- Native UIKit and AppKit/Foundation source syntax checks reported by feature implementations: passed.

## Acceptance still required

Do not treat a compile or installation as gameplay acceptance. At this checkpoint, the Mac's simulator, debugger and UI service were severely delayed by system load/disk waits. The first simulator launcher screenshot was captured before the supplied-art redesign. New reference-layout screenshots, gameplay and repeated Exit Game/switch/reenter cycles are not accepted yet.

- Verify Allied and Soviet gameplay with remastered art, production, naval units, superweapons, groups, rallies, cheats, Workshop and save/load.
- Verify repeated TD → launcher → RA → launcher → TD transitions, including audio, palette, input, background/foreground and score/movie boundaries.
- Verify portrait, landscape, cover/inner display and laptop layouts with screenshots and touch input.
- Complete Universal 2 native macOS compile/package checks and reconcile the separate native macOS combined-engine work before any release/merge.
- Validate on the physical device only after the user has saved/closed the game, backed-up save files are hash-verified, and the established installation workflow is authorized. No physical install or save changes occurred during this work.
- Validate real iCloud delivery only with a properly provisioned host and explicit opt-in. No account, entitlements or cloud preferences were enabled or changed by this implementation.

## Remaining feature gap

Red Alert supports 1–3× tactical zoom. TD-equivalent zoom-out below 1× is not implemented: Red Alert's fixed legacy sidebar, radar, power/credit display and input gadgets need coordinated relocation with expanded backing surfaces. Simply enlarging the buffer misplaces the sidebar and click targets. See `RED-ALERT-CONTROLS.md` for the bounded implementation and acceptance plan.
