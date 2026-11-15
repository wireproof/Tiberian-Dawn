// Only this entry point is called by the experimental combined iOS launcher.
// Red Alert's global engine state remains in its own Mach-O image.
extern int RedAlertEngineMain(int argc, char** argv);
#include <os/log.h>
#include <SDL.h>

// Feed Red Alert's decoded order cursors to its copy of the shared native
// command dock. The engine remains a separate Mach-O image from Dawn.
void RA_Publish_Order_Icon(int, const unsigned char*, int, int);
void WP_Publish_Order_Icon(int kind, const unsigned char* rgba, int width, int height) {
    RA_Publish_Order_Icon(kind, rgba, width, height);
}

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
