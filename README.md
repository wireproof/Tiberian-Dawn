# Tiberian Dawn — Wireproof

Native community port for iPhone, iPad and macOS, based on [Cesarus85's Apple port](https://github.com/Cesarus85/Tiberian-Dawn-for-iPad-and-macOS), [Vanilla Conquer](https://github.com/TheAssemblyArmada/Vanilla-Conquer), and Electronic Arts' released source.

## Latest release: v0.4.2

[Download v0.4.2](https://github.com/wireproof/Tiberian-Dawn/releases/tag/v0.4.2).
Camera scrolling now rebuilds the frame to address black patches and sidebar
smearing. Device confirmation and scrolling-performance feedback are pending.
**Double-tap the floating controller** to open a larger circular map joystick.
Drag farther from the center to scroll faster; release to stop. Double-tap
again to return to the normal button. Single-tap still opens Orders & Groups;
drag the normal button to reposition it. Joystick scrolling works even when
Edge scroll is OFF. Physical-device gesture confirmation is pending.

Previous update:
Adds **Instant Build** and **Zero Cost**, fixes battlefield shroud removal,
enlarges radar terrain within its panel, and reduces the touch cursor to 2x.
Instant Build charges the remaining cost when affordable; enable Zero Cost
as well for free instant production. Zero Cost waives remaining construction
costs, not repair charges; classic tooltip prices remain the stock prices.
The larger radar follows the battlefield when the whole map does not fit.
Open the floating controller and tap **Cheats** for money, invincibility,
shroud on/off, extra power, and separate infantry/vehicle/aircraft speed sliders
(0.25–3x). On Mac, use **Option-C** and Apply. Cheats affect your side in
single-player only. Speed and live toggles reset on mission start/load; money
and power remain in saves. Shroud On restores prior exploration plus current
unit sight. Saving while revealed saves that revealed map state.

Edge scroll OFF now blocks both touch and legacy cursor-edge scrolling on iOS.
Save Mission opens without the software keyboard; tap its filename field to type.
The old UI scale label is now Touch size, reflecting its effect on touch targets
and feedback rather than the entire interface.

The controller menu includes a **− / zoom slider / +** control with quarter steps:
0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3.
It defaults to 1.5x and saves your iOS choice. The map zooms while menus, the top
bar, sidebar and compact toolbar retain their size. Option-minus/Option-plus
provide keyboard equivalents. Pinch zoom remains disabled; hold the floating
controller button to pan with your other finger. Device confirmation pending.

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
