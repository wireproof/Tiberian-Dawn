# 0.6.1 validation — 2026-10-26

## Changes

- Optional iCloud Documents sync under Saves / Mod Workshop → iCloud Sync.
  Saves and settings have separate switches, off by default.
- Immutable save snapshots are content-addressed. Incoming saves are validated
  and installed into unused manual slots. Existing saves and offline copies stay intact.
- Settings snapshots contain Workshop presets, cheat choices and language only.
  Zoom, UI scale, control positions, joystick settings, app icon and CONQUER.INI
  stay local. Manual backup export/import still includes device configuration.
- Settings apply on restart. The newest timestamp wins; earlier snapshots remain
  in the cloud container. A subsequent local edit supersedes staged cloud settings.
  This is not a field-by-field settings merge. Keep device clocks automatic.
- Account changes during a session turn both switches off. Re-enable explicitly
  for the new account. Pending settings are bound to their originating account.
- Local save deletion does not delete cloud snapshots or other devices' saves.
  Snapshots currently retain history without automatic pruning.
- Unselected dark-panel tabs are white; selected white tabs use black text.
- Custom 1 is the initial Workshop preset. Existing saved choices are preserved;
  an unedited Custom 1 uses original rule defaults. Stock remains selectable.
- Labels render after map gadgets to avoid partial overpainting. Device confirmation
  of the reported unit-name clipping remains necessary.

## Build and signing

Use platform/apple/iCloud.entitlements for an Apple developer build whose App ID
has the matching registered container. Pass CODE_SIGN_ENTITLEMENTS to xcodebuild
or configure WIREPROOF_ICLOUD_ENTITLEMENTS with that absolute path. Do not commit
personal team identifiers, profiles or credentials. Forks must register their own
container and update both the entitlement template and wireproof_cloud.inc.

Both Apple native targets share the implementation. Public unsigned/ad-hoc builds
cannot use the publisher's iCloud container: a matching provisioned signature is
required. Manual Files import/export works independently of automatic iCloud sync.

## Verification

Host suite, backup transaction tests, sync key isolation/hash/immutable queue tests,
iOS Release compilation, and Universal 2 macOS packaging are release gates.
A successful build or profile check does not prove cross-device iCloud delivery.

Physical checks for this candidate:

1. Enable save sync on iPad and Duo using the same Apple Account and iCloud Drive.
   Save a mission, wait for upload/download, then find it in Load Mission on the other.
2. Disconnect a device, save different progress in the same slot on both, reconnect.
   Confirm both versions remain and original slots were not overwritten.
3. Enable settings sync. Change a cheat or Workshop rule, check the other device,
   restart it and confirm the change. Verify each screen's layout/zoom stayed local.
4. Disable settings sync: local changes must remain local. Test account logout and
   account switch; no pending settings from another account may apply.
5. Check unit labels while infantry and vehicles move, then let labels expire.
   Confirm unselected Game/Cheats/Options tabs remain readable in light/dark appearance.
6. Recheck pinch zoom, one-finger selection after pinch, pause/resume, and save import.
