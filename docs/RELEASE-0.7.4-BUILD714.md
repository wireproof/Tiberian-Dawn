# v0.7.4 — iOS build 714

This full-asset iOS update includes the previous Duo laptop deck and Remastered graphics improvements. It incorporates the owner-verified build 711 duplicate-control fix and build 712 two-column Cheats layout and restored artwork. The build 710 release remains available separately.

## New since build 710

- Production tiles show queue counts, progress, and READY status; taller Build grids fit the deck and cameos use uncropped artwork.
- The lower Radar tab supports map dragging. Before radar is built, the same area acts as a map trackpad.
- Mission movies use the upper screen in Duo laptop mode. Build 714 clears retained game UI before playback to address a top-bar artifact reported in build 713.
- Options includes an independent **Always portrait** switch beside **Laptop deck**, allowing the deck on a non-folding iPhone or iPad Pro in portrait.

## Device status

The signed development build was installed on Duo and iPad Pro, and both devices reported v0.7.4 build 714. The maintainer did not open the app. The owner tested earlier Duo builds; the latest cameo, movie, radar-drag, queue, and Always portrait changes still need gameplay verification. Follow [the checklist](https://github.com/wireproof/Tiberian-Dawn/blob/wireproof/docs/TESTING-0.7.4.md) and the [issue tracker](https://github.com/wireproof/Tiberian-Dawn/issues).

## Download

The attached **unsigned** IPA includes the classic game data and music plus ModernArt and RemasteredArt. Sign it for your device before installing. Update over the existing app to preserve local saves. The source archive does not bundle game data. Verify the IPA against `SHA256SUMS`.

## Next

Red Alert integration is starting for v0.7.5. The planned game selector, Allied and Soviet campaigns, skirmish, and multiplayer are not included in this build.
