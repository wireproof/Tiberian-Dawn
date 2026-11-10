# Red Alert Apple controls

The combined app loads Red Alert as an independent engine image. Its command
deck must use that image's SDL window and `WPOrders` state; the Tiberian Dawn
UIKit deck cannot safely manipulate Red Alert objects or share Objective-C
class names with a second implementation.

## Implemented bridge

- A collapsible RA command deck with Build, Commands, Radar, Cheats and Options, plus a
  hinged/always-portrait lower-half layout, RA cameo grid, nine direct group
  buttons and two-column cheat controls.
- Build entries come from RA's actual sidebar, including vessels and RA
  superweapons. Start/resume, hold, cancel/refund and completed-building
  placement use RA events and legality checks. Units have bounded automatic queues per infantry, vehicle, aircraft and naval
  category; cancellation is acknowledged through the engine event stream.
- Stop, guard area, scatter, force attack/move and cancel. Nine control groups
  support assign, recall, add-to-selection and center.
- Radar uses RA's current palette and mapped/visible cells, and respects the
  presence and operating status of the radar facility. Tap/drag recenters it;
  before radar is operational the same blank surface acts as a relative trackpad.
- Persisted infantry/vehicle rallies are keyed to RA scenario and player house.
  Units receive the move order after factory exit; harvesters are excluded.
- Touch joystick, two-finger pan and map drag through shared SDL scrolling. Pinch and buttons control
  1–3x battlefield zoom; the classic sidebar/top bar remain fixed-size. This
  intentionally does not implement TD's zoomed-out larger backing surface.
- Single-player campaign/skirmish cheats: credits, power, invincibility, reveal,
  instant/free production, charging existing RA superweapons, build anywhere,
  a military build-roster unlock, damaged-building health bars, and separate
  infantry, vehicle/ship and aircraft speed choices.
- Native options entry uses a queued game-thread request, exposing RA's existing
  save/load/game settings. Existing RA save paths and files are unchanged.
- Joystick size, speed and long-press repositioning persist separately for cover/inner
  displays and portrait/landscape orientations.

Cheats are disabled for network sessions and replay. Preferences have a separate
`Wireproof.RedAlert.Cheats.v1` namespace and contain choices only, never money,
power, simulation objects or queued actions. Build-anywhere bypasses the base
proximity requirement, not terrain, occupancy or naval placement legality.

## Known parity gaps

RA does not yet have TD's larger backing surface for zoom below 1x. The deck
uses RA-specific Workshop rules rather than pretending TD rules are valid in RA.
The Workshop and save/settings transfer implementations and their validation are
tracked separately. Feature implementation is not a claim of completed runtime
or physical-device acceptance.

Native macOS must compile the same engine control source and supply the
Foundation-only RA preferences functions independently of the UIKit bridge.
This change alone is not verification of the separate native macOS RA target.

## Acceptance checklist

Physical-device acceptance remains required. In both Allied and Soviet missions:

1. Open/collapse the deck, rotate, background/foreground, and return to the game
   chooser; confirm no stale deck remains over menus or the other engine.
2. Produce infantry, vehicle, aircraft, naval unit and building where available;
   hold, resume and refund; place/cancel a completed building. Verify actual
   cost and refund with free production both on and off.
3. Exercise all group actions and force orders, then cancel and select normally.
4. Pan with the joystick, pinch zoom, toggle radar power, drag the live radar
   and use the unpowered trackpad. Reposition/resize the joystick, rotate and
   reopen. Test hinged posture and Always Portrait on inner and cover displays.
5. Toggle each cheat, start/load a different mission, and verify preferences
   persist while actions/balances do not leak. Confirm network/replay games
   cannot receive cheat effects.
6. Save/load via Options without overwriting existing physical-device saves.
7. Test RA-specific superweapons, especially sonar's immediate activation and
   Chronosphere/Iron Curtain target selection.

Focused simulator syntax checks are useful but do not satisfy these runtime,
physical-device, unsigned iPadOS and Universal 2 macOS acceptance gates.

## Zoom-out implementation boundary

The lower zoom limit is currently 1x, not TD's 0.5x. Enlarging the backing
surfaces alone is unsafe: RA still draws its legacy sidebar, power bar and
some credit-tab shapes at fixed 640x400-era coordinates, whereas the shared
SDL/Metal compositor samples the sidebar from the backing surface's right edge.
The result would overlap interface art with the world and misalign hit targets.

A proper port must add an absolute-position sidebar relayout operation (RA has
no equivalent of TD's `Resize_Apple_Viewport`), relocate radar/power/sidebar and
strip gadgets, right-align all credit-tab drawing, resize and reattach both
visible/hidden buffers, and restore classic dimensions before dialogs/movies.
Loaded Map state also needs relayout because it can restore old gadget positions.
Do not rerun `One_Time` initializers or add serialized Map instance fields as a
shortcut. The existing shared compositor already supports the larger backing
surface and does not require an RA-specific workaround.

Before lowering the clamp, test 1x/0.75x/0.5x round trips, sidebar open/closed,
classic/remastered art, map-edge clipping, selection and build/radar clicks,
load/save, Options and score/movie transitions on both Apple targets. No such
zoom-out refactor was included in this change; legacy sidebar behavior was
preserved instead of silently hiding it at low zoom.
