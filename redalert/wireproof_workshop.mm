#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#include "wireproof_rules.h"
#include <cmath>
static NSString* const ActiveKey=@"Wireproof.RedAlert.Workshop.Active.v1";
static NSArray* Profiles(){return @[@"Stock",@"Custom 1",@"Custom 2",@"Custom 3"];}
static NSString* Profile(){NSString* p=[NSUserDefaults.standardUserDefaults stringForKey:ActiveKey];return [Profiles() containsObject:p]?p:@"Stock";}
static NSString* Store(){return [@"Wireproof.RedAlert.Workshop.Rules.v1." stringByAppendingString:Profile()];}
static NSDictionary* Values(){return [NSUserDefaults.standardUserDefaults dictionaryForKey:Store()]?:@{};}
int RA_LoadRule(const char* key,int fallback,int low,int high){
    if([Profile() isEqual:@"Stock"])return fallback;
    id value=Values()[@(key)];if(![value isKindOfClass:NSNumber.class])return fallback;
    double n=[value doubleValue];return std::isfinite(n)&&n==floor(n)&&n>=low&&n<=high?(int)n:fallback;
}
int RA_RulesRequireSinglePlayer(){
    if(RA_RulesActive())return 1;
    for(int i=0;i<RA_RuleCount();++i){int v=RA_LoadRule(RA_RuleKey(i),RA_RuleDefault(i),RA_RuleMin(i),RA_RuleMax(i));if(RA_RuleValueValid(i,v)&&v!=RA_RuleDefault(i))return 1;}return 0;
}
static BOOL Save(int i,NSString* text){
    if(i<0||i>=RA_RuleCount()||[Profile() isEqual:@"Stock"])return NO;
    NSScanner* s=[NSScanner scannerWithString:text];long long n;
    if(![s scanLongLong:&n]||!s.isAtEnd||n<RA_RuleMin(i)||n>RA_RuleMax(i)||!RA_RuleValueValid(i,(int)n))return NO;
    NSMutableDictionary* values=[Values() mutableCopy];values[@(RA_RuleKey(i))]=@(n);[NSUserDefaults.standardUserDefaults setObject:values forKey:Store()];return YES;
}
static NSString* Group(int i){NSString* n=@(RA_RuleName(i));return [n substringToIndex:[n rangeOfString:@" / " options:NSBackwardsSearch].location];}
static NSString* Field(int i){NSString* n=@(RA_RuleName(i));return [n substringFromIndex:[n rangeOfString:@" / " options:NSBackwardsSearch].location+3];}
static NSString* Value(int i){int v=RA_LoadRule(RA_RuleKey(i),RA_RuleDefault(i),RA_RuleMin(i),RA_RuleMax(i));for(int c=0;c<RA_RuleChoiceCount(i);++c)if(RA_RuleChoiceValue(i,c)==v)return @(RA_RuleChoiceLabel(i,c));return [NSString stringWithFormat:@"%d",v];}
static NSArray* Groups(){NSMutableOrderedSet* a=[NSMutableOrderedSet new];for(int i=0;i<RA_RuleCount();++i)[a addObject:Group(i)];return a.array;}
static NSArray* Fields(NSString* group){NSMutableArray* a=[NSMutableArray new];for(int i=0;i<RA_RuleCount();++i)if([Group(i) isEqual:group])[a addObject:@(i)];return a;}
static NSDictionary* CopyPlan(NSDictionary* fields,NSString* group){
    NSMutableDictionary* plan=[NSMutableDictionary new];for(NSNumber* n in Fields(group)){int i=n.intValue;NSNumber* v=fields[Field(i)];if(v&&RA_RuleValueValid(i,v.intValue))plan[@(RA_RuleKey(i))]=v;}return plan.count==fields.count?plan:nil;
}
static NSArray* CopyTargets(NSDictionary* fields,NSString* source){NSMutableArray* a=[NSMutableArray new];for(NSString* g in Groups())if(![g isEqual:source]&&CopyPlan(fields,g))[a addObject:g];return a;}
static void ApplyCopies(NSDictionary* fields,NSArray* targets){if([Profile() isEqual:@"Stock"])return;NSMutableDictionary* values=[Values() mutableCopy];for(NSString* g in targets){NSDictionary* plan=CopyPlan(fields,g);if(plan)[values addEntriesFromDictionary:plan];}[NSUserDefaults.standardUserDefaults setObject:values forKey:Store()];}
static NSDictionary* SelectedFields(NSString* source,NSIndexSet* selected){NSMutableDictionary* result=[NSMutableDictionary new];NSArray* fields=Fields(source);[selected enumerateIndexesUsingBlock:^(NSUInteger n,BOOL*){int i=[fields[n] intValue];int v=RA_LoadRule(RA_RuleKey(i),RA_RuleDefault(i),RA_RuleMin(i),RA_RuleMax(i));if(RA_RuleValueValid(i,v))result[Field(i)]=@(v);}];return result;}
static NSString* const Help=@"Red Alert presets are separate from Tiberian Dawn. Changes affect every owner, including enemies. Start a NEW mission to apply edits; existing units and loaded saves are not updated. Stock is read-only. Multiplayer requires Stock rules and a fresh mission or restart after playing modified rules.";
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
static UIViewController* Presenter(){for(UIScene* s in UIApplication.sharedApplication.connectedScenes)if([s isKindOfClass:UIWindowScene.class]&&s.activationState==UISceneActivationStateForegroundActive)for(UIWindow* w in ((UIWindowScene*)s).windows)if(w.isKeyWindow){UIViewController* c=w.rootViewController;while(c.presentedViewController)c=c.presentedViewController;return c;}return nil;}
@interface WPRARulesCopy : UITableViewController
@property(nonatomic,copy) NSString* source;
@property(nonatomic,copy) NSDictionary* fields;
@property(nonatomic,copy) NSArray* items;
@property(nonatomic,strong) NSMutableIndexSet* selected;
@end
@implementation WPRARulesCopy
- (void)viewDidLoad{[super viewDidLoad];self.selected=[NSMutableIndexSet new];self.items=self.fields?CopyTargets(self.fields,self.source):Fields(self.source);self.title=self.fields?@"Choose target types":@"Choose settings";self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:self.fields?@"Apply":@"Next" style:UIBarButtonItemStyleDone target:self action:@selector(next)];self.navigationItem.rightBarButtonItem.enabled=NO;}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s{return self.items.count;}
- (NSString*)tableView:(UITableView*)t titleForFooterInSection:(NSInteger)s{return self.fields?@"Only types supporting all selected settings and values are listed. Unselected settings remain unchanged.":@"Select the current preset values to copy. All owners are affected after starting a new mission.";}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p{UITableViewCell* c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];if(self.fields)c.textLabel.text=self.items[p.row];else{int i=[self.items[p.row] intValue];c.textLabel.text=Field(i);c.detailTextLabel.text=Value(i);}c.textLabel.numberOfLines=0;c.accessoryType=[self.selected containsIndex:p.row]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return c;}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p{if([self.selected containsIndex:p.row])[self.selected removeIndex:p.row];else[self.selected addIndex:p.row];self.navigationItem.rightBarButtonItem.enabled=self.selected.count>0;[t reloadData];}
- (void)next{if(!self.fields){WPRARulesCopy* targets=[[WPRARulesCopy alloc] initWithStyle:UITableViewStyleInsetGrouped];targets.source=self.source;targets.fields=SelectedFields(self.source,self.selected);[self.navigationController pushViewController:targets animated:YES];return;}NSMutableArray* targets=[NSMutableArray new];[self.selected enumerateIndexesUsingBlock:^(NSUInteger n,BOOL*){[targets addObject:self.items[n]];}];UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Apply selected settings?" message:[NSString stringWithFormat:@"From: %@\nSettings: %@\nTo: %@\n\nStart a new mission to apply. All owners are affected.",self.source,[[self.fields allKeys] componentsJoinedByString:@", "],[targets componentsJoinedByString:@", "]] preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault handler:^(UIAlertAction*){ApplyCopies(self.fields,targets);[self.navigationController popToViewController:self.navigationController.viewControllers[self.navigationController.viewControllers.count-3] animated:YES];}]];[self presentViewController:a animated:YES completion:nil];}
@end
@interface WPRARulesView : UITableViewController
@property(nonatomic,copy) NSString* group;
@end
@implementation WPRARulesView
- (void)viewDidLoad{[super viewDidLoad];self.title=self.group?:@"Red Alert Workshop";self.navigationItem.rightBarButtonItems=self.group?@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)],[[UIBarButtonItem alloc] initWithTitle:@"Apply to…" style:UIBarButtonItemStylePlain target:self action:@selector(copySettings)]]:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)]];}
- (void)done{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)copySettings{if([Profile() isEqual:@"Stock"])return;WPRARulesCopy* c=[[WPRARulesCopy alloc] initWithStyle:UITableViewStyleInsetGrouped];c.source=self.group;[self.navigationController pushViewController:c animated:YES];}
- (void)viewWillAppear:(BOOL)animated{[super viewWillAppear:animated];if(self.group)self.navigationItem.rightBarButtonItems.lastObject.enabled=![Profile() isEqual:@"Stock"];[self.tableView reloadData];}
- (NSInteger)tableView:(UITableView*)t numberOfRowsInSection:(NSInteger)s{return self.group?Fields(self.group).count:Groups().count+2;}
- (NSString*)tableView:(UITableView*)t titleForFooterInSection:(NSInteger)s{return Help;}
- (UITableViewCell*)tableView:(UITableView*)t cellForRowAtIndexPath:(NSIndexPath*)p{
    UITableViewCell* c=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.textLabel.numberOfLines=0;
    if(self.group){int i=[Fields(self.group)[p.row] intValue];c.textLabel.text=Field(i);c.detailTextLabel.text=Value(i);c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    else if(p.row==0){c.textLabel.text=@"Preset";c.detailTextLabel.text=Profile();}
    else if(p.row==1){c.textLabel.text=@"Reset current preset";c.detailTextLabel.text=@"Clears this preset only";}
    else {c.textLabel.text=Groups()[p.row-2];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}return c;
}
- (void)tableView:(UITableView*)t didSelectRowAtIndexPath:(NSIndexPath*)p{
    [t deselectRowAtIndexPath:p animated:YES];
    if(!self.group&&p.row>1){WPRARulesView* next=[[WPRARulesView alloc] initWithStyle:UITableViewStyleInsetGrouped];next.group=Groups()[p.row-2];[self.navigationController pushViewController:next animated:YES];return;}
    if(!self.group&&p.row==0){UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Select preset" message:@"Start a new mission to apply your selection." preferredStyle:UIAlertControllerStyleAlert];for(NSString* profile in Profiles())[a addAction:[UIAlertAction actionWithTitle:profile style:UIAlertActionStyleDefault handler:^(UIAlertAction*){[NSUserDefaults.standardUserDefaults setObject:profile forKey:ActiveKey];[t reloadData];}]];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];return;}
    if([Profile() isEqual:@"Stock"]){UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Stock is read-only" message:@"Choose Custom 1, 2 or 3 to edit rules." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];return;}
    if(!self.group){UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Reset this preset?" message:Profile() preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction*){[NSUserDefaults.standardUserDefaults removeObjectForKey:Store()];[t reloadData];}]];[self presentViewController:a animated:YES completion:nil];return;}
    int i=[Fields(self.group)[p.row] intValue];UIAlertController* a=[UIAlertController alertControllerWithTitle:Field(i) message:[NSString stringWithFormat:@"%@\nAllowed: %d to %d. All owners are affected.",Value(i),RA_RuleMin(i),RA_RuleMax(i)] preferredStyle:UIAlertControllerStyleAlert];
    if(RA_RuleChoiceCount(i)){for(int c=0;c<RA_RuleChoiceCount(i);++c){int value=RA_RuleChoiceValue(i,c);[a addAction:[UIAlertAction actionWithTitle:@(RA_RuleChoiceLabel(i,c)) style:UIAlertActionStyleDefault handler:^(UIAlertAction*){Save(i,[NSString stringWithFormat:@"%d",value]);[t reloadData];}]];}}
    else {[a addTextFieldWithConfigurationHandler:^(UITextField* f){f.text=Value(i);f.keyboardType=UIKeyboardTypeNumbersAndPunctuation;}];[a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction*){if(!Save(i,a.textFields.firstObject.text)){UIAlertController* e=[UIAlertController alertControllerWithTitle:@"Invalid value" message:@"Enter a whole number in the allowed range. Nothing was saved." preferredStyle:UIAlertControllerStyleAlert];[e addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:e animated:YES completion:nil];}[t reloadData];}]];}
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:a animated:YES completion:nil];
}
@end
void RA_ShowWorkshop(){dispatch_async(dispatch_get_main_queue(),^{WPRARulesView* v=[[WPRARulesView alloc] initWithStyle:UITableViewStyleInsetGrouped];[Presenter() presentViewController:[[UINavigationController alloc] initWithRootViewController:v] animated:YES completion:nil];});}
void RA_ShowMultiplayerRestriction(){dispatch_async(dispatch_get_main_queue(),^{UIAlertController* a=[UIAlertController alertControllerWithTitle:@"Stock rules required" message:@"Select Stock in Red Alert Workshop, then start a new mission or restart before multiplayer." preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[Presenter() presentViewController:a animated:YES completion:nil];});}
#else
#import <AppKit/AppKit.h>
static NSIndexSet* PickMany(NSArray* names,NSString* title){
    NSAlert* a=[NSAlert new];a.messageText=title;a.informativeText=@"Select any number of items. Unselected settings and types stay unchanged.";
    CGFloat height=MAX(40,names.count*26);NSView* content=[[NSView alloc] initWithFrame:NSMakeRect(0,0,430,height)];NSMutableArray* buttons=[NSMutableArray new];
    for(NSUInteger i=0;i<names.count;++i){NSButton* b=[NSButton checkboxWithTitle:names[i] target:nil action:nil];b.frame=NSMakeRect(0,height-26*(i+1),430,24);[content addSubview:b];[buttons addObject:b];}
    NSScrollView* scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,450,MIN(height,360))];scroll.hasVerticalScroller=YES;scroll.documentView=content;a.accessoryView=scroll;[a addButtonWithTitle:@"Continue"];[a addButtonWithTitle:@"Cancel"];if([a runModal]!=NSAlertFirstButtonReturn)return nil;NSMutableIndexSet* selected=[NSMutableIndexSet new];for(NSUInteger i=0;i<buttons.count;++i)if(((NSButton*)buttons[i]).state==NSControlStateValueOn)[selected addIndex:i];return selected;
}
static void CopyMac(NSString* group){NSMutableArray* names=[NSMutableArray new];for(NSNumber* n in Fields(group))[names addObject:[NSString stringWithFormat:@"%@: %@",Field(n.intValue),Value(n.intValue)]];NSIndexSet* indexes=PickMany(names,@"Choose settings to copy");if(!indexes.count)return;NSDictionary* fields=SelectedFields(group,indexes);NSArray* targets=CopyTargets(fields,group);NSIndexSet* chosen=PickMany(targets,@"Choose compatible target types");if(!chosen.count)return;NSMutableArray* destination=[NSMutableArray new];[chosen enumerateIndexesUsingBlock:^(NSUInteger i,BOOL*){[destination addObject:targets[i]];}];NSAlert* confirm=[NSAlert new];confirm.messageText=@"Apply selected settings?";confirm.informativeText=[NSString stringWithFormat:@"From: %@\nSettings: %@\nTo: %@\n\nStart a new mission to apply. All owners are affected.",group,[[fields allKeys] componentsJoinedByString:@", "],[destination componentsJoinedByString:@", "]];[confirm addButtonWithTitle:@"Cancel"];[confirm addButtonWithTitle:@"Apply"];if([confirm runModal]==NSAlertSecondButtonReturn)ApplyCopies(fields,destination);}
// AppKit uses the same validated metadata and preference namespace as UIKit.
void RA_ShowWorkshop(){dispatch_async(dispatch_get_main_queue(),^{
    for(;;){NSAlert* a=[NSAlert new];a.messageText=@"Red Alert Workshop";a.informativeText=Help;NSPopUpButton* profiles=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,80,420,28)];[profiles addItemsWithTitles:Profiles()];[profiles selectItemWithTitle:Profile()];NSPopUpButton* groups=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,30,420,28)];[groups addItemsWithTitles:Groups()];NSView* view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,420,120)];[view addSubview:profiles];[view addSubview:groups];a.accessoryView=view;[a addButtonWithTitle:@"Edit type"];[a addButtonWithTitle:@"Done"];[a addButtonWithTitle:@"Reset preset"];NSInteger result=[a runModal];[NSUserDefaults.standardUserDefaults setObject:profiles.titleOfSelectedItem forKey:ActiveKey];if(result==NSAlertSecondButtonReturn)break;if([Profile() isEqual:@"Stock"])continue;
        if(result==NSAlertThirdButtonReturn){NSAlert* confirm=[NSAlert new];confirm.messageText=@"Reset this Red Alert preset?";confirm.informativeText=Profile();[confirm addButtonWithTitle:@"Cancel"];[confirm addButtonWithTitle:@"Reset"];if([confirm runModal]==NSAlertSecondButtonReturn)[NSUserDefaults.standardUserDefaults removeObjectForKey:Store()];continue;}
        NSArray* fields=Fields(groups.titleOfSelectedItem);for(;;){NSAlert* edit=[NSAlert new];edit.messageText=groups.titleOfSelectedItem;edit.informativeText=@"Choose a field to edit. Changes apply to all owners in a new mission.";NSPopUpButton* picker=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,420,28)];for(NSNumber* n in fields)[picker addItemWithTitle:[NSString stringWithFormat:@"%@: %@",Field(n.intValue),Value(n.intValue)]];edit.accessoryView=picker;[edit addButtonWithTitle:@"Edit"];[edit addButtonWithTitle:@"Back"];[edit addButtonWithTitle:@"Apply to…"];NSInteger choice=[edit runModal];if(choice==NSAlertThirdButtonReturn){CopyMac(groups.titleOfSelectedItem);continue;}if(choice!=NSAlertFirstButtonReturn)break;int i=[fields[picker.indexOfSelectedItem] intValue];NSAlert* value=[NSAlert new];value.messageText=Field(i);value.informativeText=[NSString stringWithFormat:@"Allowed: %d to %d",RA_RuleMin(i),RA_RuleMax(i)];NSControl* input;if(RA_RuleChoiceCount(i)){NSPopUpButton* choices=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(0,0,420,28)];for(int c=0;c<RA_RuleChoiceCount(i);++c)[choices addItemWithTitle:@(RA_RuleChoiceLabel(i,c))];[choices selectItemWithTitle:Value(i)];input=choices;}else {NSTextField* text=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,420,28)];text.stringValue=Value(i);input=text;}value.accessoryView=input;[value addButtonWithTitle:@"Save"];[value addButtonWithTitle:@"Cancel"];if([value runModal]==NSAlertFirstButtonReturn){NSString* text=RA_RuleChoiceCount(i)?[NSString stringWithFormat:@"%d",RA_RuleChoiceValue(i,(int)((NSPopUpButton*)input).indexOfSelectedItem)]:input.stringValue;if(!Save(i,text)){NSAlert* error=[NSAlert new];error.messageText=@"Invalid value. Nothing was saved.";[error runModal];}}}
    }
});}
void RA_ShowMultiplayerRestriction(){dispatch_async(dispatch_get_main_queue(),^{NSAlert* a=[NSAlert new];a.messageText=@"Stock rules required";a.informativeText=@"Select Stock in Red Alert Workshop, then start a new mission or restart before multiplayer.";[a runModal];});}
#endif
