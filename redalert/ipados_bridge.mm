#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>

#include "platform/apple/ipados_platform.h"
#include "common/ipados_audio_engine.h"

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
        if (!bundleData) return false;
        for (NSString *name in @[@"REDALERT.MIX", @"allied/MAIN.MIX", @"soviet/MAIN.MIX"]) {
            NSURL *source = [bundleData URLByAppendingPathComponent:name];
            NSDictionary *attributes = [files attributesOfItemAtPath:source.path error:nil];
            if (![attributes[NSFileSize] respondsToSelector:@selector(unsignedLongLongValue)]
                || [attributes[NSFileSize] unsignedLongLongValue] == 0) return false;
        }
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
