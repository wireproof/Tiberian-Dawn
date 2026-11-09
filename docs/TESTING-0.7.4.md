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
| Build grid fills deck, pictured queue counts, mission videos use upper screen, and radar/trackpad drags move the map in build 713 | Owner screenshots show the video now on the upper screen but with a top-bar artifact, and Build cameos cropped; queue badges and radar drag still need testing | iPad not applicable |
| Build artwork crop and movie top-bar strip reported in build 713 | Build 714 uses uncropped artwork and clears preserved movie UI; Duo gameplay verification pending | iPad not applicable |
| Always portrait command deck | Build 714 adds a separate saved switch next to Laptop deck; verify with Laptop deck Off in portrait, then rotate to landscape | iPad not retested |
| Force Move and crushing infantry | Not verified; [#10](https://github.com/wireproof/Tiberian-Dawn/issues/10) open | Not verified |

When reporting a remaining problem, note the device and screen, fold/orientation, graphics style, stock or custom rules, exact steps, expected and actual result, and a screenshot or short recording. Add a comment to the existing [issue](https://github.com/wireproof/Tiberian-Dawn/issues) when one matches.

For build 714 on Duo, open Infantry, Vehicles, and Buildings and confirm each complete cameo fits inside its tile. Queue multiple infantry and vehicles and confirm each pictured tile shows its `+N` count while progress and READY remain readable. Drag across an active radar to move the map. Before building a Communications Center, drag the blank radar pane as a trackpad and confirm it pans the battlefield without an instruction message. Play a mission opening and ending video in laptop mode: each should fit within the upper gameplay screen with a clean black margin and no game UI strip. Also test one video with laptop mode off. In Options, turn Laptop deck Off and Always portrait On, then confirm the deck appears in upright portrait and disappears in landscape.
