# Red Alert Workshop

The Red Alert Options deck opens its own Workshop. Stock and three independent
custom preset slots use the same behavior on UIKit and AppKit. AppKit has a
native dialog editor; integration into a native Red Alert macOS launcher still
requires that target to compile and expose the Red Alert platform bridge.

## Supported edits

- Vehicles, infantry, aircraft, ships and buildings: cost, health, sight in cells,
  ammunition (`-1` unlimited), technology level (`-1` unavailable), armor, primary
  weapon, secondary weapon, selection, targetability and combat damage immunity.
- Mobile types additionally: speed in engine units. Vehicles, infantry and ships
  additionally support cloaking; aircraft are excluded because their constructor
  does not consume that flag.
- Buildings additionally: ore storage, generated power and consumed power.
- Weapons: damage (negative values heal), reload ticks, range (256 units per
  cell), and burst count.

Unit and building labels come from Red Alert's localized names; weapon labels
use recognizable Red Alert roles. Persistent identifiers remain INI names.
Weapon dropdowns include only allocated weapon types. Armor and weapon values
must match actual choices, not simply fall within a numeric range.

These are type edits: **every owner, including enemies, is affected**. Ownership,
prerequisite masks, factory category, build availability beyond technology level,
warheads, projectile classes and arbitrary INI fields are intentionally not
exposed. The Apply to… action copies a selected subset of settings to selected compatible
types. Only targets supporting every selected field/value are offered. A review
step names the settings and targets before applying, and unselected fields are
left unchanged.

## Timing and isolation

Edits are saved immediately but do not mutate a running mission. Start a new
mission to apply them. Restarting is also safe; loading an existing save is not
an application step and does not rebuild existing objects or house totals.

Initial type defaults are captured after RULES.INI, Aftermath and localized
strings load. Before each scenario reload, the captured fields are restored to
prevent values leaking from the previous custom preset. The scenario's own
rules then load, followed by validated custom overrides before objects and
house totals are created. Skirmish MPLAYER.INI overrides are followed by another
application pass. A Stock preset leaves scenario-specific rules intact.

Custom preferences have the prefix `Wireproof.RedAlert.Workshop.`; they never
read or alter Tiberian Dawn's `WPActiveRules` / `WPRules.*` preferences. Invalid
profiles select Stock. Malformed, fractional, non-finite, out-of-range and
unsupported-choice values never reach the simulation.

Network play is rejected when valid selected edits exist or modified rules are
still applied in memory. After switching to Stock, start a fresh mission or
restart to clear applied edits before multiplayer. Single-player campaign and
skirmish remain available. Replay playback never applies Workshop overrides.

## Validation

Host test (no game assets required):

```
xcrun clang++ -std=c++17 -fobjc-arc -Iredalert tests/redalert_workshop.mm \
  -framework Foundation -framework AppKit -o /tmp/wireproof-ra-workshop-test
/tmp/wireproof-ra-workshop-test
```

Tests cover Stock protection, all three preset slots, TD preference isolation,
integer/range/choice validation, malformed persisted values, unknown profiles,
rule grouping, selective batch copying, target validation, preservation of
unselected fields, and pending/applied multiplayer restrictions. The unique test
executable uses its own defaults domain and does not touch the game's settings.

UIKit/AppKit syntax checks and engine syntax checks do not substitute for a
full simulator/device build or a Universal 2 macOS package gate. Manual checks
still needed: edit/save/reset each preset, start two different missions and
switch Stock between them, inspect edited health/cost/power and weapon behavior,
verify both multiplayer entry points reject modified rules, and load an existing
save without promising retroactive changes to its objects.
