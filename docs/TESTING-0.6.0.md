# 0.6.0 — 2026-10-26

The user verified icon switching and improved scaling on the preceding candidate, labeled 0.5.10. The next version is 0.6.0 per the requested numbering convention.

## Import / Export
Main menu → Saves / Mod Workshop → Import / Export:
- Export saves only: all valid manual save slots.
- Export settings / cheats / config: display/control preferences, cheat toggles and speeds, Workshop presets, and CONQUER.INI when present.
- Export saves + settings: both in one .tdbackup file.
- Import backup: validates the version and all saves; installs into free slots. Existing saves are preserved. Settings merge on the next launch, before the engine reads configuration; fully close and reopen the app.

Original game archives, app icons, and recovery autosaves are excluded. Portable backup size is limited to 128 MB of save payload. Individual save import/export remains available under Manage saves. Both native Apple targets use the same backup format.

## Device test
1. Export each of the three types to Files. Import a saves-only backup and verify the restored mission without losing the existing slot.
2. Export configuration, change a cheat and zoom, import it, then fully close/reopen and check restoration. Repeat with combined backup and across devices.
3. Pinch slowly in a mission, including drag mode: doubling finger separation changes zoom by approximately 26%, rounded to the existing 0.25× steps. Small motion should do nothing. The top bar and sidebar must keep their size. Zoom remains limited to 0.5–3× and persists per display profile.
4. After pinching, verify tap selection, drag selection, two-finger pan and two-finger tap cancellation. Check interruptions, rotation and cover/inner transitions.
5. Tap a unit while it moves. Its short-lived tooltip should remain complete and disappear rather than leave fragments. The map redraw is refreshed while the label is visible; check performance.

Host coverage: damped pinch mapping/bounds; isolated backup round-trip, preserved slots, malformed save rollback, invalid preference rejection, and restart staging. Synthetic save validation is stubbed only in the backup harness; production uses the real engine validator. Physical gesture/file-provider checks remain pending.

Build checks passed: 26 host tests, isolated Apple backup tests, iOS Release compile and developer signing, Universal 2 macOS packaging, Apple parity, release-tree scan, and whitespace check.
