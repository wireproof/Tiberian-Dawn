# v0.7.4 device verification

Build 710 compiled, passed strict signing checks, and was installed on the owner's Duo. The owner tested the current Duo gameplay and reported the laptop controls and graphics below as fixed. Installation and owner reports are distinguished from tests run by the maintainer.

| Area | Duo result | Other device status |
| --- | --- | --- |
| Laptop deck Build, Commands, Radar, Cheats, and Options | Owner reports working; duplicate bottom buttons found later | iPad not retested |
| Radar fills the lower pane and tapping it moves the battlefield | Owner verified | iPad not applicable |
| Laptop/Remastered toggles appear only in Options | Published build 710 has duplicate footer buttons; owner screenshots verify the build 711 correction in [#16](https://github.com/wireproof/Tiberian-Dawn/issues/16) | iPad not applicable |
| Sidebar toggle, movable Options panel, joystick, placement panning, production status | Owner marked [#13](https://github.com/wireproof/Tiberian-Dawn/issues/13) verified | iPad not retested |
| Remastered trees, Tiberium, walls, projectiles, Ion Cannon, and Obelisk | Owner reported fixed on Duo; related issues closed | iPad not retested |
| Waypoints after full app relaunch | Owner verified both rally points after quitting and reopening on Duo; [#7](https://github.com/wireproof/Tiberian-Dawn/issues/7) closed | Original iPad report not separately retested |
| Two-column Cheats switches and restored full assets in build 712 | Owner verified layout, Remastered art, and pictured Build tiles on Duo; [#18](https://github.com/wireproof/Tiberian-Dawn/issues/18) and [#19](https://github.com/wireproof/Tiberian-Dawn/issues/19) closed | iPad not retested |
| Build grid fills deck, pictured queue counts, and mission videos use upper screen in build 713 | Code compiled; Duo gameplay verification pending | iPad not applicable |
| Force Move and crushing infantry | Not verified; [#10](https://github.com/wireproof/Tiberian-Dawn/issues/10) open | Not verified |

When reporting a remaining problem, note the device and screen, fold/orientation, graphics style, stock or custom rules, exact steps, expected and actual result, and a screenshot or short recording. Add a comment to the existing [issue](https://github.com/wireproof/Tiberian-Dawn/issues) when one matches.

For build 713 on Duo, open Build with several rows of structures and confirm the tiles fill the panel to its bottom edge. Queue multiple infantry and vehicles and confirm each pictured tile shows its `+N` count while progress and READY remain readable. Play a mission opening and ending video in laptop mode: each should fit within the upper gameplay screen. Also test one video with laptop mode off to check that ordinary full-screen presentation still centers normally.
