# Remastered vehicle preview — 0.6.4

This private preview uses actual installed Remastered Collection textures for MTNK, JEEP and BGGY. It does not replace infantry, buildings or terrain. Generated replacement sprites remain disabled. Enable the existing graphics toggle to display the imported vehicles.

Run `python3 scripts/import-remastered-vehicles.py /path/to/remastered-install /private/path/ModernArt` with Pillow and numpy installed. The importer reads CONFIG.MEG, TEXTURES_TD_SRGB.MEG and TEXTURES_PATCHES_SRGB.MEG, resolves the original tileset ShapeIndex mapping, restores crop offsets, and applies GOOD/BAD_UNIT team colors following the bundled map editor's TextureManager algorithm. Original 128px vehicle canvases are padded to 192px without resampling. This preserves their 24px classic footprint while tank canvases display at 36px.

Keep the generated pack private. Copy it into the application's ModernArt resource directory for a private signed build, or the user-data ModernArt directory. Do not commit or publish extracted artwork. The provenance manifest records SHA-256 of consumed archive members and output atlases.

The engine retains classic body/turret frame selection and recoil coordinates. Unsupported owners, missing artwork and unusual visibility states retain classic artwork. Mixed classic/HD occlusion remains a preview limitation. This is not a full Remastered renderer.

Evidence: the retained 2026-10-26 REA/source research established ShapeIndex-based object export and the map editor's tileset, crop and team-color contracts. No simulation DLL transplant or REMASTER_BUILD switch is used.

## Validation on 2026-10-26

- All 192 classic shape mappings imported (64 per vehicle); atlas bounds and cropped image dimensions validated. Contact-sheet review confirms actual vehicle artwork and GDI/Nod color variants.
- All 26 host tests passed; unsigned and development-signed iOS builds succeeded; Universal2 macOS packaging passed.
- Apple parity and backup round-trip/rollback tests passed.
- Private IPA SHA-256: `e1d6a2c5c75c8aedf6aaaf8e5d4b04e9c42a43942f709a2c3ba0eb3d6112b1bc`.
- Duo installation readback confirms 0.6.4 build 604. In-game visual approval remains pending. iPad was unavailable over wireless; installation remains pending.
