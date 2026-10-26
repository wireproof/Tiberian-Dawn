# v0.3.8 zoom slider

The controller menu has minus and plus buttons at the ends of a slider. The
slider and buttons use exactly 0.5–3.0 in 0.25 steps, with the current value above.
The iOS preference persists between launches; default is 1.5x. Top bar, build
sidebar and controller size stay fixed. Option-minus and Option-plus adjust the
same scale with a keyboard on macOS/iOS. Pinch zoom stays disabled.

# v0.3.7 scale adjustment

Fixed gameplay scale is now 1.5x. The hold-to-pan control is unchanged.

# v0.3.6 held map modifier

Hold the floating controller button for a quarter second (it turns blue), then
drag on the map with your other finger. Release the controller to stop panning;
lift the map finger before starting a normal selection. A quick drag of the
controller still repositions it, and a tap still expands the panel. Backgrounding
or leaving gameplay cancels the hold. Gameplay has a fixed 2x scale; pinch zoom
is disabled. Physical-device confirmation pending.

# v0.3.5 control update

Interactive pinch and Control+wheel zoom were reverted after device feedback.
Touch handling is restored to the pre-0.3.4 behavior. The panel is 256 points
wide, with groups 1–5 and 6–9 on separate rows and actions below. Collapse,
dragging, and original game icons remain. Physical-device confirmation pending.

The sections below record the prior implementation history.

# Touch orders and groups — v0.3.4

During a mission, tap the circular game-controller button to open **Orders & Groups**.
Drag the circle or expanded heading to reposition it; the relative position is saved. The tray stays
inside the window safe area. Groups 1–9 occupy the horizontal strip, with group
actions and orders in two columns below. Tap the heading again to collapse it.
The group strip scrolls horizontally; the panel scrolls vertically on short screens.

- **Stop**, **Guard**, **Scatter** act on the selected units using the existing
  engine commands and normal simulation/network events.
- **Force Attack** / **Force Move** arm the next tactical-map click. The heading
  and button indicate the mode. **Cancel**, right-click, losing the selection,
  leaving gameplay or backgrounding disarms it. A completed map click disarms
  it even if the target is invalid. Hardware Ctrl/Alt remain independent.
- Groups are the classic **1–9, 0** slots. Select an action, then a group number:
  - **Recall:** replace selection with that group.
  - **Assign:** replace the group's membership with the selected owned units.
    Disabled with no selection. A unit belongs to one classic group at a time.
  - **Add:** add the group's units to the current selection.
  - **Center:** recall the group and center the camera on it.
- Group action returns to Recall after each tap, preventing accidental repeated
  assignment. Groups use native scenario state; this feature does not add a
  separate cross-mission group store.

Mac users retain the existing keyboard equivalents: S/G/X, Ctrl/Alt-click,
number to recall, Ctrl-number to assign, Shift-number to add and Alt-number to
center. UIKit provides the tray on touch devices; all commands use shared game
behavior. No queue, Remastered importer or Red Alert implementation is included.

Validation: host tests cover command state and lifecycle resets. Physical touch,
fold/rotation, order targets and group interactions require device validation.

## 0.3.4 candidate

Groups 1–9 remain in a horizontal strip. Recall, Assign, Add, and Center are
in a two-column grid below it, followed by the order controls. Group 0 remains
available on a physical keyboard. The panel scrolls vertically when the
window is too short for all controls. Attack and Move use decoded MOUSE.SHP
artwork from the user's active game data.

Pinch the battlefield from 1x to 3x. Two-finger drag pans; a short two-finger tap
or stationary hold sends right-click. A pinch cannot become a two-finger tap
on release. One-finger tap/drag continues to select/order and box-select.
Control+mouse wheel zooms on macOS. The sidebar and top bar do not zoom.
Portrait gameplay expands the map viewport; the main menu keeps its original
artwork aspect ratio. Real Duo cover/inner switching and iPad touch validation
remain pending for this prerelease.
