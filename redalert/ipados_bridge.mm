#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>

#include "platform/apple/ipados_platform.h"
#include "common/ipados_audio_engine.h"

static void RAInstallCommandDeck();
static void RAInstallLifecycleBridge();

// The Red Alert engine is compiled independently during bring-up. Its
// immutable disc folders are read from the app bundle; saves use the separate
// vanillara user suffix.
// The combined app will choose the engine before entering either game loop.
extern "C" bool TiberianDawn_PrepareGameData(void)
{
    @autoreleasepool {
        NSURL *bundleData = [[NSBundle mainBundle] resourceURL];
        bundleData = [bundleData URLByAppendingPathComponent:@"RAData" isDirectory:YES];
        NSFileManager *files = [NSFileManager defaultManager];
        if (!bundleData) {
            NSLog(@"Red Alert bundle data directory is unavailable");
            return false;
        }
        for (NSString *name in @[@"REDALERT.MIX", @"allied/MAIN.MIX", @"soviet/MAIN.MIX"]) {
            NSURL *source = [bundleData URLByAppendingPathComponent:name];
            NSDictionary *attributes = [files attributesOfItemAtPath:source.path error:nil];
            if (![attributes[NSFileSize] respondsToSelector:@selector(unsignedLongLongValue)]
                || [attributes[NSFileSize] unsignedLongLongValue] == 0) {
                NSLog(@"Red Alert bundle asset missing: %@", name);
                return false;
            }
        }
        RAInstallLifecycleBridge();
        dispatch_async(dispatch_get_main_queue(), ^{RAInstallCommandDeck();});
        NSLog(@"Red Alert bundle data is available");
        return true;
    }
}

extern "C" void TiberianDawn_ConfigureAudioSession(void)
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

extern "C" bool TiberianDawn_RebuildAudioEngine(void) { return IPad_Audio_Rebuild(); }
extern "C" void TiberianDawn_SetCompactWindowWarning(bool) {}

#import <UIKit/UIKit.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include "common/app_lifecycle.h"
// Keep legacy video.h/Rect out of UIKit translation units (MacTypes defines Rect).
extern SDL_Window* Video_Get_Game_Window(void);
extern bool Video_Game_Window_Is_Visible(void);
extern void Set_Video_Render_Active(bool);
extern void Focus_Loss(void);
extern void Focus_Restore(void);

static UIWindowScene* RAEngineScene()
{
    SDL_Window* sdl = Video_Get_Game_Window();
    SDL_SysWMinfo info;
    SDL_VERSION(&info.version);
    if (!sdl || !SDL_GetWindowWMInfo(sdl, &info)) return nil;
    return info.info.uikit.window.windowScene;
}

static UIBackgroundTaskIdentifier RABackgroundTask = UIBackgroundTaskInvalid;

extern "C" void RedAlert_EndBackgroundTask(void)
{
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ RedAlert_EndBackgroundTask(); });
        return;
    }
    if (RABackgroundTask == UIBackgroundTaskInvalid) return;
    const UIBackgroundTaskIdentifier task = RABackgroundTask;
    RABackgroundTask = UIBackgroundTaskInvalid;
    [UIApplication.sharedApplication endBackgroundTask:task];
}

static void RABeginBackgroundTask()
{
    if (!Video_Game_Window_Is_Visible() || RABackgroundTask != UIBackgroundTaskInvalid) return;
    RABackgroundTask = [UIApplication.sharedApplication
        beginBackgroundTaskWithName:@"Red Alert recovery save"
        expirationHandler:^{ RedAlert_EndBackgroundTask(); }];
}

static void RAHandleSceneLifecycle(bool foreground, bool enteredBackground)
{
    static bool sceneActive = true;
    const bool changed = sceneActive != foreground;
    sceneActive = foreground;
    // Resigning active (Control Center, alerts) pauses immediately but is not
    // a recovery-save request. Start the task before queuing real background.
    if (enteredBackground && Is_App_In_Foreground()) RABeginBackgroundTask();
    if (foreground || enteredBackground) {
        Queue_App_Lifecycle_Event(foreground ? APP_LIFECYCLE_ENTERED_FOREGROUND
                                            : APP_LIFECYCLE_ENTERED_BACKGROUND);
    }
    if (!changed) return;
    if (foreground) {
        if (Video_Game_Window_Is_Visible()) {
            Focus_Restore();
            Set_Video_Render_Active(true);
        }
    } else {
        Focus_Loss();
        Set_Video_Render_Active(false);
    }
}

