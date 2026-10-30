#import <Foundation/Foundation.h>
#include <cmath>
#include "common/wireproof_cheats.h"
#include "common/wireproof_orders.h"
#import <TargetConditionals.h>
#include "tiberiandawn/wireproof_rules.h"
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#include "ipados_platform.h"
void WP_ShowMultiplayerRestriction(void) {
    void (^show)(void)=^{
        UIWindowScene* scene=nil;
        for(UIScene* candidate in UIApplication.sharedApplication.connectedScenes)
            if([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive) {scene=(UIWindowScene*)candidate;break;}
        if(!scene)return;
        UIWindow* previous=scene.keyWindow;
        UIWindow* host=[[UIWindow alloc] initWithWindowScene:scene];
        UIViewController* root=[UIViewController new];host.rootViewController=root;host.windowLevel=UIWindowLevelAlert;[host makeKeyAndVisible];
        __block BOOL done=NO;
        UIAlertController* alert=[UIAlertController alertControllerWithTitle:@"Multiplayer unavailable with custom rules" message:@"Select the Stock preset and restart the app before starting multiplayer." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){done=YES;}]];
        [root presentViewController:alert animated:NO completion:nil];
        while(!done)[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        host.hidden=YES;[previous makeKeyAndVisible];
    };
    if(NSThread.isMainThread)show();else dispatch_sync(dispatch_get_main_queue(),show);
}
#else
#import <AppKit/AppKit.h>
#include "macos_platform.h"
#endif
#include "wireproof_backup.inc"
#include "wireproof_cloud.inc"
// Store only reusable choices, never mission balances or queued actions.
namespace WPCheats {
Snapshot LoadPreferences() {
    Snapshot s;
    NSDictionary *values=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"Wireproof.CheatPreferences.v1"];
    auto flag=[&](NSString *key) { id v=values[key];return [v isKindOfClass:NSNumber.class] && [v boolValue]; };
    auto speed=[&](NSString *key) { id v=values[key];if(![v isKindOfClass:NSNumber.class])return 4;double n=[v doubleValue];return std::isfinite(n)&&n==std::floor(n)&&n>=1&&n<=12?(int)n:4; };
    s.invincible=flag(@"invincible");s.reveal=flag(@"reveal");s.instant=flag(@"instant");s.free=flag(@"free");s.weapons=flag(@"weapons");s.anywhere=flag(@"anywhere");s.unlock=flag(@"unlock");s.damagedHealth=flag(@"damagedHealth");
    s.infantry=speed(@"infantry");s.vehicles=speed(@"vehicles");s.aircraft=speed(@"aircraft");return s;
}
void SavePreferences(const Snapshot& s) {
    [NSUserDefaults.standardUserDefaults setObject:@{@"invincible":@(s.invincible),@"reveal":@(s.reveal),@"instant":@(s.instant),@"free":@(s.free),@"weapons":@(s.weapons),@"anywhere":@(s.anywhere),@"unlock":@(s.unlock),@"damagedHealth":@(s.damagedHealth),@"infantry":@(s.infantry),@"vehicles":@(s.vehicles),@"aircraft":@(s.aircraft)} forKey:@"Wireproof.CheatPreferences.v1"];
}
}
#if !TARGET_OS_IPHONE
namespace WPOrders { int LoadUIScale() { NSNumber *v=[NSUserDefaults.standardUserDefaults objectForKey:@"Wireproof.UIScale.Mac"];return v?v.intValue:100; } }
#endif
static NSString* Profile(void) { return [[NSUserDefaults standardUserDefaults] stringForKey:@"WPActiveRules"] ?: @"Custom 1"; }
static NSString* StoreKey(void) { return [@"WPRules." stringByAppendingString:Profile()]; }
static NSDictionary* Values(void) { return [[NSUserDefaults standardUserDefaults] dictionaryForKey:StoreKey()] ?: @{}; }
int WP_LoadRule(const char* key,int fallback,int low,int high) {
    if ([Profile() isEqualToString:@"Stock"]) return fallback;
    id value=Values()[@(key)];
    if (![value isKindOfClass:NSNumber.class]) return fallback;
    double n=[value doubleValue];
    if (!isfinite(n) || n!=floor(n) || n<low || n>high) return fallback;
    return (int)n;
}
static NSString* DisplayValue(int index,int value) {
    for(int c=0;c<WP_RuleChoiceCount(index);++c)
        if(WP_RuleChoiceValue(index,c)==value) return @(WP_RuleChoiceLabel(index,c));
    return [NSString stringWithFormat:@"%d",value];
}
static BOOL SaveValue(int index,NSString* text) {
    if(index<0 || index>=WP_RuleCount() || [Profile() isEqualToString:@"Stock"]) return NO;
    NSScanner* scanner=[NSScanner scannerWithString:text]; long long value;
    if (![scanner scanLongLong:&value] || !scanner.isAtEnd || value<WP_RuleMin(index) || value>WP_RuleMax(index) || !WP_RuleValueValid(index,(int)value)) return NO;
    NSMutableDictionary* values=[Values() mutableCopy];
    values[@(WP_RuleKey(index))]=@(value);
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:StoreKey()]; return YES;
}
static NSString* RuleGroup(int i) { NSString *n=@(WP_RuleName(i));return [n substringToIndex:[n rangeOfString:@" / " options:NSBackwardsSearch].location]; }
static NSString* RuleField(int i) { NSString *n=@(WP_RuleName(i));return [n substringFromIndex:[n rangeOfString:@" / " options:NSBackwardsSearch].location+3]; }
static NSArray<NSNumber*>* GroupRules(NSString *group) { NSMutableArray *a=[NSMutableArray new];for(int i=0;i<WP_RuleCount();i++)if([RuleGroup(i) isEqual:group])[a addObject:@(i)];return a; }
static NSDictionary* CopyPlan(NSDictionary* fields,NSString* group) {
    NSMutableDictionary *plan=[NSMutableDictionary new];
    for(NSNumber *index in GroupRules(group)){int i=index.intValue;NSNumber *v=fields[RuleField(i)];if(v && v.intValue>=WP_RuleMin(i) && v.intValue<=WP_RuleMax(i) && WP_RuleValueValid(i,v.intValue))plan[@(WP_RuleKey(i))]=v;}
    return plan.count==fields.count?plan:nil;
}
static NSArray* CopyTargets(NSDictionary* fields,NSString* source) {
    NSMutableOrderedSet *groups=[NSMutableOrderedSet new];for(int i=0;i<WP_RuleCount();i++){NSString *g=RuleGroup(i);if(![g isEqual:source] && CopyPlan(fields,g))[groups addObject:g];}return groups.array;
}
static void ApplyCopies(NSDictionary* fields,NSArray* targets) {
    if([Profile() isEqual:@"Stock"])return;
    NSMutableDictionary *values=[Values() mutableCopy];for(NSString *g in targets){NSDictionary *plan=CopyPlan(fields,g);if(plan)[values addEntriesFromDictionary:plan];}
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:StoreKey()];
}
static NSArray<NSString*>* IconNames() { return @[@"AppIcon", @"AppIconGDI", @"AppIconNod"]; }
static NSArray<NSString*>* IconTitles() { return @[@"Command & Conquer (default)", @"GDI", @"Nod"]; }
#if TARGET_OS_IPHONE
@interface WPIconPicker : UITableViewController
@property(nonatomic) BOOL finished;
@property(nonatomic) BOOL changing;
@end
@implementation WPIconPicker
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=@"App Icon"; self.tableView.rowHeight=88;
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(done)];
}
- (void)done { if(!self.changing) self.finished=YES; }
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)section { return IconNames().count; }
- (NSString*)tableView:(UITableView*)t titleForFooterInSection:(NSInteger)section {
    return UIApplication.sharedApplication.supportsAlternateIcons ? @"Changes the standalone app’s Home Screen icon." : @"This installation does not support changing its Home Screen icon. Install the standalone app to use this feature.";
}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.textLabel.text=IconTitles()[p.row]; cell.textLabel.numberOfLines=0;
    cell.imageView.image=[UIImage imageNamed:[IconNames()[p.row] stringByAppendingString:@"Preview"]];
    cell.accessoryType=[(UIApplication.sharedApplication.alternateIconName ?: @"AppIcon") isEqual:IconNames()[p.row]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p {
    [t deselectRowAtIndexPath:p animated:YES];
    if(self.changing || !UIApplication.sharedApplication.supportsAlternateIcons)return;
    NSString *name=p.row ? IconNames()[p.row] : nil;
    if([(UIApplication.sharedApplication.alternateIconName ?: @"AppIcon") isEqual:IconNames()[p.row]])return;
    self.changing=YES; self.navigationItem.rightBarButtonItem.enabled=NO;
    [UIApplication.sharedApplication setAlternateIconName:name completionHandler:^(NSError *error){
        dispatch_async(dispatch_get_main_queue(), ^{
            self.changing=NO;self.navigationItem.rightBarButtonItem.enabled=YES;[self.tableView reloadData];
            if(error){UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Icon could not be changed" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];}
        });
    }];
}
@end
@interface WPApplyPicker : UITableViewController
@property(nonatomic,copy) NSString *source;
@property(nonatomic,copy) NSArray *items;
@property(nonatomic,strong) NSMutableIndexSet *selected;
@property(nonatomic,copy) NSDictionary *fields;
@end
@implementation WPApplyPicker
- (void)viewDidLoad {
    [super viewDidLoad];self.selected=[NSMutableIndexSet new];self.title=self.fields?@"Choose target units":@"Choose settings";
    self.items=self.fields?CopyTargets(self.fields,self.source):GroupRules(self.source);
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:self.fields?@"Apply":@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(next)];self.navigationItem.rightBarButtonItem.enabled=NO;
}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s {return self.items.count;}
- (NSString*)tableView:(UITableView*)t titleForHeaderInSection:(NSInteger)s {return self.fields?@"Only targets supporting every selected value are listed. Unselected settings stay unchanged.":@"Select the current values to copy. Changes affect all owners after restart and a new mission.";}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p {
    UITableViewCell *c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if(self.fields)c.textLabel.text=self.items[p.row];else{int i=[self.items[p.row] intValue];c.textLabel.text=RuleField(i);c.detailTextLabel.text=DisplayValue(i,WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i)));}
    c.textLabel.numberOfLines=0;c.accessoryType=[self.selected containsIndex:p.row]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return c;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p {if([self.selected containsIndex:p.row])[self.selected removeIndex:p.row];else[self.selected addIndex:p.row];self.navigationItem.rightBarButtonItem.enabled=self.selected.count>0;[t reloadData];}
