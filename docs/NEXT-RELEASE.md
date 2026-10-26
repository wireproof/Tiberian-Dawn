# v0.5.6: device-aware zoom and saved cheats

Released with v0.5.6, October 26, 2026. See the README for UI-size controls added to this release.

- Ordinary iPhones and iPads show **Zoom**, using one saved zoom preference across rotation. Existing geometry-based preferences seed the new standard preference.
- On iOS 27.1 and later, a non-null UIKit hinge observation enables the Duo's **Cover zoom** and **Inner zoom** profiles. Existing Duo preference keys are preserved. Screen shape alone no longer identifies a device as Duo. Earlier systems without hinge reporting use standard Zoom.
- Cheat toggles (including Shroud) and infantry/vehicle/aircraft speed multipliers persist across missions and application launches on both Apple targets.
- Mission balances, shroud snapshots, and queued money/power actions remain transient. Cheats remain restricted by the existing single-player/player-owner checks.

Validation: all 26 host tests, Apple parity checks, unsigned iOS Release compilation, and signed/verified Universal 2 macOS packaging passed. Regression coverage checks preference restoration, disabled-state restoration, mission resets, inactive mutation protection, and exclusion of queued actions/balances from restoration.

Physical testing still required: hinge updates within LiveContainer on the Duo (including cold launch on either display), ordinary iPhone/iPad labels and rotation, saved preference migration, and cheat persistence through mission changes and app relaunch. Do not treat a successful host build as this device validation.
