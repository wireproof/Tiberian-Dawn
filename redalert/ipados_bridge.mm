#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>

#include "platform/apple/ipados_platform.h"
#include "common/ipados_audio_engine.h"

// The Red Alert engine is compiled independently during bring-up. Its
// immutable assets and saves use the existing vanillara data/user suffixes.
// The combined app will choose the engine before entering either game loop.
extern "C" bool TiberianDawn_PrepareGameData(void)
{
    @autoreleasepool {
        NSURL *bundleData = [[NSBundle mainBundle] resourceURL];
        bundleData = [bundleData URLByAppendingPathComponent:@"RAData" isDirectory:YES];
        NSURL *support = [[[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                                 inDomain:NSUserDomainMask
                                                        appropriateForURL:nil
                                                                   create:YES
                                                                    error:nil]
                          URLByAppendingPathComponent:@"TiberianDawn/vanillara" isDirectory:YES];
        NSFileManager *files = [NSFileManager defaultManager];
        if (!bundleData || !support) return false;
        if (![files createDirectoryAtURL:support withIntermediateDirectories:YES attributes:nil error:nil]) return false;
        for (NSString *name in @[@"REDALERT.MIX", @"MAIN.MIX"]) {
            NSURL *source = [bundleData URLByAppendingPathComponent:name];
            NSURL *target = [support URLByAppendingPathComponent:name];
            if (![files fileExistsAtPath:source.path]) return false;
            if (![files fileExistsAtPath:target.path] && ![files copyItemAtURL:source toURL:target error:nil]) return false;
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
