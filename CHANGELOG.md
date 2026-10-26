# Changelog

All notable changes to Tiberian Dawn for Apple platforms are documented here.
The project keeps iPadOS, macOS, and visionOS on one shared engine and content
baseline wherever the operating systems permit it.

## 0.4.2 — 2026-10-25

- Rebuild the full Apple game frame during camera scrolling instead of reusing
  a composited framebuffer block, preventing sidebar pixels and stale black
  regions from being dragged across the battlefield.
- Retain the double-tap joystick and proportional scrolling. Full redraw during
  movement favors correct output; device performance and artifact confirmation
  remain pending.

## 0.4.1 — 2026-10-25

- Double-tap the floating controller to expand a circular map joystick;
  double-tap it again to return to the normal button.
- Joystick displacement controls scroll speed, with a center dead zone and
  release/cancellation/focus-loss reset. It works with edge scrolling disabled.
- Preserve single-tap Orders & Groups, normal-button dragging and hold-to-pan.
- The touch joystick uses the existing analog camera-scroll path; macOS retains
  physical controller and keyboard camera controls.
- Physical-device confirmation of gesture feel remains pending.

## 0.4.0 — 2026-10-25

- Add separate Instant Build and Zero Cost single-player switches on iOS and
  macOS. Instant Build pays the remaining price when affordable; Zero Cost
  waives the remaining construction bill. Cancellation refunds only money paid.
- Fix Shroud Off updating the minimap but not the battlefield: update the
  player's visibility masks through the engine API, including restoration.
- Enlarge radar terrain to use its panel, following the battlefield when the
  larger scale shows only part of the map. Fix radar height calculation.
- Reduce the touch feedback cursor from 3x to 2x.
- Physical-device confirmation remains pending.

## 0.3.9 — 2026-10-25

- Add a Cheats page to the floating controller: +1,000/+10,000 credits,
  invincibility, shroud on/off, +100/+1,000 power, and infantry/vehicle/aircraft
  speed sliders from 0.25x to 3x. These affect the player in single-player only.
- Add the equivalent macOS panel on Option-C, applying changes on close.
- Live toggles and speed reset on mission start/load. Added credits and power
  are part of the saved game. Shroud On restores the pre-reveal exploration
  snapshot plus current unit sight; saving while revealed saves that map state.

- Make iOS Edge scroll OFF suppress legacy cursor-edge/autoscroll as well as
  touch-edge scrolling, and clear residual scrolling inertia. Manual panning
  and controller directional input remain available.
- Open Save Mission without focusing the filename field or opening the iOS
  keyboard. Tapping the field starts text entry; desktop autofocus is retained.
- Rename UI scale to Touch size: this setting controls touch targets/feedback,
  not the size of the entire classic interface.
- Physical-device confirmation of these fixes remains pending.

## 0.3.8 — 2026-10-25

- Add a controller-menu zoom slider with minus/plus ends and eleven exact
  quarter steps from 0.5x through 3x. Default is 1.5x; the iOS preference is saved.
- Zoom-out renders additional map area while keeping the top bar, sidebar and
  controller at their normal sizes. Preserve the map center across zoom changes.
- Add Option-minus/Option-plus keyboard equivalents on both Apple targets.
- Keep pinch zoom disabled and retain hold-to-pan and groups 1–5 / 6–9.
- Physical-device confirmation of the slider remains pending.

## 0.3.7 — 2026-10-25

- Reduce fixed battlefield magnification from 2x to 1.5x after device feedback.
- Keep hold-to-pan, the compact toolbar, menus and sidebar unchanged.
- Physical-device confirmation of the revised scale remains pending.

## 0.3.6 — 2026-10-25

- Start gameplay at a fixed 2x battlefield magnification so units and terrain
  are larger. Keep menus, the top bar, sidebar and Orders panel at normal size.
- Preserve v0.3.5 gestures; pinch and Control+wheel zoom remain disabled.
- Hold the floating controller button to temporarily pan the map with your
  other finger. Release to return to normal selection.
- Physical-device confirmation of the larger battlefield remains pending.

## 0.3.5 — 2026-10-25

- Revert the 0.3.4 pinch and Control+wheel zoom gestures. Restore the previous
  touch gesture handling while retaining adaptive display sizing.
- Narrow the draggable Orders panel to 256 points and arrange groups in two
  rows: 1–5 and 6–9. Keep the game icons and action controls below.
- Published as the latest main release; physical-device confirmation pending.

## 0.3.4 — 2026-10-25 (prerelease; device validation pending)

- Adapt the gameplay framebuffer to portrait/landscape window proportions,
  with the top bar and sidebar repositioned without resetting production.
- Add 1x–3x battlefield pinch zoom while keeping the interface at its normal
  size; retain two-finger pan, two-finger tap and hold for right-click.
- Offer Control+wheel battlefield zoom on macOS and with a connected mouse.
- Use groups 1–9 in a horizontal strip, with group modes and orders in a
  compact two-column layout below. Keep collapse and drag controls.
- Decode Force Attack and Force Move icons from the game's own cursor frames.
- Restore the original CnCGEdit weapon labels, including High-V Machine Gun
  and Ballistic Charges. Saved numeric rules remain unchanged.
- Includes the keyboard, draggable toolbar, and proportional-layout changes
  from 0.2.9–0.3.3, which were not previously published to GitHub.

## 0.3.3 — 2026-10-25 (device validation pending)

- Restore CnCGEdit’s familiar Ballistic Charges name alongside 155 mm artillery.

