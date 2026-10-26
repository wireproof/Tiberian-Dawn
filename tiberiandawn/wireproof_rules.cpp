#include "common/wireproof_cheats.h"
#include "function.h"
#include "wireproof_rules.h"
#include <vector>
#include <string>
#include <functional>
#include <map>
#include <cctype>
struct WPChoice { int value; const char* label; };
struct WPRuleEntry { std::string key, name; int original, low, high; std::function<void(int)> apply; std::vector<WPChoice> choices; std::string help; };
static const std::vector<WPChoice> factionChoices={{-1,"Use ownership mask"},{0,"Not allowed"},{1,"Allowed"}};
static const std::vector<WPChoice> toggles={{0,"Off"},{1,"On"}};
static const std::vector<WPChoice> armorChoices={{ARMOR_NONE,"None"},{ARMOR_WOOD,"Wood"},{ARMOR_ALUMINUM,"Aluminum"},{ARMOR_STEEL,"Steel"},{ARMOR_CONCRETE,"Concrete"}};
static const std::vector<WPChoice> factoryChoices={{RTTI_NONE,"None"},{RTTI_INFANTRYTYPE,"Infantry"},{RTTI_UNITTYPE,"Vehicles"},{RTTI_AIRCRAFTTYPE,"Aircraft"},{RTTI_BUILDINGTYPE,"Buildings"}};
// Original CnCGEdit weapon labels, in its verified numeric weapon order.
static const std::vector<WPChoice> weaponChoices={
    {WEAPON_NONE,"None"},
    {WEAPON_RIFLE,"Sniper's Rifle"},
    {WEAPON_CHAIN_GUN,"High-V Machine Gun"},
    {WEAPON_PISTOL,"Pistol"},
    {WEAPON_M16,"5.56mm ChainGun"},
    {WEAPON_DRAGON,"Rockets"},
    {WEAPON_FLAMETHROWER,"Infantry Flamer"},
    {WEAPON_FLAME_TONGUE,"Tank Flamer"},
    {WEAPON_CHEMSPRAY,"Chem Spray"},
    {WEAPON_GRENADE,"Grenade"},
    {WEAPON_75MM,"70mm Cannon"},
    {WEAPON_105MM,"120mm Cannon"},
    {WEAPON_120MM,"120mm Cannon (apr)"},
    {WEAPON_TURRET_GUN,"Turret Cannon"},
    {WEAPON_MAMMOTH_TUSK,"Missle Pack"},
    {WEAPON_MLRS,"277mm Rockets"},
    {WEAPON_155MM,"Ballistic Charges"},
    {WEAPON_M60MG,"Machine Gun"},
    {WEAPON_TOMAHAWK,"Gunboat Missile"},
    {WEAPON_TOW_TWO,"Rocket Launcher"},
    {WEAPON_NAPALM,"Napalm Bomb"},
    {WEAPON_OBELISK_LASER,"Laser"},
    {WEAPON_NIKE,"SAM Missile"},
    {WEAPON_HONEST_JOHN,"Honest John Missile"},
    {WEAPON_STEG,"DinoBite 1"},
    {WEAPON_TREX,"DinoBite 2"}};
