// Optional iCloud Documents transport. Immutable, content-addressed snapshots
// preserve divergent saves. Device layout and presentation preferences stay local.
#import <CommonCrypto/CommonDigest.h>
static NSString *const CloudSaveKey=@"Wireproof.Cloud.Saves";
static NSString *const CloudSettingsKey=@"Wireproof.Cloud.Settings";
static NSString *cloudStatus=@"iCloud sync is off.";
static NSURL *cloudRoot;
static NSMetadataQuery *cloudQuery;
static id cloudIdentity;
static NSString *cloudAccount;
static BOOL cloudBusy=NO;
static NSString *CloudHash(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256(data.bytes,(CC_LONG)data.length,digest);
    NSMutableString *s=[NSMutableString new];for(unsigned char b:digest)[s appendFormat:@"%02x",b];return s;
}
static BOOL CloudSharedKey(NSString *key) {
    return [@[@"WPActiveRules",@"WPRules.Custom 1",@"WPRules.Custom 2",@"WPRules.Custom 3",@"Wireproof.CheatPreferences.v1",@"TiberianDawn.LanguagePreference",@"TiberianDawnLanguagePreference"] containsObject:key];
}
static NSDictionary *CloudSettings() {
    NSMutableDictionary *prefs=[NSMutableDictionary new];
    NSDictionary *all=BackupSettings()[@"preferences"];
    for(NSString *key in all)if(CloudSharedKey(key))prefs[key]=all[key];
    return @{@"preferences":prefs};
}
static NSURL *CloudOutbox() {
    NSURL *url=[BackupDirectory() URLByAppendingPathComponent:@".cloud-outbox" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:url withIntermediateDirectories:YES attributes:nil error:nil];return url;
}
static BOOL CloudQueue(NSDictionary *payload,NSString *name) {
    NSData *bytes=[NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingSortedKeys error:nil];
    return bytes && [bytes writeToURL:[CloudOutbox() URLByAppendingPathComponent:name] options:NSDataWritingAtomic error:nil];
}
void WP_CloudSaveCompleted(const char *path) {
    @autoreleasepool {
        if(![NSUserDefaults.standardUserDefaults boolForKey:CloudSaveKey])return;
        NSString *name=[@(path) lastPathComponent];if(!Is_Manual_Savegame_Name(name.UTF8String))return;
        NSURL *url=[BackupDirectory() URLByAppendingPathComponent:name];
        NSData *bytes=[NSData dataWithContentsOfURL:url];if(!bytes.length || bytes.length>128*1024*1024)return;
        NSString *hash=CloudHash(bytes);
        if(!CloudQueue(@{@"format":@"wireproof-cloud",@"version":@1,@"kind":@"save",@"hash":hash,@"data":[bytes base64EncodedStringWithOptions:0]},[hash stringByAppendingString:@".tdcloud"]))cloudStatus=@"Could not queue save. Your local save is intact.";
    }
}
static void CloudQueueSettings() {
    if(![NSUserDefaults.standardUserDefaults boolForKey:CloudSettingsKey])return;
    NSDictionary *settings=CloudSettings();NSData *bytes=[NSJSONSerialization dataWithJSONObject:settings options:NSJSONWritingSortedKeys error:nil];
    NSString *hash=CloudHash(bytes);NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    if([hash isEqual:[d stringForKey:@"Wireproof.Cloud.LastLocalSettings"]])return;
    NSString *name=[NSString stringWithFormat:@"settings-%@.tdcloud",NSUUID.UUID.UUIDString];
    if(CloudQueue(@{@"format":@"wireproof-cloud",@"version":@1,@"kind":@"settings",@"settings":settings,@"hash":hash,@"time":@(NSDate.date.timeIntervalSince1970)},name)) {
        [d setObject:hash forKey:@"Wireproof.Cloud.LastLocalSettings"];
        [NSFileManager.defaultManager removeItemAtURL:[BackupDirectory() URLByAppendingPathComponent:@".cloud-settings-pending.json"] error:nil];
    }
}
static void CloudTick() {
    if(cloudBusy)return;
    NSUserDefaults *d=NSUserDefaults.standardUserDefaults;
    BOOL saves=[d boolForKey:CloudSaveKey],settings=[d boolForKey:CloudSettingsKey];
    if(!saves && !settings){cloudStatus=@"iCloud sync is off. Local saves are retained.";return;}
    cloudBusy=YES;
    NSFileManager *fm=NSFileManager.defaultManager;
    id identity=fm.ubiquityIdentityToken;
    if(cloudIdentity && ![identity isEqual:cloudIdentity]) {
        [d setBool:NO forKey:CloudSaveKey];[d setBool:NO forKey:CloudSettingsKey];
        [cloudQuery stopQuery];cloudQuery=nil;cloudRoot=nil;cloudIdentity=nil;cloudAccount=nil;
        cloudStatus=@"Apple Account changed. Enable sync again for this account; local data is retained.";cloudBusy=NO;return;
    }
    if(!identity || ![identity isEqual:cloudIdentity]) {
        [cloudQuery stopQuery];cloudQuery=nil;cloudRoot=nil;cloudIdentity=identity;cloudAccount=nil;
    }
    if(!identity){cloudStatus=@"Sign in to iCloud and enable iCloud Drive. Local saves remain available.";cloudBusy=NO;return;}
    if(!cloudRoot) {
        // Container discovery can block; resolve away from the game/UI thread.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
            NSURL *root=[fm URLForUbiquityContainerIdentifier:@"iCloud.com.wireproof.tiberiandawn"];
            dispatch_async(dispatch_get_main_queue(),^{
                if(![identity isEqual:fm.ubiquityIdentityToken]){cloudBusy=NO;return;}
                cloudRoot=root?[root URLByAppendingPathComponent:@"Documents/Sync-v1" isDirectory:YES]:nil;
                if(cloudRoot) {
                    NSData *token=[NSKeyedArchiver archivedDataWithRootObject:identity requiringSecureCoding:NO error:nil];
                    cloudAccount=CloudHash(token?:[NSData data]);
                    [fm createDirectoryAtURL:cloudRoot withIntermediateDirectories:YES attributes:nil error:nil];
                    cloudQuery=[NSMetadataQuery new];cloudQuery.searchScopes=@[NSMetadataQueryUbiquitousDocumentsScope];
                    cloudQuery.predicate=[NSPredicate predicateWithFormat:@"%K ENDSWITH %@",NSMetadataItemFSNameKey,@".tdcloud"];
                    [cloudQuery startQuery];cloudStatus=@"iCloud available. Checking snapshots…";
                } else cloudStatus=@"iCloud is unavailable for this signed app. Local backups still work.";
                cloudBusy=NO;
            });
        });return;
    }
    if(!cloudQuery.isGathering && [d boolForKey:[@"Wireproof.Cloud.InitialSettings." stringByAppendingString:cloudAccount]])CloudQueueSettings();
    NSString *seenKey=[@"Wireproof.Cloud.Seen." stringByAppendingString:cloudAccount];
    NSMutableSet *seen=[NSMutableSet setWithArray:[d arrayForKey:seenKey]?:@[]];
    NSUInteger queued=0;BOOL failed=NO;
    // Coordinated atomic writes never replace an existing snapshot.
    for(NSURL *url in [fm contentsOfDirectoryAtURL:CloudOutbox() includingPropertiesForKeys:nil options:0 error:nil]) {
        BOOL isSettings=[url.lastPathComponent hasPrefix:@"settings-"];
        if((isSettings && !settings)||(!isSettings && !saves))continue;
        NSURL *dest=[cloudRoot URLByAppendingPathComponent:url.lastPathComponent];
        __block BOOL copied=NO;NSError *error=nil;
        [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateWritingItemAtURL:dest options:0 error:&error byAccessor:^(NSURL *target){
            if([fm fileExistsAtPath:target.path])copied=[[NSData dataWithContentsOfURL:target] isEqual:[NSData dataWithContentsOfURL:url]];
            else copied=[fm copyItemAtURL:url toURL:target error:nil];
        }];
        if(copied && !error){
            if(isSettings){NSDictionary *p=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:url] options:0 error:nil];NSString *k=[@"Wireproof.Cloud.SettingsTime." stringByAppendingString:cloudAccount];[d setDouble:MAX([d doubleForKey:k],[p[@"time"] doubleValue]) forKey:k];}
            [seen addObject:url.lastPathComponent];[fm removeItemAtURL:url error:nil];}else{queued++;failed=YES;}
    }
    // Discover placeholders and request downloads. Only complete local snapshots
    // are consumed; cloud propagation is eventual and is never reported as instant.
    [cloudQuery disableUpdates];
    NSArray *items=[cloudQuery.results copy];
    [cloudQuery enableUpdates];
    NSDictionary *latest=nil;NSString *latestName=nil;
    double newest=[d doubleForKey:[@"Wireproof.Cloud.SettingsTime." stringByAppendingString:cloudAccount]];
    NSUInteger imported=0,waiting=0;
    for(NSMetadataItem *item in items) {
        NSURL *url=[item valueForAttribute:NSMetadataItemURLKey];
        if(![url.path hasPrefix:[cloudRoot.path stringByAppendingString:@"/"]])continue;
        NSString *name=url.lastPathComponent;BOOL isSettings=[name hasPrefix:@"settings-"];
        if((isSettings && !settings)||(!isSettings && !saves)||[seen containsObject:name])continue;
        NSString *status=nil;[url getResourceValue:&status forKey:NSURLUbiquitousItemDownloadingStatusKey error:nil];
        if(![status isEqual:NSURLUbiquitousItemDownloadingStatusCurrent] && ![status isEqual:NSURLUbiquitousItemDownloadingStatusDownloaded]){[fm startDownloadingUbiquitousItemAtURL:url error:nil];waiting++;continue;}
        __block NSData *data=nil;NSError *error=nil;
        [[[NSFileCoordinator alloc] initWithFilePresenter:nil] coordinateReadingItemAtURL:url options:0 error:&error byAccessor:^(NSURL *source){
            NSNumber *size=nil;[source getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
            if(size.unsignedLongLongValue<=192ULL*1024*1024)data=[NSData dataWithContentsOfURL:source];
        }];
        id p=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        if(error || ![p isKindOfClass:NSDictionary.class] || ![p[@"format"] isEqual:@"wireproof-cloud"] || ![p[@"version"] isEqual:@1]){failed=YES;continue;}
        if(isSettings) {
            id s=p[@"settings"];BOOL valid=ValidateBackupSettings(s) && !s[@"conquerINI"];
            if(valid)for(NSString *key in s[@"preferences"])if(!CloudSharedKey(key))valid=NO;
            NSData *bytes=valid?[NSJSONSerialization dataWithJSONObject:s options:NSJSONWritingSortedKeys error:nil]:nil;
            if(!valid || ![CloudHash(bytes) isEqual:p[@"hash"]] || ![p[@"time"] isKindOfClass:NSNumber.class] || !std::isfinite([p[@"time"] doubleValue])){failed=YES;continue;}
            if([p[@"time"] doubleValue]>newest){newest=[p[@"time"] doubleValue];latest=s;latestName=name;}
        } else {
            NSData *bytes=[p[@"data"] isKindOfClass:NSString.class]?[[NSData alloc] initWithBase64EncodedString:p[@"data"] options:0]:nil;
            if(!bytes.length || ![CloudHash(bytes) isEqual:p[@"hash"]]){failed=YES;continue;}
            BOOL duplicate=NO;
            for(NSString *local in [fm contentsOfDirectoryAtPath:BackupDirectory().path error:nil])if(Is_Manual_Savegame_Name(local.UTF8String)) {
                NSData *existing=[NSData dataWithContentsOfURL:[BackupDirectory() URLByAppendingPathComponent:local]];
                if([existing isEqual:bytes]){duplicate=YES;break;}
            }
            if(!duplicate) {
                NSURL *temp=[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:NSUUID.UUID.UUIDString];
                NSData *backup=[NSJSONSerialization dataWithJSONObject:@{@"format":@"wireproof-tiberian-dawn",@"version":@1,@"saves":@[@{@"data":p[@"data"]}]} options:0 error:nil];
                [backup writeToURL:temp options:NSDataWritingAtomic error:nil];NSString *result=RestoreBackup(temp);[fm removeItemAtURL:temp error:nil];
                if(![result hasPrefix:@"Imported 1 saves"]){failed=YES;continue;}imported++;
            }
            [seen addObject:name];
        }
    }
    if(settings && !cloudQuery.isGathering && ![d boolForKey:[@"Wireproof.Cloud.InitialSettings." stringByAppendingString:cloudAccount]]) {
        if(latest || waiting)[d setObject:CloudHash([NSJSONSerialization dataWithJSONObject:CloudSettings() options:NSJSONWritingSortedKeys error:nil]) forKey:@"Wireproof.Cloud.LastLocalSettings"];
        if(!latest && !waiting)[d removeObjectForKey:@"Wireproof.Cloud.LastLocalSettings"];
        if(!waiting)[d setBool:YES forKey:[@"Wireproof.Cloud.InitialSettings." stringByAppendingString:cloudAccount]];
    }
    if(latest) {
        // Keep manual-import staging separate. A running game's settings never change.
        NSData *bytes=[NSJSONSerialization dataWithJSONObject:latest options:0 error:nil];
        if([bytes writeToURL:[BackupDirectory() URLByAppendingPathComponent:@".cloud-settings-pending.json"] options:NSDataWritingAtomic error:nil]){
            [d setObject:cloudAccount forKey:@"Wireproof.Cloud.PendingAccount"];[d setDouble:newest forKey:[@"Wireproof.Cloud.SettingsTime." stringByAppendingString:cloudAccount]];[seen addObject:latestName];
        }else failed=YES;
    }
    [d setObject:seen.allObjects forKey:seenKey];
    BOOL pending=[fm fileExistsAtPath:[BackupDirectory() URLByAppendingPathComponent:@".cloud-settings-pending.json"].path];
    cloudStatus=[NSString stringWithFormat:@"%@ %@%@",failed?@"Some items will retry; local saves are safe.":@"iCloud checked. Uploads may still be propagating.",pending?@"Settings received: restart to apply. ":@"",waiting?@"Downloading saves…":@""];
    (void)queued;(void)imported;cloudBusy=NO;
}
void WP_CloudStart() {
    @autoreleasepool {
        NSURL *pending=[BackupDirectory() URLByAppendingPathComponent:@".cloud-settings-pending.json"];
        id token=NSFileManager.defaultManager.ubiquityIdentityToken;
        NSString *account=token?CloudHash([NSKeyedArchiver archivedDataWithRootObject:token requiringSecureCoding:NO error:nil]):nil;
        if(account && [account isEqual:[NSUserDefaults.standardUserDefaults stringForKey:@"Wireproof.Cloud.PendingAccount"]] && [NSUserDefaults.standardUserDefaults boolForKey:CloudSettingsKey]) {
            NSData *data=[NSData dataWithContentsOfURL:pending];id s=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
            if(ValidateBackupSettings(s)) {
                for(NSString *key in @[@"WPActiveRules",@"WPRules.Custom 1",@"WPRules.Custom 2",@"WPRules.Custom 3",@"Wireproof.CheatPreferences.v1",@"TiberianDawn.LanguagePreference",@"TiberianDawnLanguagePreference"]) {
                    id value=s[@"preferences"][key];
                    if(value)[NSUserDefaults.standardUserDefaults setObject:value forKey:key];
                    else [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
                }
                // Do not echo received preferences as a new local edit.
                [NSUserDefaults.standardUserDefaults setObject:CloudHash([NSJSONSerialization dataWithJSONObject:CloudSettings() options:NSJSONWritingSortedKeys error:nil]) forKey:@"Wireproof.Cloud.LastLocalSettings"];
                [NSFileManager.defaultManager removeItemAtURL:pending error:nil];
            }
        }
        for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:BackupDirectory().path error:nil])WP_CloudSaveCompleted(name.UTF8String);
        dispatch_async(dispatch_get_main_queue(),^{
            [NSTimer scheduledTimerWithTimeInterval:15 repeats:YES block:^(NSTimer *timer){CloudTick();}];CloudTick();
        });
    }
}
static void CloudToggle(NSString *key,BOOL enabled) {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:key];
    if(enabled && [key isEqual:CloudSaveKey])for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:BackupDirectory().path error:nil])WP_CloudSaveCompleted(name.UTF8String);
    CloudTick();
}
#if TARGET_OS_IPHONE
@interface WPCloudPicker : UITableViewController
@property(nonatomic) BOOL finished;
@end
@implementation WPCloudPicker
- (void)viewDidLoad {[super viewDidLoad];self.title=@"iCloud Sync";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(done)];}
- (void)done {self.finished=YES;}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s {return 3;}
- (NSString*)tableView:(UITableView*)t titleForFooterInSection:(NSInteger)s {return [@"Same Apple Account and iCloud Drive required. Saves stay available offline; different versions are kept in separate slots. Settings and cheats apply after restarting. Zoom, controls, icon and display layout stay on this device. Cloud snapshots are retained; deleting a local save does not delete other devices' copies.\n\n" stringByAppendingString:cloudStatus];}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p {
    UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];c.textLabel.numberOfLines=0;c.textLabel.text=@[@"Sync saves",@"Sync settings / cheats / Workshop",@"Check iCloud now"][p.row];
    if(p.row<2){UISwitch *s=[UISwitch new];s.tag=p.row;s.on=[NSUserDefaults.standardUserDefaults boolForKey:p.row?CloudSettingsKey:CloudSaveKey];[s addTarget:self action:@selector(changed:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;}return c;
}
- (void)changed:(UISwitch*)s {CloudToggle(s.tag?CloudSettingsKey:CloudSaveKey,s.on);[self.tableView reloadData];}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p {[t deselectRowAtIndexPath:p animated:YES];if(p.row==2){CloudTick();[t reloadData];}}
@end
#else
static void ShowCloudPicker() {
    NSAlert *a=[NSAlert new];a.messageText=@"iCloud Sync";a.informativeText=[@"Same Apple Account and iCloud Drive required. Different save versions use separate slots. Settings/cheats/Workshop apply after restart. Display, zoom, controls and icon stay local. Requires an iCloud-provisioned signed app.\n\n" stringByAppendingString:cloudStatus];
    NSView *v=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,65)];NSButton *s=[NSButton checkboxWithTitle:@"Sync saves" target:nil action:nil];s.frame=NSMakeRect(0,35,360,25);s.state=[NSUserDefaults.standardUserDefaults boolForKey:CloudSaveKey];[v addSubview:s];NSButton *p=[NSButton checkboxWithTitle:@"Sync settings / cheats / Workshop" target:nil action:nil];p.frame=NSMakeRect(0,0,360,25);p.state=[NSUserDefaults.standardUserDefaults boolForKey:CloudSettingsKey];[v addSubview:p];a.accessoryView=v;[a addButtonWithTitle:@"Apply / Check"];[a addButtonWithTitle:@"Cancel"];
    if([a runModal]==NSAlertFirstButtonReturn){CloudToggle(CloudSaveKey,s.state==NSControlStateValueOn);CloudToggle(CloudSettingsKey,p.state==NSControlStateValueOn);}
}
#endif