- (void)next {
    if(!self.fields){NSMutableDictionary *fields=[NSMutableDictionary new];[self.selected enumerateIndexesUsingBlock:^(NSUInteger n,BOOL *stop){int i=[self.items[n] intValue];fields[RuleField(i)]=@(WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i)));}];WPApplyPicker *targets=[[WPApplyPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];targets.source=self.source;targets.fields=fields;[self.navigationController pushViewController:targets animated:YES];return;}
    NSMutableArray *targets=[NSMutableArray new];[self.selected enumerateIndexesUsingBlock:^(NSUInteger n,BOOL *stop){[targets addObject:self.items[n]];}];
    NSMutableArray *summary=[NSMutableArray new];for(NSNumber *index in GroupRules(self.source)){int i=index.intValue;NSNumber *v=self.fields[RuleField(i)];if(v)[summary addObject:[NSString stringWithFormat:@"%@: %@",RuleField(i),DisplayValue(i,v.intValue)]];}
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Apply selected settings?" message:[NSString stringWithFormat:@"%@\n\nTo: %@\n\nRestart and start a new mission to use these changes.",[summary componentsJoinedByString:@"\n"],[targets componentsJoinedByString:@", "]] preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){ApplyCopies(self.fields,targets);[self.navigationController popToViewController:self.navigationController.viewControllers[self.navigationController.viewControllers.count-3] animated:YES];}]];[self presentViewController:a animated:YES completion:nil];
}
@end
@interface WPWorkshop : UITableViewController
@property BOOL finished;
@property NSString* group;
@property NSArray<NSString*>* groups;
@property NSArray<NSNumber*>* indices;
@end
@implementation WPWorkshop
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.group ?: @"Mod Workshop";
    self.tableView.backgroundColor=UIColor.systemBackgroundColor;
    if (!self.group) {
        NSMutableOrderedSet* groups=[NSMutableOrderedSet new];
        for(int i=0;i<WP_RuleCount();++i) {
            NSString* name=@(WP_RuleName(i)); NSRange split=[name rangeOfString:@" / " options:NSBackwardsSearch];
            [groups addObject:[name substringToIndex:split.location]];
        }
        self.groups=groups.array;
        self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(done)];
        self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Preset" style:UIBarButtonItemStylePlain target:self action:@selector(preset)];
    } else {
        NSMutableArray* indices=[NSMutableArray new];
        for(int i=0;i<WP_RuleCount();++i) if ([@(WP_RuleName(i)) hasPrefix:[self.group stringByAppendingString:@" / "]]) [indices addObject:@(i)];
        self.indices=indices;
        self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"Apply to…" style:UIBarButtonItemStylePlain target:self action:@selector(applyTo)];
    }
}
- (void)applyTo {if([Profile() isEqual:@"Stock"]){[self preset];return;}WPApplyPicker *picker=[[WPApplyPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];picker.source=self.group;[self.navigationController pushViewController:picker animated:YES];}
- (void)done { self.finished=YES; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }
- (NSString*)tableView:(UITableView*)t titleForHeaderInSection:(NSInteger)s {
    return [NSString stringWithFormat:@"Preset: %@ • Changes apply after restart. Modified rules disable multiplayer. Type edits affect every owner, including enemies. Prerequisites and ownership are advanced bitmasks.",Profile()];
}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s { return self.group ? self.indices.count : self.groups.count; }
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p {
    UITableViewCell* cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (!self.group) { cell.textLabel.text=self.groups[p.row]; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator; }
    else { int i=self.indices[p.row].intValue;
        NSString* name=@(WP_RuleName(i));cell.textLabel.text=[name substringFromIndex:self.group.length+3];
        cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ (stock %@)",DisplayValue(i,WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i))),DisplayValue(i,WP_RuleDefault(i))];
        cell.textLabel.numberOfLines=0; cell.detailTextLabel.numberOfLines=0;
    } return cell;
}
- (void)preset {
    UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Rules preset" message:@"Choose Stock to restore original gameplay after restarting. Your custom presets remain saved." preferredStyle:UIAlertControllerStyleAlert];
    for(NSString* name in @[@"Stock",@"Custom 1",@"Custom 2",@"Custom 3"])
        [a addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){[[NSUserDefaults standardUserDefaults] setObject:name forKey:@"WPActiveRules"];[self.tableView reloadData];}]];
    if (![Profile() isEqualToString:@"Stock"]) [a addAction:[UIAlertAction actionWithTitle:@"Reset this preset…" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action){
        UIAlertController* confirm=[UIAlertController alertControllerWithTitle:@"Reset preset?" message:@"This clears only the selected custom rules. Saves and game data are kept." preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action){[[NSUserDefaults standardUserDefaults] removeObjectForKey:StoreKey()];[self.tableView reloadData];}]];
        [self presentViewController:confirm animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]]; [self presentViewController:a animated:YES completion:nil];
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p {
    if (!self.group) { WPWorkshop* detail=[[WPWorkshop alloc] initWithStyle:UITableViewStyleInsetGrouped];detail.group=self.groups[p.row];[self.navigationController pushViewController:detail animated:YES];return; }
    if ([Profile() isEqualToString:@"Stock"]) { UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Stock is read-only" message:@"Go back and choose a Custom preset first." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];return; }
    int i=self.indices[p.row].intValue;
    if(WP_RuleChoiceCount(i)) {
        UIAlertController* choices=[UIAlertController alertControllerWithTitle:@(WP_RuleName(i)) message:[NSString stringWithFormat:@"%s\nApplies after restart and a new mission.",WP_RuleHelp(i)] preferredStyle:UIAlertControllerStyleAlert];
        for(int c=0;c<WP_RuleChoiceCount(i);++c) {
            int selected=WP_RuleChoiceValue(i,c);
            [choices addAction:[UIAlertAction actionWithTitle:@(WP_RuleChoiceLabel(i,c)) style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){SaveValue(i,[NSString stringWithFormat:@"%d",selected]);[t reloadData];}]];
        }
        [choices addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:choices animated:YES completion:nil]; return;
    }
    UIAlertController* a=[UIAlertController alertControllerWithTitle:@(WP_RuleName(i)) message:[NSString stringWithFormat:@"%s\nWhole number from %d to %d. Applies after restart.",WP_RuleHelp(i),WP_RuleMin(i),WP_RuleMax(i)] preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField* field){field.text=[NSString stringWithFormat:@"%d",WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i))];field.keyboardType=UIKeyboardTypeNumbersAndPunctuation;}];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        if (!SaveValue(i,a.textFields.firstObject.text)) {
            UIAlertController* error=[UIAlertController alertControllerWithTitle:@"Invalid value" message:@"Enter a whole number within the displayed range. Nothing was changed." preferredStyle:UIAlertControllerStyleAlert];[error addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:error animated:YES completion:nil];
        } [t reloadData];
    }]]; [self presentViewController:a animated:YES completion:nil];
}
@end
void WP_ShowWorkshop(void) {
    @autoreleasepool {
        void (^present)(void)=^{
            UIWindowScene* scene=nil;
            for(UIScene* candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive) {scene=(UIWindowScene*)candidate;break;}
            if (!scene) return;
            UIWindow* previous=scene.keyWindow;
            UIWindow* host=[[UIWindow alloc] initWithWindowScene:scene];
            UIViewController* root=[UIViewController new];host.rootViewController=root;host.windowLevel=UIWindowLevelAlert;[host makeKeyAndVisible];
            __block NSInteger choice=-1;
            UIAlertController* menu=[UIAlertController alertControllerWithTitle:@"Saves / Mod Workshop" message:@"Custom rules are for single-player. Restart after editing, then start a new mission. Keep stock saves separate from modded saves." preferredStyle:UIAlertControllerStyleAlert];
            [menu addAction:[UIAlertAction actionWithTitle:@"Manage saves" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){choice=0;}]];
            [menu addAction:[UIAlertAction actionWithTitle:@"Mod Workshop" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){choice=1;}]];
            [menu addAction:[UIAlertAction actionWithTitle:@"Import / Export" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){choice=4;}]];
            [menu addAction:[UIAlertAction actionWithTitle:@"iCloud Sync" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){choice=5;}]];
            [menu addAction:[UIAlertAction actionWithTitle:@"App Icon" style:UIAlertActionStyleDefault handler:^(UIAlertAction* a){choice=3;}]];
            [menu addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleCancel handler:^(UIAlertAction* a){choice=2;}]];
            [root presentViewController:menu animated:NO completion:nil];
            while(choice<0) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            if (choice==1) {
                WPWorkshop* editor=[[WPWorkshop alloc] initWithStyle:UITableViewStyleInsetGrouped];
                host.rootViewController=[[UINavigationController alloc] initWithRootViewController:editor];
                while(!editor.finished) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
            if(choice==3) {
                WPIconPicker *picker=[[WPIconPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
                host.rootViewController=[[UINavigationController alloc] initWithRootViewController:picker];
                while(!picker.finished) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
            if(choice==5) {
                WPCloudPicker *picker=[[WPCloudPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
                host.rootViewController=[[UINavigationController alloc] initWithRootViewController:picker];
                while(!picker.finished) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
            if(choice==4) {
                WPBackupPicker *picker=[[WPBackupPicker alloc] initWithStyle:UITableViewStyleInsetGrouped];
                host.rootViewController=[[UINavigationController alloc] initWithRootViewController:picker];
                while(!picker.finished) [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
            host.hidden=YES;[previous makeKeyAndVisible];
            if (choice==0) TiberianDawn_ManageSaveGames();
        };
        if (NSThread.isMainThread) present(); else dispatch_sync(dispatch_get_main_queue(),present);
    }
}
#else
// macOS allows a runtime Dock icon without modifying the signed app bundle.
void WP_ShowMultiplayerRestriction(void) {
    NSAlert* alert=[NSAlert new];alert.messageText=@"Multiplayer unavailable with custom rules";
    alert.informativeText=@"Select the Stock preset and restart the app before starting multiplayer.";
    [alert runModal];
}
void WP_ApplySavedAppIcon(void) {
    NSString *name=[NSUserDefaults.standardUserDefaults stringForKey:@"Wireproof.AppIcon"] ?: @"AppIcon";
    if(![IconNames() containsObject:name])name=@"AppIcon";
    NSImage *image=[NSImage imageNamed:[name stringByAppendingString:@"Preview"]];
    if(image)NSApp.applicationIconImage=image;
}
static void PickAppIcon() {
    NSAlert *a=[NSAlert new];a.messageText=@"App Icon";a.informativeText=@"Choose the Dock icon. Finder uses the default icon. Your choice is restored when the app starts.";
    NSPopUpButton *picker=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,340,32) pullsDown:NO];
    [picker addItemsWithTitles:IconTitles()];
    NSString *current=[NSUserDefaults.standardUserDefaults stringForKey:@"Wireproof.AppIcon"] ?: @"AppIcon";
    NSUInteger index=[IconNames() indexOfObject:current];if(index!=NSNotFound)[picker selectItemAtIndex:index];
    for(NSUInteger i=0;i<IconNames().count;i++){NSImage *preview=[[NSImage imageNamed:[IconNames()[i] stringByAppendingString:@"Preview"]] copy];preview.size=NSMakeSize(48,48);[picker itemAtIndex:i].image=preview;}
    a.accessoryView=picker;[a addButtonWithTitle:@"Apply"];[a addButtonWithTitle:@"Cancel"];
    if([a runModal]==NSAlertFirstButtonReturn){[NSUserDefaults.standardUserDefaults setObject:IconNames()[picker.indexOfSelectedItem] forKey:@"Wireproof.AppIcon"];WP_ApplySavedAppIcon();}
}
static NSArray* PickCopies(NSArray* titles,NSString* heading) {
    NSAlert *a=[NSAlert new];a.messageText=heading;
    NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,440,320)];scroll.hasVerticalScroller=YES;
    NSView *content=[[NSView alloc] initWithFrame:NSMakeRect(0,0,420,MAX(320,titles.count*32))];NSMutableArray *checks=[NSMutableArray new];
    for(NSUInteger n=0;n<titles.count;n++){NSButton *b=[NSButton checkboxWithTitle:titles[n] target:nil action:nil];b.frame=NSMakeRect(0,content.frame.size.height-(n+1)*32,420,30);[content addSubview:b];[checks addObject:b];}
    scroll.documentView=content;a.accessoryView=scroll;[a addButtonWithTitle:@"Next"];[a addButtonWithTitle:@"Cancel"];if([a runModal]!=NSAlertFirstButtonReturn)return nil;
    NSMutableArray *indices=[NSMutableArray new];for(NSUInteger n=0;n<checks.count;n++)if([checks[n] state]==NSControlStateValueOn)[indices addObject:@(n)];return indices;
}
static void MacApplyCopies(int sourceIndex) {
    NSString *source=RuleGroup(sourceIndex);NSArray *rules=GroupRules(source);NSMutableArray *titles=[NSMutableArray new];
    for(NSNumber *n in rules){int i=n.intValue;[titles addObject:[NSString stringWithFormat:@"%@: %@",RuleField(i),DisplayValue(i,WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i)))]];}
    NSArray *chosen=PickCopies(titles,@"Choose settings to copy");if(!chosen.count)return;NSMutableDictionary *fields=[NSMutableDictionary new];
    for(NSNumber *n in chosen){int i=[rules[n.integerValue] intValue];fields[RuleField(i)]=@(WP_LoadRule(WP_RuleKey(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i)));}
    NSArray *targets=CopyTargets(fields,source);NSArray *selected=PickCopies(targets,@"Choose compatible target units");if(!selected.count)return;
    NSMutableArray *dest=[NSMutableArray new];for(NSNumber *n in selected)[dest addObject:targets[n.integerValue]];
    NSAlert *confirm=[NSAlert new];confirm.messageText=@"Apply selected settings?";confirm.informativeText=[NSString stringWithFormat:@"Copy %lu settings from %@ to %@. Unselected settings stay unchanged. Restart and start a new mission afterwards.",(unsigned long)fields.count,source,[dest componentsJoinedByString:@", "]];[confirm addButtonWithTitle:@"Apply"];[confirm addButtonWithTitle:@"Cancel"];if([confirm runModal]==NSAlertFirstButtonReturn)ApplyCopies(fields,dest);
}
// AppKit modal panels can retain key-window focus after dismissal. Restore
// the SDL game window on every exit, including the save-manager branch.
struct WPGameWindowRestore {
    NSWindow* window;
    ~WPGameWindowRestore() { if (window) [window makeKeyAndOrderFront:nil]; }
};
void WP_ShowWorkshop(void) {
    @autoreleasepool {
        WPGameWindowRestore restore{NSApp.keyWindow};
        NSAlert* menu=[NSAlert new];menu.messageText=@"Saves / Mod Workshop";
        [menu addButtonWithTitle:@"Mod Workshop"];[menu addButtonWithTitle:@"Manage saves"];[menu addButtonWithTitle:@"Back"];[menu addButtonWithTitle:@"App Icon"];[menu addButtonWithTitle:@"Import / Export"];[menu addButtonWithTitle:@"iCloud Sync"];
        NSInteger choice=[menu runModal];if(choice==NSAlertFirstButtonReturn+5){ShowCloudPicker();return;}if(choice==NSAlertFirstButtonReturn+4){ShowBackupPicker();return;}if(choice==NSAlertFirstButtonReturn+3){PickAppIcon();return;}if(choice==NSAlertSecondButtonReturn){TiberianDawn_ManageSaveGames();return;}if(choice!=NSAlertFirstButtonReturn)return;
        BOOL finished=NO;
        while(!finished) {
            NSAlert* a=[NSAlert new];a.messageText=@"Mod Workshop";a.informativeText=@"Choose a preset and rule. Edits apply after restarting; use new single-player missions. Stock is read-only. Modified rules disable multiplayer.";
            NSView* view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,440,120)];
            NSPopUpButton* profiles=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,85,440,28) pullsDown:NO];[profiles addItemsWithTitles:@[@"Stock",@"Custom 1",@"Custom 2",@"Custom 3"]];[profiles selectItemWithTitle:Profile()];[view addSubview:profiles];
            NSPopUpButton* rules=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,50,440,28) pullsDown:NO];
            for(int i=0;i<WP_RuleCount();++i)[rules addItemWithTitle:[NSString stringWithFormat:@"%s (stock %d; %d…%d)",WP_RuleName(i),WP_RuleDefault(i),WP_RuleMin(i),WP_RuleMax(i)]];[view addSubview:rules];
            NSTextField* value=[[NSTextField alloc] initWithFrame:NSMakeRect(0,10,440,28)];value.placeholderString=@"New whole-number value (leave blank to select preset only)";[view addSubview:value];a.accessoryView=view;
            [a addButtonWithTitle:@"Save"];[a addButtonWithTitle:@"Done"];[a addButtonWithTitle:@"Reset preset…"];[a addButtonWithTitle:@"Edit selected rule…"];[a addButtonWithTitle:@"Apply to…"];
            NSInteger action=[a runModal];
            if(action==NSAlertFirstButtonReturn+4) {
                [[NSUserDefaults standardUserDefaults] setObject:profiles.titleOfSelectedItem forKey:@"WPActiveRules"];
                if(![Profile() isEqual:@"Stock"])MacApplyCopies((int)rules.indexOfSelectedItem);
                else {NSAlert *error=[NSAlert new];error.messageText=@"Choose a Custom preset first.";[error runModal];}continue;
            }
            if(action==NSAlertFirstButtonReturn+3) {
                [[NSUserDefaults standardUserDefaults] setObject:profiles.titleOfSelectedItem forKey:@"WPActiveRules"];
                if([Profile() isEqualToString:@"Stock"]) { NSAlert* error=[NSAlert new];error.messageText=@"Choose a Custom preset first.";[error runModal];continue; }
                int index=(int)rules.indexOfSelectedItem;
                NSAlert* edit=[NSAlert new];edit.messageText=@(WP_RuleName(index));
                edit.informativeText=[NSString stringWithFormat:@"%s\nStock: %@. Restart and start a new mission after editing.",WP_RuleHelp(index),DisplayValue(index,WP_RuleDefault(index))];
                int current=WP_LoadRule(WP_RuleKey(index),WP_RuleDefault(index),WP_RuleMin(index),WP_RuleMax(index));
                NSPopUpButton* options=nil; NSTextField* number=nil;
                if(WP_RuleChoiceCount(index)) {
                    options=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,360,28) pullsDown:NO];
                    for(int c=0;c<WP_RuleChoiceCount(index);++c) { [options addItemWithTitle:@(WP_RuleChoiceLabel(index,c))];if(WP_RuleChoiceValue(index,c)==current)[options selectItemAtIndex:c]; }
                    edit.accessoryView=options;
                } else {
                    number=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,360,28)]; number.stringValue=[NSString stringWithFormat:@"%d",current];
                    edit.informativeText=[edit.informativeText stringByAppendingFormat:@" Allowed: %d…%d.",WP_RuleMin(index),WP_RuleMax(index)];edit.accessoryView=number;
                }
                [edit addButtonWithTitle:@"Save"];[edit addButtonWithTitle:@"Cancel"];
                if([edit runModal]==NSAlertFirstButtonReturn) {
                    NSString* text=options ? [NSString stringWithFormat:@"%d",WP_RuleChoiceValue(index,(int)options.indexOfSelectedItem)] : number.stringValue;
                    if(!SaveValue(index,text)){NSAlert* error=[NSAlert new];error.messageText=@"Invalid value. Nothing was changed.";[error runModal];}
                }
                continue;
            }
            if(action==NSAlertThirdButtonReturn) {
                NSString* selected=profiles.titleOfSelectedItem;
                if (![selected isEqualToString:@"Stock"]) {
                    NSAlert* confirm=[NSAlert new];confirm.messageText=[@"Reset " stringByAppendingString:selected];
                    confirm.informativeText=@"Clear this preset's custom rules? Saves and game data are kept.";
                    [confirm addButtonWithTitle:@"Cancel"];[confirm addButtonWithTitle:@"Reset"];
                    if([confirm runModal]==NSAlertSecondButtonReturn)
                        [[NSUserDefaults standardUserDefaults] removeObjectForKey:[@"WPRules." stringByAppendingString:selected]];
                }
                continue;
            }
            if(action!=NSAlertFirstButtonReturn) {finished=YES;continue;}
            [[NSUserDefaults standardUserDefaults] setObject:profiles.titleOfSelectedItem forKey:@"WPActiveRules"];
            if(value.stringValue.length && ([Profile() isEqualToString:@"Stock"] || !SaveValue((int)rules.indexOfSelectedItem,value.stringValue))) {
                NSAlert* error=[NSAlert new];error.messageText=@"Choose a Custom preset and enter a value in range.";[error runModal];
            }
        }
    }
}
#endif