static std::vector<WPRuleEntry> rules;
static std::map<std::string,std::string> displayGroups;
static bool active = false;
static int creditFloor=0, autoHeal=0;
static void Add(const std::string& group, const char* field, int value, int low, int high, std::function<void(int)> apply, const char* label=nullptr, const char* help="", const std::vector<WPChoice>& choices={}) {
    const auto found=displayGroups.find(group);
    const std::string& display=found==displayGroups.end() ? group : found->second;
    rules.push_back({group+"/"+field, display+" / "+(label ? label : field), value,low,high,apply,choices,help});
}
static void AddType(const char* category, TechnoTypeClass& t) {
    std::string group = std::string(category)+" / "+t.IniName;
    // Keep INI identifiers in persistent keys; only presentation uses game names.
    const char* translated=SystemStrings ? Text_String(t.FullName) : nullptr;
    std::string name=translated && *translated ? translated : t.IniName;
    if ((t.IniName[0]=='C' || t.IniName[0]=='V') && std::isdigit((unsigned char)t.IniName[1]))
        name=(t.IniName[0]=='C' ? "Civilian " : "Civilian Building ")+std::to_string(std::atoi(t.IniName+1));
    displayGroups[group]=std::string(category)+" / "+name;
    Add(group,"Cost",(int)t.Cost,1,50000,[&t](int v) { t.Cost = static_cast<decltype(t.Cost)>(v); });
    Add(group,"MaxStrength",(int)t.MaxStrength,10,60000,[&t](int v) { t.MaxStrength = static_cast<decltype(t.MaxStrength)>(v); },"Health","All owners of this type are affected, including enemies.",{});
    Add(group,"SightRange",(int)t.SightRange,0,10,[&t](int v) { t.SightRange = static_cast<decltype(t.SightRange)>(v); },"Sight (cells)","All owners of this type are affected, including enemies.",{});
    Add(group,"MaxSpeed",(int)t.MaxSpeed,0,255,[&t](int v) { t.MaxSpeed = static_cast<decltype(t.MaxSpeed)>(v); },"Speed","All owners of this type are affected, including enemies.",{});
    Add(group,"MaxAmmo",(int)t.MaxAmmo,-1,255,[&t](int v) { t.MaxAmmo = static_cast<decltype(t.MaxAmmo)>(v); },"Ammo (-1 unlimited)","All owners of this type are affected, including enemies.",{});
    Add(group,"Primary",(int)t.Primary,-1,WEAPON_COUNT-1,[&t](int v) { t.Primary = static_cast<decltype(t.Primary)>(v); },"Primary weapon","All owners of this type are affected, including enemies.",weaponChoices);
    Add(group,"Secondary",(int)t.Secondary,-1,WEAPON_COUNT-1,[&t](int v) { t.Secondary = static_cast<decltype(t.Secondary)>(v); },"Secondary weapon","All owners of this type are affected, including enemies.",weaponChoices);
    Add(group,"Armor",(int)t.Armor,0,ARMOR_COUNT-1,[&t](int v) { t.Armor = static_cast<decltype(t.Armor)>(v); },"Armor","All owners of this type are affected, including enemies.",armorChoices);
    Add(group,"Scenario",(int)t.Scenario,0,99,[&t](int v) { t.Scenario = static_cast<decltype(t.Scenario)>(v); },"Campaign build level","All owners of this type are affected, including enemies.",{});
    Add(group,"Level",(int)t.Level,0,99,[&t](int v) { t.Level = static_cast<decltype(t.Level)>(v); },"Technology level","All owners of this type are affected, including enemies.",{});
    Add(group,"Pre",(int)t.Pre,0,2147483647,[&t](int v) { t.Pre = static_cast<decltype(t.Pre)>(v); },"Prerequisites (bitmask)","Advanced: a building prerequisite bitmask. Changing this does not grant ownership or campaign access.",{});
    Add(group,"Ownable",(int)t.Ownable,0,65535,[&t](int v) { t.Ownable = static_cast<decltype(t.Ownable)>(v); },"Ownership (bitmask)","Advanced: a house ownership bitmask; stock campaign restrictions may still apply.",{});
    // Apply these explicit overrides after Ownable; retain every unrelated house bit.
    Add(group,"GDIAvailability",-1,-1,1,[&t](int v){if(v>=0) t.Ownable=v ? t.Ownable|HOUSEF_GOOD : t.Ownable&~HOUSEF_GOOD;},"GDI availability","Overrides only the GDI ownership bit. Buildable, technology and prerequisites still apply.",factionChoices);
    Add(group,"NodAvailability",-1,-1,1,[&t](int v){if(v>=0) t.Ownable=v ? t.Ownable|HOUSEF_BAD : t.Ownable&~HOUSEF_BAD;},"Nod availability","Overrides only the Nod ownership bit. Other houses remain unchanged.",factionChoices);
    Add(group,"IsImmune",t.IsImmune,0,1,[&t](int v){t.IsImmune=v;},"Immune to combat damage","All owners, including enemies. Does not prevent scripted removal or selling.",toggles);
    Add(group,"IsTwoShooter",t.IsTwoShooter,0,1,[&t](int v){t.IsTwoShooter=v;},"Double-shot burst","All owners. Weapon and unit firing behavior can impose additional limits.",toggles);
    Add(group,"Buildable",t.IsBuildable,0,1,[&t](int v){t.IsBuildable=v;},"Buildable","All owners of this type are affected, including enemies.",toggles);
}
void WP_InitRules(void) {
    if (!rules.empty()) return;
    Add("Cheats", "Credit refill floor", 0, 0, 100000, [](int v){creditFloor=v;});
    Add("Cheats", "Auto heal player units (0 off, 1 on)", 0, 0, 1, [](int v){autoHeal=v;});
    for(int i=0;i<UNIT_COUNT;++i) {
        auto& t=const_cast<UnitTypeClass&>(UnitTypeClass::As_Reference((UnitType)i)); AddType("Vehicles",t);
        std::string group=std::string("Vehicles / ")+t.IniName;
        Add(group,"IsCloakable",t.IsCloakable,0,1,[&t](int v){t.IsCloakable=v;},"Cloaking","Applies to newly created vehicles of every owner. Start a new mission.",toggles);
    }
    for(int i=0;i<INFANTRY_COUNT;++i) AddType("Infantry",const_cast<InfantryTypeClass&>(InfantryTypeClass::As_Reference((InfantryType)i)));
    for(int i=0;i<AIRCRAFT_COUNT;++i) {
        auto& t=const_cast<AircraftTypeClass&>(AircraftTypeClass::As_Reference((AircraftType)i)); AddType("Aircraft",t);
        std::string group=std::string("Aircraft / ")+t.IniName;
        Add(group,"IsSelectable",t.IsSelectable,0,1,[&t](int v){t.IsSelectable=v;},"Selectable","Allows selection; does not change fixed-wing flight behavior.",toggles);
        Add(group,"IsLegalTarget",t.IsLegalTarget,0,1,[&t](int v){t.IsLegalTarget=v;},"Can be targeted","Whether commands can target this aircraft; separate from damage immunity.",toggles);
        Add(group,"IsTransporter",t.IsTransporter,0,1,[&t](int v){t.IsTransporter=v;},"Carry passengers","Enables a five-passenger capacity. Experimental on aircraft not designed to land and unload.",toggles);
        // IsLandable is stored by the constructor but never read by this engine.
        // Do not offer a toggle that promises landing behavior it cannot implement.
    }
    for(int i=0;i<STRUCT_COUNT;++i) {
        auto& t=const_cast<BuildingTypeClass&>(BuildingTypeClass::As_Reference((StructType)i)); AddType("Buildings",t);
        std::string group=std::string("Buildings / ")+t.IniName;
        Add(group,"Capacity",t.Capacity,0,100000,[&t](int v){t.Capacity=v;},"Tiberium storage","Capacity for every building of this type. Start a new mission to rebuild house totals.");
        Add(group,"Power",t.Power,0,10000,[&t](int v){t.Power=v;},"Power produced","All owners. Actual output may fall with building damage.");
        Add(group,"Drain",t.Drain,0,10000,[&t](int v){t.Drain=v;},"Power consumed","All owners. Start a new mission to rebuild house totals.");
        Add(group,"ToBuild",t.ToBuild,RTTI_NONE,RTTI_BUILDINGTYPE,[&t](int v){t.ToBuild=static_cast<RTTIType>(v);},"Factory production","Experimental: changes production category, not building exits or animations. Some combinations cannot deliver units.",factoryChoices);
    }
    for(int i=0;i<WEAPON_COUNT;++i) {
        auto& w=Weapons[i]; std::string group="Weapons / #"+std::to_string(i); // Stable preset key: keep numeric weapon groups.
        for(const auto& choice:weaponChoices) if(choice.value==i) displayGroups[group]=std::string("Weapons / ")+choice.label;
        Add(group,"Damage",w.Attack,0,255,[&w](int v){w.Attack=v;});
        Add(group,"Reload ticks",w.ROF,1,255,[&w](int v){w.ROF=v;});
        Add(group,"Range (256 per cell)",w.Range,0,8192,[&w](int v){w.Range=v;});
    }
    for(int i=0;i<(int)rules.size();++i) { auto& r=rules[i]; int v=WP_LoadRule(r.key.c_str(),r.original,r.low,r.high); if(WP_RuleValueValid(i,v) && v!=r.original) { r.apply(v); active=true; } }
}
int WP_RuleCount(void){return (int)rules.size();}
const char* WP_RuleName(int i){return i>=0&&i<WP_RuleCount()?rules[i].name.c_str():"";}
const char* WP_RuleKey(int i){return i>=0&&i<WP_RuleCount()?rules[i].key.c_str():"";}
int WP_RuleDefault(int i){return i>=0&&i<WP_RuleCount()?rules[i].original:0;}
int WP_RuleMin(int i){return i>=0&&i<WP_RuleCount()?rules[i].low:0;}
int WP_RuleMax(int i){return i>=0&&i<WP_RuleCount()?rules[i].high:0;}
int WP_RulesActive(void){return active;}
const char* WP_RuleHelp(int i){return i>=0&&i<WP_RuleCount()?rules[i].help.c_str():"";}
int WP_RuleChoiceCount(int i){return i>=0&&i<WP_RuleCount()?(int)rules[i].choices.size():0;}
int WP_RuleChoiceValue(int i,int c){return c>=0&&c<WP_RuleChoiceCount(i)?rules[i].choices[c].value:0;}
const char* WP_RuleChoiceLabel(int i,int c){return c>=0&&c<WP_RuleChoiceCount(i)?rules[i].choices[c].label:"";}
int WP_RuleValueValid(int i,int v){
    if(i<0||i>=WP_RuleCount()||v<rules[i].low||v>rules[i].high) return 0;
    if(rules[i].choices.empty()) return 1;
    for(const auto& c:rules[i].choices) if(c.value==v) return 1;
    return 0;
}

