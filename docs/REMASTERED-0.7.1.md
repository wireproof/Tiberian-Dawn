# Remastered controls and production — 0.7.1 (701)

2026-10-26. Preview update; physical-device regression testing remains pending.

## Changes

- Remastered mode uses the Collection's top-bar panels, GDI/Nod emblems, sidebar panel and repair/sell/map artwork. Existing control geometry, radar operation, power display and scroll controls are retained. Original mode retains classic artwork. This adapts the source artwork to this port's layout, rather than reproducing the Collection's entire interface.
- Green/red building footprints render above the Remastered terrain pass.
- Sidebar cameos clip to their visible strip while scrolling. Production clocks use explicit opacity, with READY/HOLD labels and queue counts; palette ghost-table differences no longer overwrite the artwork.
- Repeated unit-icon presses queue production in FIFO order within infantry, vehicle and aircraft categories (up to 99 waiting entries per category). The badge counts waiting orders, excluding the active factory item once acknowledged. Right-click removes a waiting matching item; otherwise existing hold/cancel behavior applies. Insufficient funds and blocked exits retain existing game behavior.
- The floating Orders panel offers separate infantry and vehicle rally destinations and a clear action. Select a production building and click empty ground for the same operation on Mac. Newly produced units receive normal move events after clearing their exit; harvesters retain harvesting behavior. Aircraft are not assigned ground rally points.
- Unchanged UI overlays reuse GPU textures rather than allocating replacements every frame. This reduces allocation work; it is not a measured device FPS claim.

Queues and rally destinations are session controls: loading or starting a mission clears them. They do not alter the legacy save format or multiplayer event protocol. Automatic movement uses existing command events; replays do not generate new commands.

## Private assets

Import the private full pack as described in [0.7.0](REMASTERED-0.7.0.md), then run:

```
python3 scripts/import-remastered-graphics.py /path/to/Collection /path/to/RemasteredArt --append-chrome
```

The chrome importer reads original MTD atlas coordinates. Extracted Collection assets and private signed bundles are not included in the repository or public release. Public gameplay clips were supplied by the user and show the previous preview build, including the bugs that motivated this update.

## Verification

- 27 host tests, including FIFO/capacity/cancel/retry behavior and placement lifecycle.
- Unsigned iOS compile, developer-signed iOS build, and Universal 2 Mac package.
- Isolated live Mac session: loaded copied save, checked actual UI artwork, observed green/red placement cells, placed a factory, queued tanks with a visible waiting counter, and observed a tank follow a vehicle rally destination.
- Source asset payloads remain private. Duo installation is separate from runtime validation and does not launch the app.

Remaining coverage: physical Duo/iPad touch, sustained performance, infantry and Nod airstrip rally paths, all animations, and multiplayer sessions. These are not established by compilation or host tests.
