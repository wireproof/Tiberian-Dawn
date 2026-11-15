#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <TargetConditionals.h>
#include <cmath>
#include <cassert>
#include "common/fixed.h"
#include "redalert/defines.h"
#include "redalert/savegame_validate.h"
#define WP_BACKUP_RED_ALERT 1
#include "platform/apple/wireproof_backup.inc"
static NSUserDefaults *TestCloudDefaults;
#define WP_CLOUD_DEFAULTS TestCloudDefaults
#include "platform/apple/wireproof_cloud.inc"
PathsClass Paths;
static std::string TestDirectory;
const char* PathsClass::User_Path(){return TestDirectory.c_str();}
extern "C" bool RedAlert_ValidateSaveGame(const char* path,char* title,size_t capacity,unsigned* scenario,int* faction) {
    return RA_ValidateSaveFile<HousesType>(path,title,capacity,scenario,faction,DESCRIP_MAX,1234,true,20);
}
static NSData* Fixture() {
    NSMutableData *data=[NSMutableData data];char description[DESCRIP_MAX]={0};strcpy(description,"Test mission\r\n");
    unsigned scenario=7,version=1234;HousesType house=HOUSE_USSR;
    const char payload[]="Encrypted game payload fixture";unsigned char digest[20];
    SHAEngine sha;sha.Hash(payload,sizeof(payload));sha.Result(digest);
    [data appendBytes:description length:sizeof(description)];[data appendBytes:&scenario length:sizeof(scenario)];
    [data appendBytes:&house length:sizeof(house)];[data appendBytes:&version length:sizeof(version)];
    [data appendBytes:digest length:sizeof(digest)];[data appendBytes:payload length:sizeof(payload)];return data;
}
int main(){@autoreleasepool {
    char pattern[]="/tmp/ra-backup-test-XXXXXX";char *temporary=mkdtemp(pattern);assert(temporary);TestDirectory=temporary;
    NSFileManager *fm=NSFileManager.defaultManager;NSURL *dir=BackupDirectory();
    NSData *valid=Fixture();NSURL *original=[dir URLByAppendingPathComponent:@"SAVEGAME.000"];
    assert([valid writeToURL:original atomically:YES]);
    char title[128];unsigned scenario;int faction;
    assert(RedAlert_ValidateSaveGame(original.fileSystemRepresentation,title,sizeof(title),&scenario,&faction));
    assert(!strcmp(title,"Test mission") && scenario==7 && faction==2);
    char shortTitle[2];assert(RedAlert_ValidateSaveGame(original.fileSystemRepresentation,shortTitle,sizeof(shortTitle),nullptr,nullptr));assert(shortTitle[1]==0);
    NSURL *probe=[dir URLByAppendingPathComponent:@"probe.sav"];
    for(NSUInteger length=0;length<DESCRIP_MAX+sizeof(unsigned)*2+sizeof(HousesType)+20;length++) {
        [[valid subdataWithRange:NSMakeRange(0,length)] writeToURL:probe atomically:YES];
        assert(!RedAlert_ValidateSaveGame(probe.fileSystemRepresentation,title,sizeof(title),nullptr,nullptr));
    }
    for(NSUInteger offset : {NSUInteger(DESCRIP_MAX),NSUInteger(DESCRIP_MAX+4),NSUInteger(DESCRIP_MAX+5),NSUInteger(DESCRIP_MAX+9),valid.length-1}) {
        NSMutableData *bad=[valid mutableCopy];((unsigned char*)bad.mutableBytes)[offset]^=0xff;
        [bad writeToURL:probe atomically:YES];
        // Scenario is intentionally not covered by the legacy payload digest.
        if(offset!=DESCRIP_MAX)assert(!RedAlert_ValidateSaveGame(probe.fileSystemRepresentation,title,sizeof(title),nullptr,nullptr));
    }
    NSMutableData *unterminated=[valid mutableCopy];memset(unterminated.mutableBytes,'A',DESCRIP_MAX);
    [unterminated writeToURL:probe atomically:YES];assert(!RedAlert_ValidateSaveGame(probe.fileSystemRepresentation,title,sizeof(title),nullptr,nullptr));
    NSMutableData *aftermath=[valid mutableCopy];unsigned next=1235;memcpy((char*)aftermath.mutableBytes+DESCRIP_MAX+5,&next,4);
    [aftermath writeToURL:probe atomically:YES];assert(RedAlert_ValidateSaveGame(probe.fileSystemRepresentation,title,sizeof(title),nullptr,nullptr));
    assert(!RA_ValidateSaveFile<HousesType>(probe.fileSystemRepresentation,title,sizeof(title),nullptr,nullptr,DESCRIP_MAX,1234,false,20));
    NSString *suite=[@"test.wireproof.ra.cloud." stringByAppendingString:NSUUID.UUID.UUIDString];
    TestCloudDefaults=[[NSUserDefaults alloc] initWithSuiteName:suite];
    assert([CloudSaveKey isEqual:@"Wireproof.RedAlert.Cloud.Saves"]);
    assert([CloudSettingsKey isEqual:@"Wireproof.RedAlert.Cloud.Settings"]);
    assert([WP_CLOUD_FOLDER isEqual:@"Documents/RedAlert/Sync-v1"]);
    assert(CloudSharedKey(@"Wireproof.RedAlert.Cheats.v1"));
    assert(CloudSharedKey(@"Wireproof.RedAlert.Workshop.Rules.v1.Custom 1"));
    assert(!CloudSharedKey(@"Wireproof.CheatPreferences.v1"));
    assert(!CloudSharedKey(@"Wireproof.RedAlert.Joystick.v1"));
    assert(!CloudSharedKey(@"Wireproof.RedAlert.LaptopMode"));
    RA_CloudSaveCompleted("SAVEGAME.000");assert([fm contentsOfDirectoryAtPath:CloudOutbox().path error:nil].count==0);
    [TestCloudDefaults setBool:YES forKey:CloudSaveKey];
    RA_CloudSaveCompleted("SAVEGAME.000");RA_CloudSaveCompleted("SAVEGAME.000");
    NSArray *queued=[fm contentsOfDirectoryAtPath:CloudOutbox().path error:nil];assert(queued.count==1);
    assert([[queued.firstObject pathExtension] isEqual:@"racloud"]);
    NSDictionary *cloudPayload=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:[CloudOutbox() URLByAppendingPathComponent:queued.firstObject]] options:0 error:nil];
    assert([cloudPayload[@"format"] isEqual:@"wireproof-red-alert-cloud"]);
    assert([cloudPayload[@"hash"] isEqual:CloudHash(valid)]);
    RA_CloudSaveCompleted("AUTOSAVE.SAV");assert([fm contentsOfDirectoryAtPath:CloudOutbox().path error:nil].count==1);
    [TestCloudDefaults removePersistentDomainForName:suite];TestCloudDefaults=nil;
    NSString *error=nil;NSURL *backup=CreateBackup(0,&error);assert(backup && [backup.pathExtension isEqual:@"rabackup"]);
    assert([RestoreBackup(backup) containsString:@"Imported 1 saves"]);
    assert([[NSData dataWithContentsOfURL:original] isEqual:valid]);
    assert([[NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"SAVEGAME.001"]] isEqual:valid]);
    NSURL *input=[dir URLByAppendingPathComponent:@"input.rabackup"];
    void (^write)(NSDictionary*)=^(NSDictionary *payload){assert([[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil] writeToURL:input atomically:YES]);};
    write(@{@"format":@"wireproof-tiberian-dawn",@"version":@1,@"saves":@[]});assert([RestoreBackup(input) containsString:@"Not a supported Red Alert"]);
    write(@{@"format":@"wireproof-red-alert",@"version":@1,@"saves":@[@{@"data":[valid base64EncodedStringWithOptions:0]},@{@"data":@"YmFk"}]});
    assert([RestoreBackup(input) containsString:@"damaged"]);assert(![fm fileExistsAtPath:[dir URLByAppendingPathComponent:@"SAVEGAME.002"].path]);
    assert(ValidateBackupSettings(@{@"preferences":@{@"Wireproof.RedAlert.Cheats.v1":@{@"infantry":@12,@"invincible":@YES},@"Wireproof.RedAlert.Workshop.Active.v1":@"Custom 2",@"Wireproof.RedAlert.Workshop.Rules.v1.Custom 2":@{@"RULE":@45}}}));
    for(NSDictionary *prefs in @[@{@"WPActiveRules":@"Stock"},@{@"Wireproof.RedAlert.Cheats.v1":@{@"infantry":@13}},@{@"Wireproof.RedAlert.Cheats.v1":@{@"free":@3}},@{@"Wireproof.RedAlert.Cheats.v1":@{@"unknown":@1}},@{@"Wireproof.RedAlert.Workshop.Active.v1":@"Unknown"}])assert(!ValidateBackupSettings(@{@"preferences":prefs}));
    for(NSString *key in @[@"Wireproof.RedAlert.LaptopMode",@"Wireproof.RedAlert.PortraitDeckAlways"]) {
        assert(BackupKey(key));assert(BackupValue(key,@YES));assert(BackupValue(key,@NO));
        assert(!BackupValue(key,@2));assert(!BackupValue(key,@"yes"));
        assert(ValidateBackupSettings(@{@"preferences":@{key:@YES}}));
    }
    assert(ValidateBackupSettings(@{@"preferences":@{@"Wireproof.RedAlert.Cheats.v1":@{@"unlock":@YES,@"damagedHealth":@NO},@"Wireproof.RedAlert.Joystick.v1":@{@"size":@8,@"speed":@12,@"coverPortraitX":@0.5,@"innerLandscapeY":@1}}}));
    for(NSDictionary *joystick in @[@{@"size":@1},@{@"speed":@13},@{@"size":@2.5},@{@"coverPortraitX":@1.1},@{@"innerLandscapeY":@(-0.1)},@{@"unknown":@1}])assert(!BackupValue(@"Wireproof.RedAlert.Joystick.v1",joystick));
    NSData *ini=[@"[WireproofRARally]\nExample=100\n" dataUsingEncoding:NSUTF8StringEncoding];
    write(@{@"format":@"wireproof-red-alert",@"version":@1,@"settings":@{@"preferences":@{},@"redalertINI":[ini base64EncodedStringWithOptions:0]}});
    assert([RestoreBackup(input) containsString:@"Fully close"]);
    RA_ApplyPendingBackupSettings(); // Empty preferences: no defaults are modified.
    assert([[NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"REDALERT.INI"]] isEqual:ini]);
    assert(![fm fileExistsAtPath:[dir URLByAppendingPathComponent:@"CONQUER.INI"].path]);
    assert(![fm fileExistsAtPath:[dir URLByAppendingPathComponent:@".wireproof-settings-pending.json"].path]);
    [fm removeItemAtURL:dir error:nil];[fm removeItemAtURL:backup.URLByDeletingLastPathComponent error:nil];
    puts("Red Alert backup: digest/header validation, free-slot round-trip, rollback, game isolation, preference bounds and INI restart restore passed.");
}}