static void WP_ApplyLiveCheats();
void WP_TickCheats(void) {
    WP_ApplyLiveCheats();
    if (GameToPlay != GAME_NORMAL || !PlayerPtr) return;
    if (creditFloor && PlayerPtr->Credits < creditFloor) PlayerPtr->Credits=creditFloor;
    if (!autoHeal) return;
    for(int i=0;i<Units.Count();++i) { auto* u=Units.Ptr(i); if(u && u->House==PlayerPtr && u->Strength>0) u->Strength=u->Class->MaxStrength; }
    for(int i=0;i<Infantry.Count();++i) { auto* u=Infantry.Ptr(i); if(u && u->House==PlayerPtr && u->Strength>0) u->Strength=u->Class->MaxStrength; }
    for(int i=0;i<Aircraft.Count();++i) { auto* u=Aircraft.Ptr(i); if(u && u->House==PlayerPtr && u->Strength>0) u->Strength=u->Class->MaxStrength; }
    for(int i=0;i<Buildings.Count();++i) { auto* u=Buildings.Ptr(i); if(u && u->House==PlayerPtr && u->Strength>0) u->Strength=u->Class->MaxStrength; }
}

namespace {
WPCheats::Snapshot liveCheats;
std::vector<unsigned char> savedShroud;
bool mapRevealed=false;
template<class Pool> void RestoreSight(Pool& pool) {
    for(int i=0;i<pool.Count();++i) {auto* u=pool.Ptr(i);
        if(u&&u->House==PlayerPtr&&!u->IsInLimbo&&u->Strength>0)
            Map.Sight_From(PlayerPtr,Coord_Cell(u->Center_Coord()),u->Class->SightRange,false);
    }
}
}
void WP_ResetLiveCheats(void) {
    WPCheats::Shared().reset(); liveCheats={}; savedShroud.clear();mapRevealed=false;
}
int WP_InstantBuild(const void* house) { return !PlaybackGame && GameToPlay==GAME_NORMAL && house==PlayerPtr && liveCheats.instant; }
int WP_BuildAnywhere(const void* house) { return !PlaybackGame && GameToPlay==GAME_NORMAL && house==PlayerPtr && liveCheats.anywhere; }
int WP_ZeroCost(const void* house) { return !PlaybackGame && GameToPlay==GAME_NORMAL && house==PlayerPtr && liveCheats.free; }
int WP_PlayerInvincible(const void* house) {
    return !PlaybackGame && GameToPlay==GAME_NORMAL && house==PlayerPtr && liveCheats.invincible;
}
int WP_ScalePlayerSpeed(const void* house,int base,int category) {
    if(PlaybackGame || GameToPlay!=GAME_NORMAL || house!=PlayerPtr)return base;
    int quarters=category==0?liveCheats.infantry:category==1?liveCheats.vehicles:liveCheats.aircraft;
    return base*quarters/4;
}
static void WP_ApplyLiveCheats() {
    if(GameToPlay!=GAME_NORMAL || !PlayerPtr || PlaybackGame) return;
    liveCheats=WPCheats::Shared().snapshot();
    if(liveCheats.weapons) {
        // Let the normal house logic grant weapons and add sidebar cameos.
        if(PlayerPtr->ActiveBScan & STRUCTF_TEMPLE) PlayerPtr->NukePieces=7;
        if(PlayerPtr->IonCannon.Is_Present() && !PlayerPtr->IonCannon.Is_Ready()) {
            PlayerPtr->IonCannon.Forced_Charge(); Map.Flag_To_Redraw(true);
        }
        if(PlayerPtr->NukeStrike.Is_Present() && !PlayerPtr->NukeStrike.Is_Ready()) {
            PlayerPtr->NukeStrike.Forced_Charge(); Map.Flag_To_Redraw(true);
        }
    }
    auto actions=WPCheats::Shared().take();
    if(actions.money) PlayerPtr->Refund_Money(actions.money);
    if(actions.power) {PlayerPtr->Adjust_Power(actions.power);Map.Flag_To_Redraw(true);}
    if(liveCheats.reveal!=mapRevealed) {
        if(liveCheats.reveal) {
            savedShroud.resize(MAP_CELL_TOTAL);
            for(int i=0;i<MAP_CELL_TOTAL;++i) savedShroud[i]=(Map[i].Is_Mapped(PlayerPtr)?1:0)|(Map[i].Is_Visible(PlayerPtr)?2:0);
            for(int i=0;i<MAP_CELL_TOTAL;++i) {Map[i].Set_Mapped(PlayerPtr,true);Map[i].Set_Visible(PlayerPtr,true);Map[i].Redraw_Objects();}
        } else if(savedShroud.size()==MAP_CELL_TOTAL) {
            for(int i=0;i<MAP_CELL_TOTAL;++i) {Map[i].Set_Mapped(PlayerPtr,(savedShroud[i]&1)!=0);Map[i].Set_Visible(PlayerPtr,(savedShroud[i]&2)!=0);Map[i].Redraw_Objects();}
            // Restore the explored snapshot plus the sight of current player objects.
            RestoreSight(Units);RestoreSight(Infantry);RestoreSight(Aircraft);RestoreSight(Buildings);
            savedShroud.clear();
        }
        mapRevealed=liveCheats.reveal;Map.Flag_To_Redraw(true);
    }
    WPCheats::Shared().publish(true,PlayerPtr->Available_Money(),PlayerPtr->Power,PlayerPtr->Drain);
}
