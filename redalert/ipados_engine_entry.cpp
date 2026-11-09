// Only this entry point is called by the experimental combined iOS launcher.
// Red Alert's global engine state remains in its own Mach-O image.
extern int RedAlertEngineMain(int argc, char** argv);
#include <os/log.h>
#include <SDL.h>

// The shared SDL video backend has a Tiberian Dawn dock icon hook. Red Alert
// has no command dock yet, so keep that callback local to its engine image.
void WP_Publish_Order_Icon(int, const unsigned char*, int, int) {}

extern "C" __attribute__((visibility("default"))) int WireproofRedAlertRun(int argc, char** argv)
{
    os_log(OS_LOG_DEFAULT, "Red Alert engine: calling main");
    // SDL's UIKit delegate initialized the host executable's SDL copy. The
    // Red Alert image links its own SDL state and must mark it ready too.
    SDL_SetMainReady();
    int result = RedAlertEngineMain(argc, argv);
    os_log(OS_LOG_DEFAULT, "Red Alert engine: main returned %{public}d", result);
    return result;
}
