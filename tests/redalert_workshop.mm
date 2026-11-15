// Standalone host validation. Run in a unique executable domain, never the app.
#include "../redalert/wireproof_workshop.mm"
#include <cassert>
static bool testActive=false;
extern "C" {
int RA_RuleCount(){return 4;}
const char* RA_RuleName(int i){static const char* n[]={"Vehicles / Medium Tank / Cost","Vehicles / Medium Tank / Armor","Vehicles / Light Tank / Cost","Vehicles / Light Tank / Armor"};return n[i];}
const char* RA_RuleKey(int i){static const char* k[]={"cost","armor","othercost","otherarmor"};return k[i];}
int RA_RuleDefault(int i){return i%2?0:100;}
int RA_RuleMin(int){return 0;}
int RA_RuleMax(int i){return i%2?4:50000;}
int RA_RuleChoiceCount(int i){return i%2?3:0;}
int RA_RuleChoiceValue(int,int c){return c*2;}
const char* RA_RuleChoiceLabel(int,int c){return c==0?"None":c==1?"Light":"Concrete";}
int RA_RuleValueValid(int i,int v){return i>=0&&i<4 && (i%2==0?v>=0&&v<=50000:v>=0&&v<=4&&v%2==0);}
int RA_RulesActive(){return testActive;}
}
int main(){@autoreleasepool{
    NSUserDefaults* d=NSUserDefaults.standardUserDefaults;
    // Isolate this test from every real preference domain, including TD's.
    NSString* domain=NSBundle.mainBundle.bundleIdentifier?:NSProcessInfo.processInfo.processName;
    [d removePersistentDomainForName:domain];
    assert([Profile() isEqual:@"Stock"]);assert(!Save(0,@"250"));
    [d setObject:@"Custom 1" forKey:ActiveKey];assert(Save(0,@"250"));assert(RA_LoadRule("cost",100,0,50000)==250);assert(RA_RulesRequireSinglePlayer());
    for(NSString* bad in @[@"-1",@"50001",@"12.5",@"100abc",@"",@"999999999999999999999999999"]){assert(!Save(0,bad));assert(RA_LoadRule("cost",100,0,50000)==250);}
    assert(Save(1,@"2"));assert(!Save(1,@"3"));assert([Value(1) isEqual:@"Light"]);assert(!Save(-1,@"1"));assert(!Save(4,@"1"));
    [d setObject:@"Custom 2" forKey:ActiveKey];assert(RA_LoadRule("cost",100,0,50000)==100);assert(Save(0,@"333"));
    [d setObject:@"Custom 3" forKey:ActiveKey];assert(RA_LoadRule("cost",100,0,50000)==100);
    [d setObject:@"Custom 1" forKey:ActiveKey];assert(RA_LoadRule("cost",100,0,50000)==250);
    [d setObject:@"Custom 1" forKey:@"WPActiveRules"];[d setObject:@{@"cost":@999} forKey:@"WPRules.Custom 1"];assert(RA_LoadRule("cost",100,0,50000)==250);
    for(id bad in @[@1.5,@"500",@(NAN),@(INFINITY),@(-1),@50001]){[d setObject:@{@"cost":bad} forKey:Store()];assert(RA_LoadRule("cost",100,0,50000)==100);}
    [d removeObjectForKey:Store()];assert(!RA_RulesRequireSinglePlayer());
    [d setObject:@"Stock" forKey:ActiveKey];assert(RA_LoadRule("cost",100,0,50000)==100);assert(!RA_RulesRequireSinglePlayer());testActive=true;assert(RA_RulesRequireSinglePlayer());testActive=false;
    [d setObject:@"Not a real profile" forKey:ActiveKey];assert([Profile() isEqual:@"Stock"]);
    assert(Groups().count==2);assert(Fields(@"Vehicles / Medium Tank").count==2);
    [d setObject:@"Custom 3" forKey:ActiveKey];assert(Save(0,@"250"));assert(Save(3,@"4"));
    NSDictionary* selected=SelectedFields(@"Vehicles / Medium Tank",[NSIndexSet indexSetWithIndex:0]);assert(selected.count==1);
    assert(CopyTargets(selected,@"Vehicles / Medium Tank").count==1);
    assert(!CopyPlan(@{@"Cost":@50001},@"Vehicles / Light Tank"));assert(!CopyPlan(@{@"Armor":@3},@"Vehicles / Light Tank"));assert(!CopyPlan(@{@"Unknown":@2},@"Vehicles / Light Tank"));
    ApplyCopies(selected,@[@"Vehicles / Light Tank"]);assert(RA_LoadRule("othercost",100,0,50000)==250);assert(RA_LoadRule("otherarmor",0,0,4)==4);
    [d setObject:@"Stock" forKey:ActiveKey];ApplyCopies(@{@"Cost":@999},@[@"Vehicles / Light Tank"]);assert(RA_LoadRule("othercost",100,0,50000)==100);
    [d setObject:@"Custom 3" forKey:ActiveKey];assert(RA_LoadRule("othercost",100,0,50000)==250);
    [d removePersistentDomainForName:domain];puts("Red Alert Workshop: validation, presets, isolation and multiplayer guard passed");
}}
