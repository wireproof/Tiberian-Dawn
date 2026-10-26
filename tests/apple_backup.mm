#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <TargetConditionals.h>
#include <cmath>
#include <cassert>
#include "platform/apple/wireproof_backup.inc"
PathsClass Paths;
static std::string TestDirectory;
const char* PathsClass::User_Path(){return TestDirectory.c_str();}
extern "C" bool TiberianDawn_ValidateSaveGame(const char* path,char*,size_t,unsigned*,int*) {
    NSData *d=[NSData dataWithContentsOfFile:@(path)];return d.length==4 && memcmp(d.bytes,"SAVE",4)==0;
}
int main(){@autoreleasepool {
    char pattern[]="/tmp/td-backup-test-XXXXXX";char *temporary=mkdtemp(pattern);assert(temporary);TestDirectory=temporary;
    NSFileManager *fm=NSFileManager.defaultManager;NSURL *dir=BackupDirectory();
    [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *valid=[@"SAVE" dataUsingEncoding:NSUTF8StringEncoding];
    NSURL *original=[dir URLByAppendingPathComponent:@"SAVEGAME.000"];
    assert([valid writeToURL:original atomically:YES]);
    NSString *error=nil;NSURL *backup=CreateBackup(0,&error);assert(backup);
    NSString *result=RestoreBackup(backup);assert([result containsString:@"Imported 1 saves"]);
    assert([[NSData dataWithContentsOfURL:original] isEqual:valid]);
    assert([fm fileExistsAtPath:[dir URLByAppendingPathComponent:@"SAVEGAME.001"].path]);
    NSDictionary *bad=@{@"format":@"wireproof-tiberian-dawn",@"version":@1,@"saves":@[@{@"data":[valid base64EncodedStringWithOptions:0]},@{@"data":@"YmFk"}]};
    NSURL *input=[dir URLByAppendingPathComponent:@"bad.tdbackup"];
    [[NSJSONSerialization dataWithJSONObject:bad options:0 error:nil] writeToURL:input atomically:YES];
    assert([RestoreBackup(input) containsString:@"damaged"]);
    assert(![fm fileExistsAtPath:[dir URLByAppendingPathComponent:@"SAVEGAME.002"].path]);
    assert(!ValidateBackupSettings(@{@"preferences":@{@"Wireproof.OrdersPosition":@[@"bad",@1]}}));
    assert(!ValidateBackupSettings(@{@"preferences":@{@"unrelated.secret":@1}}));
    assert(ValidateBackupSettings(@{@"preferences":@{@"Wireproof.Zoom.Standard":@6,@"WPActiveRules":@"Stock"}}));
    NSDictionary *settings=@{@"format":@"wireproof-tiberian-dawn",@"version":@1,@"settings":@{@"preferences":@{@"Wireproof.Zoom.Standard":@6}}};
    [[NSJSONSerialization dataWithJSONObject:settings options:0 error:nil] writeToURL:input atomically:YES];
    assert([RestoreBackup(input) containsString:@"Fully close"]);
    assert([fm fileExistsAtPath:[dir URLByAppendingPathComponent:@".wireproof-settings-pending.json"].path]);
    [fm removeItemAtURL:dir error:nil];[fm removeItemAtURL:backup.URLByDeletingLastPathComponent error:nil];
    puts("Backup round-trip, preservation, invalid-save rollback, preference validation and restart staging passed.");
}}
