# v0.5.9 input recovery candidate — 2026-10-26

This candidate addresses two verified input-handling defects. It does not yet prove the cause of the intermittent selection lock shown in the v0.5.8 recording.

- Floating Game → Cancel now cancels the engine action, including repair, sell, or pending building placement, rather than clearing only the force-order modifier. Cancelling placement keeps the completed building available in the sidebar.
- A new touch press discards stale gadget capture and tactical rubber-band state from an interrupted prior gesture. Ordinary mouse capture is unchanged.
- Saved drag/stick mode, cheats, UI settings, and control positions remain intact.

## Device retest

1. Load the same mission/save used in the 52-second recording. Tap and box-select units, issue orders, and switch drag/stick mode repeatedly.
2. Open/dismiss Control Center, take a screenshot, open/close the floating panel, and rotate. Repeat selection without building anything.
3. Enter Repair, then use floating Game → Cancel; verify unit selection works. Repeat for Sell and for a completed building awaiting placement. Verify the building remains ready after Cancel.
4. If selection locks again, try floating Game → Cancel before constructing anything. Record whether that restores selection, plus the preceding action and device/orientation.
5. Verify group assignment/recall and normal sidebar button presses still work.

## Scope

No Remastered artwork importer, icon picker, or icon replacement is included in this focused recovery candidate. The four-faction icon picker remains requested follow-up work. Native wireless installation requires a valid development signing identity and device provisioning; the ad-hoc IPA remains a LiveContainer candidate.
