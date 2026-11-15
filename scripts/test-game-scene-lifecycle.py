#!/usr/bin/env python3
"""Check RA scene routing source and execute its handler with the real event queue."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
root = Path(__file__).resolve().parent.parent
source = (root / "redalert/ipados_bridge.mm").read_text()
start = source.index("static void RAHandleSceneLifecycle(bool foreground, bool enteredBackground)")
end = source.index("static void RAInstallLifecycleBridge()", start)
registration = source[end:source.index('#include "common/wireproof_orders.h"', end)]
assert registration.index("notification.object != scene") < registration.index("RAHandleSceneLifecycle(foreground, background)")
assert "Video_Get_Game_Window()" in source[source.index("static UIWindowScene* RAEngineScene()"):start]
termination = registration.split("UIApplicationWillTerminateNotification", 1)[1]
assert termination.index("RABeginBackgroundTask();") < termination.index("Queue_App_Lifecycle_Event(APP_LIFECYCLE_TERMINATING)")
task_source = source[source.index('extern "C" void RedAlert_EndBackgroundTask'):start]
assert "expirationHandler:^{ RedAlert_EndBackgroundTask(); }" in task_source
assert "!Video_Game_Window_Is_Visible() || RABackgroundTask != UIBackgroundTaskInvalid" in task_source
assert task_source.index("RABackgroundTask = UIBackgroundTaskInvalid;") < task_source.index("endBackgroundTask:task")
for engine in ("redalert", "tiberiandawn"):
    focus = (root / engine / "winstub.cpp").read_text().split("void Focus_Restore(void)", 1)[1]
    assert focus.index("if (!Video_Game_Window_Is_Visible()) return;") < focus.index("Start_Primary_Sound_Buffer")
with tempfile.TemporaryDirectory(prefix="game-scene-lifecycle-") as temporary:
    directory = Path(temporary)
    (directory / "game_scene_lifecycle_under_test.h").write_text(source[start:end])
    binary = directory / "test"
    command = shlex.split(os.environ.get("CXX", "c++"))
    command += ["-std=c++17", "-I", str(root), "-I", str(directory),
                str(root / "tests/game_scene_lifecycle.cpp"), str(root / "common/app_lifecycle.cpp"),
                "-o", str(binary)]
    subprocess.run(command, check=True)
    subprocess.run([str(binary)], check=True)
print("PASS: exact scene filter source, both hidden-engine focus gates, duplicate/rapid lifecycle edges and actual-background task ordering")
