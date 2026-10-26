# Wireproof future plans — 2026-10-26

These are planned features, not functionality shipped in the current app.

1. Production queues: quantities, ordering, cancellation/refunds, factory loss,
   save/load behavior and deterministic multiplayer handling.
2. Optional Remastered artwork import: first validate infantry and a turreted
   vehicle, then expand animation/direction/shadow/palette coverage. Retain the
   complete classic fallback. The existing modern artwork mode is not a complete
   Remastered asset importer.
3. Red Alert game selection: integrate and validate the existing Red Alert
   source with Apple controls, game data, campaigns, saves and audio. Keep each
   game's data, saves and presets separate.
4. RedEdit98-inspired Workshop: inspect Child's Play Software's editor and its
   output; map verified settings onto native Red Alert rules. Evaluate relevant
   Remastered source changes individually. Windows mod DLLs are not directly
   compatible with this native app.

5. Optional iCloud sync for standalone apps: separate save and settings/cheat
   switches; shared Apple-account storage, offline local copies, and preservation
   of conflicting saves. Keep device-specific control positions and display zoom
   local by default. Enable iCloud capabilities/provisioning first; validate
   signed iPad, Duo and Mac builds with two-device, offline, account-change and
   conflict tests. Automatic sync is not included in 0.6.0; .tdbackup files can
   be exported to and imported from iCloud Drive manually.

Current priority: validate 0.6.0 backup restoration and slower pinch zoom on
physical devices, then implement and verify optional iCloud sync.

Reference donor: [Jamesadsy/Vanilla-Conquer](https://github.com/Jamesadsy/Vanilla-Conquer),
reviewed at a006664. Candidate areas: iOS Red Alert build work, controller
repair/sell/sidebar paging, and TD Bonjour discovery. No code imported yet;
retain attribution for any future reuse. Its current landscape-only scaled
renderer does not implement our adaptive portrait battlefield.
