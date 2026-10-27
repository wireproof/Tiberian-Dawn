# 0.6.3 device testing

Classic tooltip text now renders into an independent palette buffer and is copied to the presentation framebuffer before its dirty-region upload. The existing final Metal overlay restores that region above artwork. Labels no longer depend on map pixels remaining intact between drawing and presentation. The same path serves iOS and macOS; menus clear the pending overlay with world artwork.

Experimental replacement units and buildings are disabled both at the engine availability checks and compositor. Original sprites remain visible. The style option is now called Enhanced classic and retains the image filter; this is not Remastered artwork.

Validated: 26 host tests, backup/cloud tests, Apple parity, unsigned iOS compile, development-signed iOS build, Universal 2 macOS package. Device rendering confirmation remains pending, especially the selected Construction Yard label near the sidebar and tooltip expiry/scrolling.

User confirmed Duo-to-iPad save delivery in 0.6.2, including the named iCloud save and the iPad receipt status. Reverse transfer and settings application are not separately verified.