static void RAInstallLifecycleBridge()
{
#if defined(WP_COMBINED_APP)
    // The existing scene delegate belongs to the host SDL image. Use blocks
    // compiled into this image, not a duplicate SDL Objective-C observer class.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
        for (NSNotificationName name in @[UISceneWillDeactivateNotification,
                                          UISceneDidEnterBackgroundNotification,
                                          UISceneDidActivateNotification]) {
            [center addObserverForName:name object:nil queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification* notification) {
                UIWindowScene* scene = RAEngineScene();
                if (!scene || notification.object != scene) return;
                const bool foreground = [notification.name isEqual:UISceneDidActivateNotification];
                const bool background = [notification.name isEqual:UISceneDidEnterBackgroundNotification];
                RAHandleSceneLifecycle(foreground, background);
            }];
        }
        [center addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil
                            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*) {
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_LOW_MEMORY);
        }];
        [center addObserverForName:UIApplicationWillTerminateNotification object:nil
                            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification*) {
            RABeginBackgroundTask();
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_TERMINATING);
            Focus_Loss();
            Set_Video_Render_Active(false);
        }];
    });
#endif
}

#include "common/wireproof_orders.h"
#include "common/wireproof_laptop.h"
#include "common/wireproof_cheats.h"
#include <cmath>

// Red Alert retains its own cheat preferences and engine state while the
// native controls share Dawn's layout and interaction implementation.
namespace WPCheats {
Snapshot LoadPreferences() {
    Snapshot s;NSDictionary* p=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"Wireproof.RedAlert.Cheats.v1"];
    auto flag=[&](NSString* key){id v=p[key];return [v isKindOfClass:NSNumber.class] && [v boolValue];};
    s.invincible=flag(@"invincible");s.reveal=flag(@"reveal");s.instant=flag(@"instant");
    s.free=flag(@"free");s.weapons=flag(@"weapons");s.anywhere=flag(@"anywhere");s.unlock=flag(@"unlock");s.damagedHealth=flag(@"damagedHealth");
    auto speed=[&](NSString* key){id v=p[key];if(![v isKindOfClass:NSNumber.class])return 4;double n=[v doubleValue];return std::isfinite(n)&&n==std::floor(n)&&n>=1&&n<=12?(int)n:4;};
    s.infantry=speed(@"infantry");s.vehicles=speed(@"vehicles");s.aircraft=speed(@"aircraft");return s;
}
void SavePreferences(const Snapshot& s) {
    [NSUserDefaults.standardUserDefaults setObject:@{@"invincible":@(s.invincible),@"reveal":@(s.reveal),
        @"instant":@(s.instant),@"free":@(s.free),@"weapons":@(s.weapons),@"anywhere":@(s.anywhere),@"unlock":@(s.unlock),@"damagedHealth":@(s.damagedHealth),@"infantry":@(s.infantry),@"vehicles":@(s.vehicles),@"aircraft":@(s.aircraft)} forKey:@"Wireproof.RedAlert.Cheats.v1"];
}
}

extern "C" void RA_InstallOrdersPanel(void);

static void RAInstallCommandDeck() {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // Preserve Red Alert's saved preferences while using the same UI
        // implementation and posture handling as Tiberian Dawn.
        WPLaptop::SetEnabled([NSUserDefaults.standardUserDefaults boolForKey:@"Wireproof.RedAlert.LaptopMode"]);
        WPLaptop::SetAlwaysPortrait([NSUserDefaults.standardUserDefaults boolForKey:@"Wireproof.RedAlert.PortraitDeckAlways"]);
        RA_InstallOrdersPanel();
    });
}

void RA_SaveDeckPreferences(bool laptop,bool portrait) {
    [NSUserDefaults.standardUserDefaults setBool:laptop forKey:@"Wireproof.RedAlert.LaptopMode"];
    [NSUserDefaults.standardUserDefaults setBool:portrait forKey:@"Wireproof.RedAlert.PortraitDeckAlways"];
}

void RA_EnsureCommandDeck() {
    dispatch_async(dispatch_get_main_queue(), ^{RAInstallCommandDeck();});
}
