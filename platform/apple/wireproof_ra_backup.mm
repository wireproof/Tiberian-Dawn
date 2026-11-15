#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#include <cmath>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif
#define WP_BACKUP_RED_ALERT 1
#include "wireproof_backup.inc"
#include "wireproof_cloud.inc"

void RA_ShowBackup(void) {
    @autoreleasepool {
        void (^show)(void)=^{
#if TARGET_OS_IPHONE
            UIWindowScene *scene=nil;
            for(UIScene *candidate in UIApplication.sharedApplication.connectedScenes)
                if([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive){scene=(UIWindowScene*)candidate;break;}
            if(!scene)return;
            UIWindow *previous=scene.keyWindow;
            UIWindow *host=[[UIWindow alloc] initWithWindowScene:scene];
            RABackupPicker *picker=[[RABackupPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
            host.rootViewController=[[UINavigationController alloc] initWithRootViewController:picker];
            host.windowLevel=UIWindowLevelAlert;[host makeKeyAndVisible];
            while(!picker.finished)[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            [picker cleanup];host.hidden=YES;[previous makeKeyAndVisible];
#else
            ShowBackupPicker();
#endif
        };
        if(NSThread.isMainThread)show();else dispatch_sync(dispatch_get_main_queue(),show);
    }
}

void RA_ShowCloud(void) {
    @autoreleasepool {
        void (^show)(void)=^{
#if TARGET_OS_IPHONE
            UIWindowScene *scene=nil;
            for(UIScene *candidate in UIApplication.sharedApplication.connectedScenes)
                if([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive){scene=(UIWindowScene*)candidate;break;}
            if(!scene)return;
            UIWindow *previous=scene.keyWindow;
            UIWindow *host=[[UIWindow alloc] initWithWindowScene:scene];
            RACloudPicker *picker=[[RACloudPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
            host.rootViewController=[[UINavigationController alloc] initWithRootViewController:picker];
            host.windowLevel=UIWindowLevelAlert;[host makeKeyAndVisible];
            while(!picker.finished)[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            host.hidden=YES;[previous makeKeyAndVisible];
#else
            ShowCloudPicker();
#endif
        };
        if(NSThread.isMainThread)show();else dispatch_sync(dispatch_get_main_queue(),show);
    }
}
