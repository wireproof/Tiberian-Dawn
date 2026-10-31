# iOS 0.7.3 device check

Build 703 is a test candidate. Install it over 0.7.2 to preserve local saves and settings. The complete iOS release IPA includes classic game data, music, and Remastered artwork; the public source archive contains code without those assets. The public IPA must be signed for the destination device.

## Check on iPad and Duo

1. In both Original and Enhanced classic graphics, open a mission. The Game controller button should open a separate command toolbar. Its orientation button should switch between vertical and horizontal layouts. The Cheats and Options button should still open its own panel.
2. Select units, assign a control group by holding a number, recall it by tapping, and try Stop, Guard, Scatter, Force Attack, Force Move, Cancel, and both rally destinations. Drag each toolbar, rotate the device, and confirm the positions remain usable.
3. In Enhanced classic, fire an Ion Cannon and launch an airborne projectile. The beam should end at the strike point; the projectile's shadow should not become a second full-color projectile. Check the Obelisk laser and building placement preview too.
4. Save and reload a mission with infantry and vehicle rally destinations. Try a selected unit after selling a building. Change game speed, close and reopen the app, then check the saved setting.
5. On iPad, rotate portrait to landscape during mission select and a cutscene. This reported distortion still needs a device reproduction; this build has no targeted rotation change.

Report a regression with the device, graphics mode, exact steps, and a screenshot or short recording using the repository's GitHub issue forms. Installation and a successful compile do not establish that gameplay checks passed.
