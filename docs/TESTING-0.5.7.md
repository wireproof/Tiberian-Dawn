# v0.5.7 — interruption and sidebar fixes

Test candidate, 2026-10-26. Physical-device verification is pending.

## Changes

- Preserve one-finger map-drag preference when gameplay is temporarily inactive, including screenshots and Control Center. Inactive gameplay still stops movement and discards queued commands.
- Clear interrupted pointer capture and unfinished selection gestures on iOS focus loss and viewport changes, without issuing orders or discarding a pending building.
- Draw permanent sidebar strip artwork using its permanent graphics cache consistently, including empty slots and the gap above the arrows.
- Keep the collapsed floating gamepad icon at its normal size independently of UI size.
- Use a vertical, scrollable Options layout when the usable width cannot fit four slider columns at the chosen UI size.

## Device checks

1. In one-finger map-drag mode, take a screenshot, open/close Control Center, and switch away/back. The hand icon should remain, dragging should pan, and switching to selection should still select/order units without placing a building.
2. Repeat interruptions in joystick mode; it should remain in joystick mode.
3. Change UI size through 75%, 100%, and 150%, rotate, and open/close the panel. The collapsed gamepad icon should stay fixed in size. Sliders must not overlap.
4. Inspect empty sidebar slots and the gap above the arrows before/after rotation, scrolling the build list, and changing UI size. No black streaks or transparent gaps.
5. Recheck the existing Duo cover/inner and portrait/landscape preferences, and saved cheats across missions and relaunch.

Mission Select is not part of this candidate. Keep the existing LiveContainer game data when replacing the app.
