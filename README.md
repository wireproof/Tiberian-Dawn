# Tiberian Dawn — Wireproof

Native community port for iPhone, iPad and macOS, based on [Cesarus85's Apple port](https://github.com/Cesarus85/Tiberian-Dawn-for-iPad-and-macOS), [Vanilla Conquer](https://github.com/TheAssemblyArmada/Vanilla-Conquer), and Electronic Arts' released source.

## Latest release: v0.5.2

[Download v0.5.2](https://github.com/wireproof/Tiberian-Dawn/releases/tag/v0.5.2).

The joystick is now independent: drag its center to scroll and its outer ring
to reposition. **Double-tap** to shrink it into a hand button and switch from
one-finger drag selection to map dragging. Ordinary taps still click.
Double-tap again to return to normal selection and the full joystick.
Map-drag mode resets when leaving gameplay.

Workshop **Apply to…** copies chosen settings to selected compatible units.
Portrait sidebars use five rows on all screens, with a larger 1.625× presentation
and map space beneath the arrows. Instant Weapons recharges Airstrike, the Ion Cannon and
nuke when available. Build Anywhere removes base proximity limits
while preserving terrain and occupancy checks. Both cheats are player-only and
single-player, and reset on mission load.

Tap a group number to select it; hold to replace it with the current selection.
Holding with nothing selected clears that group. Cover and inner displays
remember separate zoom levels.

The controller has **Game, Cheats and Options** tabs. It opens vertically in
portrait and with side-by-side columns in landscape.

The **gamepad is a second floating icon**. Tap it for Orders, Groups, Zoom and
Cheats; drag the icon or open panel header to reposition it. Tap the header to
collapse it. The joystick remains independent, with a slower proportional speed
and half the previous maximum. Map scrolling now clamps signed coordinates before
packing them, preventing large drags past an edge from wrapping across the map.
Adaptive gameplay fills the available safe area without integer-scale borders
or stretching. Taller displays gain additional build slots with scroll arrows
below the expanded list. Mac retains keyboard/controller camera controls and Option-C for cheats.
Joystick size (0.5–2×) and speed (0.25–3×) now have saved sliders with −/+
buttons in 0.25 steps. The portrait menu uses compact button spacing.
The power gauge follows the extended sidebar. Opening Options keeps the adaptive
battlefield size, and the main menu reflows to the available screen with proportional
logo artwork. Physical-device layout confirmation remains pending.

## Release 0.2.8

- Native touch controls and adaptable display layout.
- Mod Workshop with readable unit/building/weapon names, Stock and three custom presets.
- Health, cost, weapons, armor, faction availability, cloaking, combat immunity, building power/storage and more.
- Touch feedback circles are 3 times their previous diameter; the game cursor is restored to its 0.2.6 size. Touch coordinates remain unchanged.
- Bundle identifier: `com.wireproof.tiberiandawn`; title label: `wireproof v0.2.8`.

Download the IPA from this repository's Releases and install/resign with your sideloading tool or LiveContainer. Preserve the existing data container when updating. Workshop changes apply after restarting and beginning a new mission. Shared type edits also affect enemies; custom rules disable multiplayer. Selecting Stock restores compiled rules on restart.

## Source build

```sh
git clone --recurse-submodules https://github.com/wireproof/Tiberian-Dawn.git
cd Tiberian-Dawn
sh scripts/prepare-ipados-dependencies.sh
cmake --preset ipados-device
cmake --build --preset ipados-device-release -- CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

Use the `macos-universal` configure/build presets for macOS. This release was built with Xcode 27.1. Keep the SDL submodule at its recorded commit and apply the supplied patch. Local CMake builds do not include original game data automatically: import data through the app, or place an authorized GameData directory into the built bundle and re-sign it before packaging.

## Validation and limits

Both Apple Release builds and all 26 host tests passed. Workshop persistence/validation tests passed in 0.2.5. The owner reports good gameplay in 0.2.6 on their Duo; the corrected touch indicator in 0.2.8 still needs device confirmation. macOS is an ad-hoc-signed local build, not notarized. Vision Pro and arbitrary workshop combinations are not certified by this fork.

## CnCGEdit credit

The Mod Workshop incorporates settings and behavior learned by reverse-engineering **CnCGEdit 1.2b (C&C Gold Editor)**, created by **BioHazard / Roe Yun Song (1998)**. Its unit categories, editable attributes, weapon/faction choices and reset workflow informed this native implementation.

CnCGEdit's executable and original source code are not included. The workshop is newly implemented against the game engine's native types, with presets and validation. Misleading or unsafe legacy behaviors were deliberately not reproduced. See [the reverse-engineering findings](docs/CNCGEDIT-RESEARCH.txt) for the mapping and differences. CnCGEdit remains copyright its original author; this credit does not imply endorsement.

## Licensing and assets

Source licenses and original notices are preserved; see `tiberiandawn/license.txt`, `redalert/license.txt`, and dependency licenses. The GPL source license does not grant ownership of game artwork/audio. EA owns the classic assets bundled in the release IPA; they are not committed to this source repository or relicensed as GPL.

The requested release includes the classic soundtrack. EA's [current modding guidelines](https://www.ea.com/games/command-and-conquer/news/modding-faq) explicitly exclude game music files from mods. The historic freeware release is not represented here as an unrestricted redistribution license. This project is unofficial, free and non-commercial.

Research notes: `docs/CNCGEDIT-RESEARCH.txt`. Historical upstream documentation is retained in `docs/UPSTREAM-README.md`; its release/notarization claims refer to upstream, not this fork.
