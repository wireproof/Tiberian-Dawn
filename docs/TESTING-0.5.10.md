# 0.5.10 device checks — 2026-10-26

- Main menu → Saves / Mod Workshop → App Icon: default C&C, GDI, Nod. Switch each, check Home Screen, relaunch and verify selection. Errors must leave the checkmark on the actual icon. LiveContainer host icon changes are not promised.
- macOS: same choices change the Dock icon and persist. Finder retains the signed bundle default.
- Mission Select: verify later GDI missions as well as Nod; launch one from each campaign. The picker now switches GENERAL.MIX while enumerating each campaign and switches back to the chosen campaign before launch.
- Duo cover portrait: sidebar should reach the bottom, with arrows accessible. Rotate and unfold; repeat at 75%, 100%, and 135% UI size.
- In-game Options: all five central buttons must remain inside the dialog at each screen size. Coordinates are refreshed when opening it.
- Small first-mission maps: retest blank/terrain edges and zoom. The sidebar extent and Options alignment have fixes; remaining terrain-edge artifacts are not yet verified resolved.
- Continue 0.5.9 selection-lock testing. If it recurs, try Game → Cancel before placing a building and report whether control returns.

Validation: 26 host tests passed; iOS Release compile passed; Universal 2 macOS package passed; built iPhone and iPad icon metadata contains AppIconGDI and AppIconNod. Physical checks remain pending.