#if !TARGET_OS_IPHONE
extern "C" void WP_ShowLiveCheats(void) {
    @autoreleasepool {
        auto state=WPCheats::Shared().snapshot(); if(!state.available)return;
        WPGameWindowRestore restore{NSApp.keyWindow};
        NSAlert* a=[NSAlert new];a.messageText=@"Battlefield Cheats";
        a.informativeText=@"Player only, single-player. Changes apply after closing. Shroud On restores previous exploration plus current unit sight. Toggles and speed persist across missions and launches. Money and power remain in saves. UI size: 75–150%, default 100%.";
        NSView* view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,360,465)];
        NSButton* inv=[NSButton checkboxWithTitle:@"Invincibility" target:nil action:nil];inv.frame=NSMakeRect(0,230,180,24);inv.state=state.invincible;[view addSubview:inv];
        NSButton* shroud=[NSButton checkboxWithTitle:@"Shroud On" target:nil action:nil];shroud.frame=NSMakeRect(180,230,180,24);shroud.state=!state.reveal;[view addSubview:shroud];
        NSButton* instant=[NSButton checkboxWithTitle:@"Instant Build" target:nil action:nil];instant.frame=NSMakeRect(0,270,180,24);instant.state=state.instant;[view addSubview:instant];
        NSButton* freeBuild=[NSButton checkboxWithTitle:@"Zero Cost" target:nil action:nil];freeBuild.frame=NSMakeRect(180,270,180,24);freeBuild.state=state.free;[view addSubview:freeBuild];
        NSButton* weapons=[NSButton checkboxWithTitle:@"Instant Weapons" target:nil action:nil];weapons.frame=NSMakeRect(0,310,180,24);weapons.state=state.weapons;[view addSubview:weapons];
        NSButton* anywhere=[NSButton checkboxWithTitle:@"Build Anywhere" target:nil action:nil];anywhere.frame=NSMakeRect(180,310,180,24);anywhere.state=state.anywhere;[view addSubview:anywhere];
        NSButton* unlock=[NSButton checkboxWithTitle:@"Unlock GDI + Nod" target:nil action:nil];unlock.frame=NSMakeRect(0,390,360,24);unlock.state=state.unlock;[view addSubview:unlock];
        NSButton* health=[NSButton checkboxWithTitle:@"Damaged building health" target:nil action:nil];health.frame=NSMakeRect(0,430,360,24);health.state=state.damagedHealth;[view addSubview:health];
        NSMutableArray<NSSlider*>* speeds=[NSMutableArray array];
        NSArray* names=@[@"Infantry",@"Vehicles",@"Aircraft"];
        int values[]={state.infantry,state.vehicles,state.aircraft};
        for(int i=0;i<3;++i) {
            NSTextField* label=[NSTextField labelWithString:[names[i] stringByAppendingString:@" speed: 0.25–3×"]];label.frame=NSMakeRect(0,195-i*45,180,24);[view addSubview:label];
            NSSlider* slider=[NSSlider sliderWithValue:values[i] minValue:1 maxValue:12 target:nil action:nil];slider.frame=NSMakeRect(180,195-i*45,180,24);slider.numberOfTickMarks=12;slider.allowsTickMarkValuesOnly=YES;[view addSubview:slider];[speeds addObject:slider];
        }
        NSPopUpButton* money=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,50,175,30)];[money addItemsWithTitles:@[@"No added money",@"Add $1,000",@"Add $10,000"]];[view addSubview:money];
        NSPopUpButton* power=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(180,50,175,30)];[power addItemsWithTitles:@[@"No added power",@"Add 100 power",@"Add 1,000 power"]];[view addSubview:power];
        NSTextField* status=[NSTextField labelWithString:[NSString stringWithFormat:@"Credits: %d   Power: %d / %d",state.money,state.power,state.drain]];status.frame=NSMakeRect(0,10,360,25);[view addSubview:status];
        NSTextField *uiLabel=[NSTextField labelWithString:@"UI size (100% default)"];uiLabel.frame=NSMakeRect(0,350,180,24);[view addSubview:uiLabel];
        NSSlider *uiScale=[NSSlider sliderWithValue:WPOrders::Shared().uiScale() minValue:75 maxValue:150 target:nil action:nil];uiScale.frame=NSMakeRect(180,350,180,24);uiScale.numberOfTickMarks=16;uiScale.allowsTickMarkValuesOnly=YES;[view addSubview:uiScale];
        a.accessoryView=view;[a addButtonWithTitle:@"Apply"];[a addButtonWithTitle:@"Cancel"];
        if([a runModal]==NSAlertFirstButtonReturn) {
            WPOrders::Shared().setUIScale((int)lround(uiScale.doubleValue/5)*5);
            [NSUserDefaults.standardUserDefaults setInteger:WPOrders::Shared().uiScale() forKey:@"Wireproof.UIScale.Mac"];
            WPCheats::Shared().weapons(weapons.state==NSControlStateValueOn);
            WPCheats::Shared().anywhere(anywhere.state==NSControlStateValueOn);
            WPCheats::Shared().unlock(unlock.state==NSControlStateValueOn);
            WPCheats::Shared().damagedHealth(health.state==NSControlStateValueOn);
            WPCheats::Shared().instant(instant.state==NSControlStateValueOn);
            WPCheats::Shared().free(freeBuild.state==NSControlStateValueOn);
            WPCheats::Shared().invincible(inv.state==NSControlStateValueOn);
            WPCheats::Shared().reveal(shroud.state!=NSControlStateValueOn);
            for(int i=0;i<3;++i)WPCheats::Shared().speed(i,(int)lround(speeds[i].doubleValue));
            WPCheats::Shared().addMoney(money.indexOfSelectedItem==1?1000:money.indexOfSelectedItem==2?10000:0);
            WPCheats::Shared().addPower(power.indexOfSelectedItem==1?100:power.indexOfSelectedItem==2?1000:0);
        }
    }
}
#endif
