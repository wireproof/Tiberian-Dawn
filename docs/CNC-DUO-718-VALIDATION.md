# C&C Duo build 718 validation

Current checkpoint: the post-isolation combined iOS device build succeeded and a complete replacement IPA was signed and archive-verified. Physical-device gameplay acceptance remains pending. The withdrawn pre-isolation candidate below must not be installed.

## Implemented

- Separate Red Alert remastered world, team-color and cameo artwork, loaded from `RemasteredArtRA`. Tiberian Dawn keeps its own pack.
- Red Alert native command/build/radar/cheat controls, nine control groups, unit queues, persistent rallies, joystick settings, laptop layout, RA-specific Workshop, safe backup transfer, and opt-in iCloud snapshots.
- A persistent game-library loop, reusable engine sessions, and explicit rendering/audio visibility changes instead of falling out of SDL startup on Exit Game.
- Image-local cheat/layout singletons, RA-local scene lifecycle handling, hidden-engine audio guards, and transactional two-slot background recovery with a Continue/Main menu prompt.
- Tyson's supplied launcher artwork, unchanged, with functional native hit targets and responsive portrait panel layout.
- Packaging overlays the complete new app and signs its nested engine, rather than accidentally retaining an old Red Alert dylib.

The `Artwork` control in each game's native Options panel selects classic or remastered rendering. Original menu/sidebar chrome is retained. Red Alert's Chronal Vortex temporarily uses classic world rendering for its distortion effect.

## Checks completed on 2026-11-10 UTC

- Combined arm64 iOS simulator build: succeeded, including reference launcher.
- Combined unsigned arm64 iOS device build: succeeded, including RA iCloud integration.
- Signed development candidate: archive and nested code signatures verified; bundle/version/build are com.wireproof.tiberiandawn / 0.7.5 / 718, all 174 RA atlas pages and the exact supplied selector PNG included.
- Both the preserved provisioning profile and signed executable authorize the existing iCloud/ubiquity container. No entitlement changes were needed.
- Host tests: 27/27 passed after final remastered scene changes.
- Shared Apple parity source checks: passed.
- Focus/visibility regression using the current helper: passed 10 TD and 10 RA hide/show cycles, stale events and null-window handling.
- Real-header native O0/O2 dlopen isolation tests: passed for all layout state addresses, wrapper behavior, distinct cheat defaults and save-callback ownership.
- RA lifecycle edge/background-task tests and recovery transaction/validation tests: passed. Latest full app builds remain pending.
- Final combined simulator/device builds after focus and partial-startup cleanup: succeeded.
- Replacement full iOS device build from this source: succeeded with bundle ID `com.wireproof.tiberiandawn`, version `0.7.5`, build `718`.
- Replacement full IPA: original Tiberian Dawn and Red Alert assets, music, movies, both remastered art packs, launcher image and nested Red Alert engine included; nested and outer signatures plus archive integrity verified. SHA-256 `e6cd53a800902af0cdbd55282cf067dc7ef1874edc0d120bf89796d4018d3738`.
- Complete IPA copied to the live Synology SMB mount at `Documents/Applications/iPhone/Games/CnC-Duo-0.7.5-build718-development-full.ipa`; local and destination SHA-256 hashes matched before promotion to the final name.
- TD backup regression and RA backup/cloud schema, validation, isolation and rollback fixtures: passed.
- RA Workshop metadata/batch-edit fixtures: passed.
- Real TD/RA remastered pack lookup, separation, theater, team-color and icon smoke tests: passed.
- RA importer fixtures and full pack manifest/image-bound/hash checks: passed.
- Native UIKit and AppKit/Foundation source syntax checks reported by feature implementations: passed.
- Universal 2 native TD/shared-code build and package verification: passed for arm64 and x86_64, with ad-hoc signature and archive verification. A preexisting shared renderer include error was repaired. This is not native macOS Red Alert feature acceptance.

## Acceptance still required

Do not treat a compile or installation as gameplay acceptance. At this checkpoint, the Mac's simulator, debugger and UI service were severely delayed by system load/disk waits. The first simulator launcher screenshot was captured before the supplied-art redesign. New reference-layout screenshots, gameplay and repeated Exit Game/switch/reenter cycles are not accepted yet. A subsequent simulator launch returned FBSOpenApplicationServiceErrorDomain code 3; another launch and UI reads stalled. The exact runtime cause is unproven and must be diagnosed on a responsive test host.

- Verify Allied and Soviet gameplay with remastered art, production, naval units, superweapons, groups, rallies, cheats, Workshop and save/load.
- Verify repeated TD → launcher → RA → launcher → TD transitions, including audio, palette, input, background/foreground and score/movie boundaries.
- Verify portrait, landscape, cover/inner display and laptop layouts with screenshots and touch input.
- Reconcile and validate the separate native macOS Red Alert/combined-engine work before any release/merge. The native TD/shared-code Universal 2 package check passed, but does not establish RA AppKit feature parity.
- Validate on the physical device only after the user has saved/closed the game and backed-up save files are hash-verified. No physical install or save changes occurred during this build/package checkpoint.
- Validate real iCloud delivery only with a properly provisioned host and explicit opt-in. No account, entitlements or cloud preferences were enabled or changed by this implementation.

## Remaining feature gap

Red Alert supports 1–3× tactical zoom. TD-equivalent zoom-out below 1× is not implemented: Red Alert's fixed legacy sidebar, radar, power/credit display and input gadgets need coordinated relocation with expanded backing surfaces. Simply enlarging the buffer misplaces the sidebar and click targets. See `RED-ALERT-CONTROLS.md` for the bounded implementation and acceptance plan.

## Superseded private development candidate

The initial candidate was withdrawn during review after a reproduced cross-engine singleton leak and a missing RA lifecycle event route. Do not install this older package. A replacement will follow those fixes and validation:

`/Users/wireproof/BuildScratch/CnC718-candidate/superseded/CnC-Duo-build718-pre-isolation-review-DO-NOT-INSTALL.ipa`

SHA-256: `d4d6106accb1b06ecf26d22144b797b082dd7a8f7ec5d71ffeed0128c542d515`

The original simulator RA save was preserved and SHA-256 verified after simulator update. Physical-device saves and installation were not touched.
