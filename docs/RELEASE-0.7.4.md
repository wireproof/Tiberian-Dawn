# v0.7.4 — iOS build 710

This release brings a Duo laptop command deck and further Remastered graphics fixes. Build 710 was compiled, signed, and installed on the owner's Duo. The owner subsequently reported in-game verification for the laptop controls and graphics listed below. iPad gameplay was not separately retested for this build.

## What changed

- Added an optional Duo laptop layout: battlefield on the upper screen and Build, Commands, Radar, Cheats, and Options below. Build shows game artwork for buildings, infantry, and vehicles, with production progress and READY state. The classic sidebar can be shown or hidden independently. [#13](https://github.com/wireproof/Tiberian-Dawn/issues/13) · [#16](https://github.com/wireproof/Tiberian-Dawn/issues/16)
- Added Radar tap-to-center in the lower deck. Laptop and Remastered toggles are in Options rather than below the radar. The owner marked #13 and #16 verified in gameplay.
- Restored the movable Options panel and joystick in laptop mode. During building production, one-finger map dragging remains available; two-finger panning takes over when a completed structure is selected for placement.
- Improved Remastered sprite, tree, Tiberium, wall, projectile, Ion Cannon, and Obelisk rendering. The owner reported the recent Remastered graphics fixes working on Duo. [#1](https://github.com/wireproof/Tiberian-Dawn/issues/1) · [#14](https://github.com/wireproof/Tiberian-Dawn/issues/14) · [#15](https://github.com/wireproof/Tiberian-Dawn/issues/15)

## Verification and remaining checks

The [issue tracker](https://github.com/wireproof/Tiberian-Dawn/issues) uses `stage: implemented` for code changes awaiting gameplay verification and `stage: verified` for owner-confirmed physical-device results. [Waypoints after relaunch #7](https://github.com/wireproof/Tiberian-Dawn/issues/7) and [Force Move/crushing #10](https://github.com/wireproof/Tiberian-Dawn/issues/10) remain open. The [v0.7.4 checklist](https://github.com/wireproof/Tiberian-Dawn/blob/v0.7.4/docs/TESTING-0.7.4.md) keeps device-specific checks explicit.

## Download

The complete unsigned iOS IPA includes classic game data, music, and Remastered artwork. Sign it for your device before installation; iCloud sync requires compatible entitlements. Update the existing app instead of uninstalling it if you want to preserve local saves. Use `SHA256SUMS` to verify the download. The repository source archive does not bundle game data.

## Next

The [v0.7.5 plan](https://github.com/wireproof/Tiberian-Dawn/blob/v0.7.4/docs/RED-ALERT-0.7.5-PLAN.md) targets a visual Tiberian Dawn / Red Alert choice, Allied and Soviet content, skirmish, and multiplayer. An AYN Thor Android dual-screen port is being explored. Neither is included in this release.
