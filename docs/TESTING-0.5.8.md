# v0.5.8 — campaign selection and battlefield options

Test candidate, 2026-10-26. Physical-device validation is pending.

## Changes

- Mission Select on the main menu lists installed GDI/Nod campaign missions and their available east/west, A–D variants. It launches the exact selected variant through normal difficulty selection and campaign initialization.
- UI size affects the game interface; the complete floating panel and collapsed icon remain fixed in size. Joystick size remains independent.
- Sidebar extends to the available bottom edge in portrait and landscape, adding slots as space permits.
- Saved Unlock GDI + Nod cheat bypasses faction, technology and prerequisite restrictions for an explicit military roster. Appropriate production buildings are still needed. Civilian/special mission structures, civilian infantry, dinosaurs, visceroids, gunboats, hovercraft and scripted cargo aircraft are excluded. Normal build eligibility is recalculated when disabled; existing units/buildings are retained.
- Saved Damaged building health toggle displays the existing health bar on visible damaged buildings without selecting them. Hidden/cloaked objects are not revealed.
- Touch tooltip labels expire after two seconds of touch inactivity; mouse hover behavior is retained.
- Added the owner's iPad Build Anywhere screenshot to the source showcase gallery. It depicts v0.5.7 Workshop customization, not the new unlock toggle.

## First device tests

1. Main menu → Mission Select → choose a GDI mission and then a Nod variant. Verify the mission, faction and briefing, then test Cancel and ordinary New Game/Load Mission.
2. Compare the floating panel and icon at UI size 75%, 100%, 150%. They should remain the same size while the game sidebar/top bar change.
3. Rotate iPad and both Duo displays; check sidebar arrows reach the bottom and every new slot has intact artwork and correct touch targets.
4. Enable Unlock GDI + Nod with production buildings available. Build an opposite-faction unit/building, disable it and confirm unavailable options disappear. Existing produced objects should remain. Verify no civilian cameos are added.
5. Tap a building and wait without touching. Its label should disappear after about two seconds and stay hidden until another touch. Enable Damaged building health, deselect it, repair to full health, and toggle off to check cleanup.
6. Recheck saved cheats, independent Duo profiles, and screenshot/Control Center drag-mode persistence.

Replace the existing app in LiveContainer while retaining its data container.
