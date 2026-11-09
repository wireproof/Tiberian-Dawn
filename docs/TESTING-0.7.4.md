# v0.7.4 (704) Duo laptop preview

This is a test build. An iOS Release compile and strict signature check do not establish Duo layout or gameplay behavior.

1. On Duo, open **Options → Game Controls → Visual Controls** and turn **Laptop deck** on. Start a mission, partly fold the inner display into laptop position, and confirm the battlefield occupies the upper half and the command deck appears below. Open the Duo flat and close it to the cover display; the ordinary layout should return. Turn the option off and confirm the deck stays hidden even when partly folded.
2. Tap an infantry and a vehicle production button several times. Check that queue counts rise, units emerge, and the credits spent match the units produced. Hold a queued unit button; check that its waiting entries cancel and that active production refunds correctly. Keep an eye on stale buttons after construction options change.
3. Select units on the upper battlefield. Test Stop, Guard, Scatter, Force Attack, Force Move, Cancel, group recall, and hold-to-assign. Set separate infantry and vehicle rally points by tapping the upper battlefield, then produce each type and check where it travels.
4. Use both fingers to pan the upper battlefield. Check target taps, sidebar production and building placement, top bar, save/load, and transitions into and out of menus. Repeat with Original and Remastered style.
5. In Remastered style, check the separately reported Duo blur: do terrain, units, buildings, and chrome actually change, or does only image filtering change? Switch styles both during a mission and before starting one. Build 704 requests a full battlefield redraw when the style changes; attach an Original/Remastered pair from the same scene. This candidate fix is not yet verified on Duo.

For each problem, record Duo inner or cover display, fold position, graphics style, stock or custom rules, steps, expected/actual result, and a screenshot or short recording. Keep GitHub issues open until the behavior is confirmed on the physical device.