- Resolve the Orders overlay through the retained SDL game-window ID when
  keyboard focus is temporarily absent.
- Restore overlay stacking and cancelled drag recognizers after keyboard
  dismissal, and avoid inheriting keyboard animations for toolbar geometry.
- Keep the toolbar refresh timer active in common run-loop modes.

## 0.3.2 — 2026-10-25 (device validation pending)

- Ignore keyboard-show notifications from native UIKit editors when SDL's
  hidden field is not the first responder. Those notifications previously
  could activate SDL text input and reposition the game behind native dialogs.
- Add a Done accessory button to SDL's software keyboard. Dismissal stops
  text input, resigns the responder and restores the game view position.
- Always resign SDL's responder when stopping text input, even if delayed
  visibility notifications incorrectly report that its keyboard is hidden.
- Retain the user-confirmed centered cover layout from v0.3.1.

## 0.3.1 — 2026-10-25 (device validation pending)

- Start the Orders toolbar as a draggable circle; tap to expand/collapse, drag
  the circle or heading, and retain a clamped relative position after rotation.
- Migrate previous Fill defaults to proportional fit. Portrait remains
  proportional even with Fill selected. Balance horizontal safe-area margins.
- Track SDL text-edit ownership through focus loss/destruction, end stale
  single-player battlefield text sessions, and restore keyboard-adjusted views
  using window-local bounds.
- Suppress the desktop-style enlargement warning on phones.

## 0.3.0 — 2026-10-25 (device validation pending)

- Add a native iOS Orders & Groups tray with Stop, Guard, Scatter, one-target
  Force Attack/Move and Cancel.
- Expose all ten native control groups with Recall, Assign, Add and Center.
- Compact screens use separate Orders/Groups tabs; larger displays show both.
- Retain v0.2.9 scene bounds and display refresh fixes.
- Record production queues, Remastered artwork and Red Alert/RedEdit98 as
  future plans in docs/WIREPROOF-FUTURE-PLANS.md.

## 0.2.9 — 2026-10-25 (device validation pending)

- Keep UIKit fullscreen views within active scene/window bounds rather than
  replacing their frame with physical-screen geometry.
- Recheck actual drawable, window and safe-area geometry before each Apple
  frame so delayed display transitions do not retain a stale viewport.
- Keep rendering and touch coordinates based on the same refreshed layout.
- Add cover/inner-size transition coverage for fit and fill presentation.
- iPadOS and Universal 2 macOS compile; 25 host tests pass. Physical Duo
  cover-screen alignment remains pending user verification.

## 0.2.3 — 2026-08-15

This release publishes the current shared Apple-platform source together with
a signed, notarized Universal 2 macOS package for Apple Silicon and Intel.

### Added

- Native visionOS command-window target, build guide, simulator/device
  workflows, and physical Vision Pro validation.
- Vision Pro gaze and pinch input, selection-box gestures, edge and look-to-
  scroll map movement, and mission-safe gesture-state handling.
- Touch-first iPad map scrolling, accurate drag selection, contextual move and
  attack feedback, Apple Pencil input, and software-keyboard support.
- Touch, Pencil, mouse, and trackpad shortcuts for skipping videos and
  cutscenes.
- Expanded optional modern-art mode with GDI and Nod infantry, Buggy/Humvee,
  mobile construction vehicles, Power Plants, Barracks/Hand of Nod, and
  Construction Yards.
- Deterministic artwork-atlas builders, source references, validation, and the
  modern-art asset contract for future contributors.

### Changed

- Shared rendering, settings, localization, import, save, audio, and
  multiplayer behavior now explicitly covers iPadOS, macOS, and visionOS.
- Modern unit and structure overlays preserve classic gameplay state while
  matching movement direction, health display, construction activity, map
  clipping, and faction presentation.
- iPad input differentiates taps, selection drags, one- and two-finger map
  movement, Pencil, pointer accessories, and text-entry focus more reliably.
- Vision Pro input is reset across mission, dialog, and lobby transitions so
  the same controls remain available throughout campaigns and multiplayer.

### Fixed

- Right-edge gaze scrolling on Vision Pro now uses the complete command-window
  width.
- visionOS builds made with pre-26 SDKs now compile without the optional
  Look-to-Scroll API and retain the custom edge-scroll fallback.
- Modern artwork no longer reveals enemies through fog of war, leaks over the
  sidebar or menus, or remains visible after leaving a mission.
- Infantry and vehicle modern artwork follows the commanded travel direction.
- Touch scrolling no longer leaves stale building fragments or a frozen
  selection cursor on the map.
- Selection rectangles align with the user's touch point and remain usable
  after attaching or removing a keyboard accessory.

### Known limitations

- Multiplayer remains a beta and needs further long-session, adverse-network,
  suspend/recovery, and maximum-player testing.
- Native visionOS is a physical-device-tested prototype. Source and build
  instructions are public, but there is no public visionOS binary yet.
- Modern artwork is optional and currently covers an initial set of units and
  structures; the original graphics remain the complete fallback.

## 0.2.2 — 2026-08-13

- Aligned public version metadata for iPadOS and macOS at 0.2.2 (202).
- Centralized Apple bundle version metadata and added a CI parity check.
- Retained the signed, notarized Universal 2 macOS package and all gameplay,
  multiplayer, window, rendering, import, save, and audio improvements from
  0.2.1.

No release contains original Command & Conquer game data. Players must supply
their own lawfully usable C&C Gold GDI and Nod discs or disc images.
