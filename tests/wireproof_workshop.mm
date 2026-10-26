// Standalone host test: validation and preset isolation, no game assets needed.
#include "../platform/apple/wireproof_workshop.mm"
#include <cassert>
extern "C" {
int WP_RuleCount(){return 2;}
const char* WP_RuleName(int){return "Vehicles / TEST / Cost";}
const char* WP_RuleKey(int i){return i ? "factory" : "test";}
int WP_RuleDefault(int i){return i ? 0 : 100;}
int WP_RuleMin(int i){return i ? 0 : 1;}
int WP_RuleMax(int i){return i ? 8 : 50000;}
const char* WP_RuleHelp(int){return "Validation fixture";}
int WP_RuleChoiceCount(int i){return i ? 5 : 0;}
int WP_RuleChoiceValue(int,int c){return c*2;}
const char* WP_RuleChoiceLabel(int,int c){static const char* names[]={"None","Infantry","Vehicles","Aircraft","Buildings"};return names[c];}
int WP_RuleValueValid(int i,int v){return i==0 ? v>=1&&v<=50000 : i==1&&v>=0&&v<=8&&v%2==0;}
int WP_RulesActive(){return 0;}
void TiberianDawn_ManageSaveGames(){}
}
int main(){@autoreleasepool {
 NSUserDefaults* d=NSUserDefaults.standardUserDefaults;
 [d setObject:@"WPValidationTemporary" forKey:@"WPActiveRules"];
 [d removeObjectForKey:StoreKey()];
 assert(WP_LoadRule("test",100,1,50000)==100);
 assert(SaveValue(0,@"250"));assert(WP_LoadRule("test",100,1,50000)==250);
 for(NSString* invalid in @[@"0",@"50001",@"12.5",@"100abc",@"",@"999999999999999999999999999"]){assert(!SaveValue(0,invalid));assert(WP_LoadRule("test",100,1,50000)==250);}
 assert(SaveValue(1,@"6")); assert(WP_LoadRule("factory",0,0,8)==6);
 assert(!SaveValue(1,@"3")); assert(WP_LoadRule("factory",0,0,8)==6);
 assert([DisplayValue(1,6) isEqualToString:@"Aircraft"]);
 assert(!SaveValue(-1,@"2")); assert(!SaveValue(2,@"2"));
 [d setObject:@{@"test":@1.5} forKey:StoreKey()];assert(WP_LoadRule("test",100,1,50000)==100);
 [d setObject:@{@"test":@"500"} forKey:StoreKey()];assert(WP_LoadRule("test",100,1,50000)==100);
 [d removeObjectForKey:StoreKey()];[d setObject:@"Stock" forKey:@"WPActiveRules"];
 assert(WP_LoadRule("test",100,1,50000)==100); assert(!SaveValue(0,@"500"));
 // Selecting Stock does not destroy another preset; resetting it restores defaults.
 [d setObject:@"WPValidationTemporary" forKey:@"WPActiveRules"]; assert(SaveValue(0,@"300"));
 [d setObject:@"Stock" forKey:@"WPActiveRules"]; assert(WP_LoadRule("test",100,1,50000)==100);
 [d setObject:@"WPValidationTemporary" forKey:@"WPActiveRules"]; assert(WP_LoadRule("test",100,1,50000)==300);
 [d removeObjectForKey:StoreKey()]; assert(WP_LoadRule("test",100,1,50000)==100);
 [d removeObjectForKey:@"WPActiveRules"];
 puts("Workshop validation and stock fallback passed");
} }
