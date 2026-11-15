// Run scripts/test-game-scene-lifecycle.py. The handler comes from the RA bridge.
#include "common/app_lifecycle.h"
#include <cassert>
static bool visible = true, rendering = true, audio = true;
static int restores = 0, losses = 0, backgroundTasks = 0;
bool Video_Game_Window_Is_Visible() { return visible; }
void Set_Video_Render_Active(bool value) { rendering = value; }
void Focus_Loss() { ++losses; audio = false; }
void Focus_Restore() { assert(visible); ++restores; audio = true; }
void RABeginBackgroundTask() {
    assert(Is_App_In_Foreground()); // Must begin before the real background queue edge.
    if (visible) ++backgroundTasks;
}
#include "game_scene_lifecycle_under_test.h"
int main() {
    RAHandleSceneLifecycle(false, false); // Resign active: no recovery or background task.
    RAHandleSceneLifecycle(false, false);
    assert(losses == 1 && !rendering && !audio && backgroundTasks == 0);
    assert(Consume_App_Lifecycle_Events() == APP_LIFECYCLE_NONE);
    RAHandleSceneLifecycle(true, false); // An alert dismissal must still restore audio.
    assert(restores == 1 && rendering && audio);
    assert(Consume_App_Lifecycle_Events() == APP_LIFECYCLE_NONE);
    RAHandleSceneLifecycle(false, false);
    RAHandleSceneLifecycle(false, true);
    RAHandleSceneLifecycle(false, true); // Duplicate background must not start another task.
    assert(losses == 2 && !rendering && !audio && backgroundTasks == 1);
    assert(Consume_App_Lifecycle_Events() == APP_LIFECYCLE_ENTERED_BACKGROUND);
    RAHandleSceneLifecycle(true, false);
    RAHandleSceneLifecycle(true, false);
    assert(restores == 2 && rendering && audio);
    assert(Consume_App_Lifecycle_Events() == APP_LIFECYCLE_ENTERED_FOREGROUND);
    visible = false; rendering = false; audio = false;
    RAHandleSceneLifecycle(false, false);
    RAHandleSceneLifecycle(false, true);
    RAHandleSceneLifecycle(true, false);
    assert(restores == 2 && backgroundTasks == 1 && !rendering && !audio);
    const auto events = Consume_App_Lifecycle_Events();
    assert(events == (APP_LIFECYCLE_ENTERED_BACKGROUND | APP_LIFECYCLE_ENTERED_FOREGROUND));
}
