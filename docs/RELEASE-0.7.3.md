# v0.7.3 — iOS build 703

Build 703 was compiled, signed, and installed over the existing app on the owner's iPad and Duo. Device gameplay checks are still pending; this release does not mark the associated bugs or feature requests as verified.

## What changed

- Added a separate, movable Game command toolbar with control groups, orders, and an orientation toggle. Cheats and Options remain in their own panel. [Feature #12](https://github.com/wireproof/Tiberian-Dawn/issues/12)
- Added candidate fixes for the Obelisk laser, duplicated projectile shadows, the Ion Cannon beam, Remastered scene transitions, and Mission Accomplished text. [Issues #1](https://github.com/wireproof/Tiberian-Dawn/issues/1), [#3](https://github.com/wireproof/Tiberian-Dawn/issues/3), [#6](https://github.com/wireproof/Tiberian-Dawn/issues/6), [#8](https://github.com/wireproof/Tiberian-Dawn/issues/8)
- Saved infantry and vehicle rally destinations by mission; persisted game speed; improved player-unit defense and Force Move on occupied cells. [Issues #5](https://github.com/wireproof/Tiberian-Dawn/issues/5), [#7](https://github.com/wireproof/Tiberian-Dawn/issues/7), [#9](https://github.com/wireproof/Tiberian-Dawn/issues/9), [#10](https://github.com/wireproof/Tiberian-Dawn/issues/10)
- Made partial changes for the multiplayer custom-rules path and touch Sell mode. [Issues #2](https://github.com/wireproof/Tiberian-Dawn/issues/2), [#4](https://github.com/wireproof/Tiberian-Dawn/issues/4) remain reported. The iPad rotation distortion in [#11](https://github.com/wireproof/Tiberian-Dawn/issues/11) still needs reproduction and has no targeted fix in this build.

## Downloads and testing

Download the complete iOS IPA below. It includes classic game data, music, and Remastered artwork, but no personal developer provisioning profile. Sign the IPA for your device before installation; iCloud sync needs a compatible entitlement. Do not uninstall the existing app to update, because that can remove local saves.

The public source archive remains asset-free. Clone with submodules to build: `git clone --recurse-submodules https://github.com/wireproof/Tiberian-Dawn.git`. The attached `SHA256SUMS` checks the IPA download.

Please use the [device test checklist](https://github.com/wireproof/Tiberian-Dawn/blob/v0.7.3/docs/TESTING-0.7.3.md) and comment on an [existing issue](https://github.com/wireproof/Tiberian-Dawn/issues) with the device, graphics mode, steps, and screenshot or recording. Issues marked `stage: implemented` remain open until confirmed on a device.
