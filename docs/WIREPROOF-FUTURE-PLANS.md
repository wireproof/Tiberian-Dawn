# Wireproof future plans — 2026-10-25

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

Current priority: cover/inner display alignment, touch orders and control groups.

Reference donor: [Jamesadsy/Vanilla-Conquer](https://github.com/Jamesadsy/Vanilla-Conquer),
reviewed at a006664. Candidate areas: iOS Red Alert build work, controller
repair/sell/sidebar paging, and TD Bonjour discovery. No code imported yet;
retain attribution for any future reuse. Its current landscape-only scaled
renderer does not implement our adaptive portrait battlefield.
