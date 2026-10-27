0.6.2 device testing
- Floating dock: replace visible sliders with minus/value/plus rows for zoom, UI size, joystick size/speed and unit speed cheats.
- Joystick size and speed remember Cover, Inner and Standard profiles. Existing global preferences seed each profile. Manual backup includes these keys; iCloud excludes device control preferences.
- Recompose the classic help label above modern artwork and health overlays in the shared Apple Metal renderer. The SDL fallback already renders the final classic framebuffer and has no HD sprite pass.
- iCloud status reports snapshot upload states, pending downloads, local queue and last save receipt; settings awaiting restart are explicit. Open iOS status refreshes every two seconds.
Validation: 26 host tests, Apple parity, backup/cloud isolation tests, unsigned iOS compile, development signed iOS build and Universal 2 Mac package passed.
Physical verification pending: dock layout in both orientations, cover/inner joystick persistence, labels beside and across HD sprites, named save transfer in both directions. User reported one save may have synced in 0.6.1, but named test save not confirmed.

Delivery: native app installed on Duo and iPad; both read back version 0.6.2. Duo launch attempt was blocked because the device was locked, so startup and gameplay verification remain pending.
