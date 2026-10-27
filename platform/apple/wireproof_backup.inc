// Shared, versioned backup format. Never include original game archives or signing data.
#include "common/paths.h"
#include "common/savegame_transfer.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
extern "C" bool TiberianDawn_ValidateSaveGame(const char*,char*,size_t,unsigned*,int*);
static NSURL* BackupDirectory() { return [NSURL fileURLWithPath:@(Paths.User_Path()) isDirectory:YES]; }
static BOOL BackupKey(NSString *key) {
    if([@[@"WPActiveRules",@"WPRules.Custom 1",@"WPRules.Custom 2",@"WPRules.Custom 3",@"Wireproof.CheatPreferences.v1",@"Wireproof.JoystickSize",@"Wireproof.JoystickSpeed",@"Wireproof.ZoomQuarters",@"TiberianDawn.LanguagePreference",@"TiberianDawnLanguagePreference"] containsObject:key])return YES;
    for(NSString *prefix in @[@"Wireproof.Zoom.",@"Wireproof.Joystick.",@"Wireproof.UIScale.",@"Wireproof.JoystickPosition",@"Wireproof.OrdersPosition"])
        if([key hasPrefix:prefix] && key.length<120)return YES;
    return NO;
}
static BOOL BackupValue(NSString *key,id value) {
    if([key isEqual:@"WPActiveRules"])return [@[@"Stock",@"Custom 1",@"Custom 2",@"Custom 3"] containsObject:value];
    if([key hasPrefix:@"WPRules."] || [key isEqual:@"Wireproof.CheatPreferences.v1"]) {
        if(![value isKindOfClass:NSDictionary.class] || [value count]>4096)return NO;
        for(id k in value)if(![k isKindOfClass:NSString.class] || ![value[k] isKindOfClass:NSNumber.class] || !std::isfinite([value[k] doubleValue]))return NO;
        return YES;
    }
    if([key containsString:@"Position"]) {
        if(![value isKindOfClass:NSArray.class] || [value count]!=2)return NO;
        for(id n in value)if(![n isKindOfClass:NSNumber.class] || !std::isfinite([n doubleValue]) || [n doubleValue]<0 || [n doubleValue]>1)return NO;
        return YES;
    }
    if(![value isKindOfClass:NSNumber.class])return NO;
    double n=[value doubleValue];return std::isfinite(n) && n==std::floor(n) && n>=0 && n<=1000;
}
static NSDictionary* BackupSettings() {
    NSMutableDictionary *prefs=[NSMutableDictionary new];
    NSDictionary *all=[NSUserDefaults.standardUserDefaults persistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
    for(NSString *key in all)if(BackupKey(key) && BackupValue(key,all[key]))prefs[key]=all[key];
    NSMutableDictionary *result=[@{@"preferences":prefs} mutableCopy];
    NSData *ini=[NSData dataWithContentsOfURL:[BackupDirectory() URLByAppendingPathComponent:@"CONQUER.INI"]];
    if(ini.length && ini.length<=1024*1024)result[@"conquerINI"]=[ini base64EncodedStringWithOptions:0];
    return result;
}
static BOOL ValidateBackupSettings(id settings) {
    if(![settings isKindOfClass:NSDictionary.class] || ![settings[@"preferences"] isKindOfClass:NSDictionary.class])return NO;
    NSDictionary *prefs=settings[@"preferences"];if(prefs.count>256)return NO;
    for(NSString *key in prefs)if(!BackupKey(key) || !BackupValue(key,prefs[key]))return NO;
    if(settings[@"conquerINI"]) {
        if(![settings[@"conquerINI"] isKindOfClass:NSString.class])return NO;
        NSData *ini=[[NSData alloc] initWithBase64EncodedString:settings[@"conquerINI"] options:0];
        if(!ini || ini.length>1024*1024)return NO;
    }
    return YES;
}
// Apply before reading CONQUER.INI and before UI timers start, so a running
// session cannot overwrite restored preferences on shutdown.
void WP_ApplyPendingBackupSettings(void) {
    @autoreleasepool {
        NSURL *pending=[BackupDirectory() URLByAppendingPathComponent:@".wireproof-settings-pending.json"];
        NSData *data=[NSData dataWithContentsOfURL:pending];if(!data)return;
        NSDictionary *settings=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if(!ValidateBackupSettings(settings))return;
        NSData *ini=settings[@"conquerINI"]?[[NSData alloc] initWithBase64EncodedString:settings[@"conquerINI"] options:0]:nil;
        if(ini && ![ini writeToURL:[BackupDirectory() URLByAppendingPathComponent:@"CONQUER.INI"] options:NSDataWritingAtomic error:nil])return;
        for(NSString *key in settings[@"preferences"])[NSUserDefaults.standardUserDefaults setObject:settings[@"preferences"][key] forKey:key];
        [NSUserDefaults.standardUserDefaults synchronize];
        [NSFileManager.defaultManager removeItemAtURL:pending error:nil];
    }
}
static NSURL* CreateBackup(NSInteger mode,NSString **message) {
    NSMutableDictionary *payload=[@{@"format":@"wireproof-tiberian-dawn",@"version":@1,@"created":NSDate.date.description} mutableCopy];
    if(mode!=0)payload[@"settings"]=BackupSettings();
    if(mode!=1){
        NSMutableArray *saves=[NSMutableArray new];NSUInteger total=0;
        for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:BackupDirectory().path error:nil]) {
            if(!Is_Manual_Savegame_Name(name.UTF8String))continue;
            NSURL *url=[BackupDirectory() URLByAppendingPathComponent:name];
            char title[128];unsigned scenario;int faction;
            if(!TiberianDawn_ValidateSaveGame(url.fileSystemRepresentation,title,sizeof(title),&scenario,&faction))continue;
            NSData *data=[NSData dataWithContentsOfURL:url];if(!data){*message=@"A save could not be read. Nothing was exported.";return nil;}
            total+=data.length;if(total>128*1024*1024){*message=@"Saves exceed the 128 MB backup limit. Export individual saves using Manage saves.";return nil;}
            [saves addObject:@{@"name":name,@"data":[data base64EncodedStringWithOptions:0]}];
        }
        payload[@"saves"]=saves;
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:nil];
    NSURL *folder=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *kind=@[@"Saves",@"Settings",@"Saves-and-Settings"][mode];
    NSURL *url=[folder URLByAppendingPathComponent:[NSString stringWithFormat:@"TiberianDawn-%@.tdbackup",kind]];
    NSError *error=nil;if(!data || ![data writeToURL:url options:NSDataWritingAtomic error:&error]){*message=error.localizedDescription?:@"Backup could not be written.";return nil;}return url;
}
static NSString* RestoreBackup(NSURL *source) {
    BOOL access=[source startAccessingSecurityScopedResource];
    NSNumber *size=nil;[source getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    NSData *data=size && size.unsignedLongLongValue<=192ULL*1024*1024?[NSData dataWithContentsOfURL:source]:nil;
    if(access)[source stopAccessingSecurityScopedResource];
    id payload=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    if(![payload isKindOfClass:NSDictionary.class] || ![payload[@"format"] isEqual:@"wireproof-tiberian-dawn"] || ![payload[@"version"] isEqual:@1])return @"Not a supported Tiberian Dawn backup. Nothing was imported.";
    id settings=payload[@"settings"],saves=payload[@"saves"];
    if((settings && !ValidateBackupSettings(settings)) || (saves && (![saves isKindOfClass:NSArray.class] || [saves count]>1000)) || (!settings && !saves))return @"Invalid backup contents. Nothing was imported.";
    NSFileManager *fm=NSFileManager.defaultManager;
    NSURL *directory=BackupDirectory();[fm createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL *stage=[directory URLByAppendingPathComponent:[@".restore-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    if(![fm createDirectoryAtURL:stage withIntermediateDirectories:NO attributes:nil error:nil])return @"Could not create restore staging folder.";
    NSMutableArray *staged=[NSMutableArray new],*destinations=[NSMutableArray new],*committed=[NSMutableArray new];
    std::vector<std::string> names;for(NSString *name in [fm contentsOfDirectoryAtPath:directory.path error:nil])names.push_back(name.UTF8String);
    NSString *failure=nil;NSUInteger total=0;
    for(id entry in saves) {
        if(![entry isKindOfClass:NSDictionary.class] || ![entry[@"data"] isKindOfClass:NSString.class]){failure=@"Malformed save entry.";break;}
        NSData *bytes=[[NSData alloc] initWithBase64EncodedString:entry[@"data"] options:0];total+=bytes.length;
        if(!bytes.length || total>128*1024*1024){failure=@"Invalid or oversized save data.";break;}
        int slot=First_Free_Manual_Savegame_Slot(names);if(slot<0){failure=@"There are not enough free save slots.";break;}
        std::string name=Manual_Savegame_Name(slot);names.push_back(name);
        NSURL *temp=[stage URLByAppendingPathComponent:@(name.c_str())];
        char title[128];unsigned scenario;int faction;
        if(![bytes writeToURL:temp options:NSDataWritingAtomic error:nil] || !TiberianDawn_ValidateSaveGame(temp.fileSystemRepresentation,title,sizeof(title),&scenario,&faction)){failure=@"A save is damaged or incompatible.";break;}
        [staged addObject:temp];[destinations addObject:[directory URLByAppendingPathComponent:@(name.c_str())]];
    }
    if(!failure)for(NSUInteger i=0;i<staged.count;i++) {
        if(![fm moveItemAtURL:staged[i] toURL:destinations[i] error:nil]){failure=@"Could not install the saves.";break;}[committed addObject:destinations[i]];
    }
    if(!failure && settings) {
        NSData *pending=[NSJSONSerialization dataWithJSONObject:settings options:0 error:nil];
        if(![pending writeToURL:[directory URLByAppendingPathComponent:@".wireproof-settings-pending.json"] options:NSDataWritingAtomic error:nil])failure=@"Could not schedule settings restoration.";
    }
    if(failure)for(NSURL *url in committed)[fm removeItemAtURL:url error:nil];
    [fm removeItemAtURL:stage error:nil];
    if(failure)return [failure stringByAppendingString:@" Existing saves were preserved."];
    return [NSString stringWithFormat:@"Imported %lu saves into free slots. %@",(unsigned long)committed.count,settings?@"Fully close and reopen the app to apply settings, cheats and Workshop presets.":@"Existing saves were preserved."];
}
#if TARGET_OS_IPHONE
@interface WPBackupPicker : UITableViewController <UIDocumentPickerDelegate>
@property(nonatomic) BOOL finished;
@property(nonatomic) BOOL importing;
@property(nonatomic,strong) NSURL *exportURL;
@end
@implementation WPBackupPicker
- (void)viewDidLoad { [super viewDidLoad];self.title=@"Import / Export";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(done)]; }
- (void)done { self.finished=YES; }
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s {return 4;}
- (NSString*)tableView:(UITableView*)t titleForFooterInSection:(NSInteger)s {return @"Back up saved missions, settings/cheats/Workshop presets, or both. Imports keep existing saves. Settings apply after fully closing and reopening the app. Original game data and app icon choices are excluded.";}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p {
    UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];c.textLabel.text=@[@"Export saves only",@"Export settings / cheats / config",@"Export saves + settings",@"Import backup…"][p.row];c.textLabel.numberOfLines=0;return c;
}
- (void)message:(NSString*)text {UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Import / Export" message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p {
    [t deselectRowAtIndexPath:p animated:YES];self.importing=p.row==3;UIDocumentPickerViewController *picker;
    if(self.importing) {picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];picker.allowsMultipleSelection=NO;}
    else {NSString *failure=nil;self.exportURL=CreateBackup(p.row,&failure);if(!self.exportURL){[self message:failure];return;}picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[self.exportURL] asCopy:YES];}
    picker.delegate=self;[self presentViewController:picker animated:YES completion:nil];
}
- (void)cleanup {if(self.exportURL)[NSFileManager.defaultManager removeItemAtURL:self.exportURL.URLByDeletingLastPathComponent error:nil];self.exportURL=nil;}
- (void)documentPicker:(UIDocumentPickerViewController*)picker didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {
    NSString *result=self.importing && urls.count?RestoreBackup(urls.firstObject):@"Backup exported.";[self cleanup];
    dispatch_async(dispatch_get_main_queue(),^{[self message:result];});
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)picker {[self cleanup];}
@end
#else
static void ShowBackupPicker() {
    NSAlert *a=[NSAlert new];a.messageText=@"Import / Export";a.informativeText=@"Back up saves, settings/cheats/Workshop presets, or both. Existing saves are preserved. Imported settings apply after restarting. Original game data and app icons are excluded.";
    [a addButtonWithTitle:@"Export"];[a addButtonWithTitle:@"Import…"];[a addButtonWithTitle:@"Cancel"];
    NSPopUpButton *mode=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,350,30) pullsDown:NO];[mode addItemsWithTitles:@[@"Saves only",@"Settings / cheats / config",@"Saves + settings"]];a.accessoryView=mode;
    NSInteger choice=[a runModal];NSString *result=nil;
    if(choice==NSAlertFirstButtonReturn) {
        NSString *failure=nil;NSURL *url=CreateBackup(mode.indexOfSelectedItem,&failure);
        if(!url)result=failure;else {NSSavePanel *panel=[NSSavePanel savePanel];panel.nameFieldStringValue=url.lastPathComponent;
            if([panel runModal]==NSModalResponseOK){NSError *error=nil;NSData *data=[NSData dataWithContentsOfURL:url];result=[data writeToURL:panel.URL options:NSDataWritingAtomic error:&error]?@"Backup exported.":error.localizedDescription;}
            [NSFileManager.defaultManager removeItemAtURL:url.URLByDeletingLastPathComponent error:nil];}
    }else if(choice==NSAlertSecondButtonReturn){NSOpenPanel *panel=[NSOpenPanel openPanel];panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;if([panel runModal]==NSModalResponseOK)result=RestoreBackup(panel.URL);}
    if(result){NSAlert *notice=[NSAlert new];notice.messageText=@"Import / Export";notice.informativeText=result;[notice runModal];}
}
#endif
