#include "function.h"
#include "wireproof_rules.h"
#include <functional>
#include <string>
#include <vector>
#include <atomic>
#include <cctype>
#include <map>
#include <cstring>
namespace {
struct Choice { int value; std::string label; };
struct Entry { std::string key,name; int original,low,high; std::function<void(int)> set; std::vector<Choice> choices; };
std::vector<Entry> entries;
std::vector<Choice> weapons;
std::atomic<bool> active{false};
void Add(const std::string& key,const std::string& name,int value,int low,int high,std::function<void(int)> set,const std::vector<Choice>& choices={}) {
    entries.push_back({key,name,value,low,high,set,choices});
}
std::string Label(const TechnoTypeClass& t) {
    const char* label=SystemStrings ? Text_String(t.FullName) : nullptr;
    if((t.IniName[0]=='C'||t.IniName[0]=='V') && std::isdigit((unsigned char)t.IniName[1]))
        return std::string(t.IniName[0]=='C'?"Civilian ":"Civilian Building ")+std::to_string(std::atoi(t.IniName+1));
    return label && *label ? label : t.IniName;
}
void Type(const char* category,TechnoTypeClass& t) {
    const std::string key=std::string(category)+" / "+t.IniName+"/",name=std::string(category)+" / "+Label(t)+" / ";
#define FIELD(member,title,lo,hi) Add(key+#member,name+title,(int)t.member,lo,hi,[&t](int v){t.member=static_cast<decltype(t.member)>(v);})
    FIELD(Cost,"Cost",0,50000);
    FIELD(MaxStrength,"Health",1,60000);
    FIELD(SightRange,"Sight (cells)",0,10);
    if(std::strcmp(category,"Buildings")!=0) { FIELD(MaxSpeed,"Speed",0,255); }
    FIELD(MaxAmmo,"Ammo (-1 unlimited)",-1,255);
    FIELD(Level,"Technology level (-1 unavailable)",-1,99);
#undef FIELD
    const std::vector<Choice> toggles={{0,"Off"},{1,"On"}};
    Add(key+"IsSelectable",name+"Selectable",t.IsSelectable,0,1,[&t](int v){t.IsSelectable=v;},toggles);
    Add(key+"IsLegalTarget",name+"Can be targeted",t.IsLegalTarget,0,1,[&t](int v){t.IsLegalTarget=v;},toggles);
    Add(key+"IsImmune",name+"Immune to combat damage",t.IsImmune,0,1,[&t](int v){t.IsImmune=v;},toggles);
    // Only these constructors read the type's cloak flag. Aircraft do not.
    if(std::strcmp(category,"Vehicles")==0 || std::strcmp(category,"Infantry")==0 || std::strcmp(category,"Ships")==0)
        Add(key+"IsCloakable",name+"Cloaking",t.IsCloakable,0,1,[&t](int v){t.IsCloakable=v;},toggles);
    Add(key+"Armor",name+"Armor",t.Armor,0,ARMOR_COUNT-1,[&t](int v){t.Armor=(ArmorType)v;},{{ARMOR_NONE,"None"},{ARMOR_WOOD,"Wood"},{ARMOR_ALUMINUM,"Light"},{ARMOR_STEEL,"Heavy"},{ARMOR_CONCRETE,"Concrete"}});
    Add(key+"PrimaryWeapon",name+"Primary weapon",t.PrimaryWeapon?t.PrimaryWeapon->ID:-1,-1,WEAPON_COUNT-1,[&t](int v){t.PrimaryWeapon=v<0?nullptr:WeaponTypeClass::As_Pointer((WeaponType)v);},weapons);
    Add(key+"SecondaryWeapon",name+"Secondary weapon",t.SecondaryWeapon?t.SecondaryWeapon->ID:-1,-1,WEAPON_COUNT-1,[&t](int v){t.SecondaryWeapon=v<0?nullptr:WeaponTypeClass::As_Pointer((WeaponType)v);},weapons);
}
}
static std::string WeaponLabel(const char* name) {
    static const std::map<std::string,std::string> labels={
        {"Colt45","Tanya pistols"},{"ZSU-23","Anti-air cannon"},{"Vulcan","Aircraft autocannon"},
        {"Maverick","MiG missile"},{"Camera","Spy plane camera"},{"FireballLauncher","Flame turret"},
        {"Sniper","Sniper rifle"},{"ChainGun","Chain gun"},{"Pistol","Pistol"},{"M1Carbine","Rifle"},
        {"Dragon","Anti-tank rocket"},{"Hellfire","Helicopter missile"},{"Grenade","Grenade"},
        {"75mm","Light tank cannon"},{"90mm","Medium tank cannon"},{"105mm","Heavy tank cannon"},
        {"120mm","Mammoth tank cannon"},{"TurretGun","Gun turret cannon"},{"MammothTusk","Mammoth missiles"},
        {"155mm","Artillery cannon"},{"M60mg","Machine gun"},{"Napalm","Napalm bomb"},{"TeslaZap","Tesla coil"},
        {"Nike","SAM missile"},{"8Inch","Cruiser naval gun"},{"Stinger","Destroyer missile"},{"TorpTube","Submarine torpedo"},
        {"2Inch","Gunboat cannon"},{"DepthCharge","Depth charge"},{"ParaBomb","Parabomb"},{"DogJaw","Attack dog bite"},
        {"Heal","Medic healing"},{"SCUD","V2 rocket"},{"Flamer","Flamethrower"},{"RedEye","Infantry anti-air missile"},
        {"Mandible","Giant ant bite"},{"PortaTesla","Shock trooper Tesla"},{"GoodWrench","Mechanic repair"},
        {"SubSCUD","Missile submarine rocket"},{"TTankZap","Tesla tank"},{"APTusk","Mammoth anti-air missiles"},
        {"Democharge","Demolition charge"}};
    auto it=labels.find(name);return it==labels.end()?name:it->second;
}
void RA_InitRules() {
    // A combined-app engine can be entered again without unloading its image.
    // Rebind every setter to the newly initialized type heaps on each entry.
    entries.clear(); weapons.clear(); active=false;
    weapons.push_back({-1,"None"});
    for(int i=0;i<Weapons.Count() && i<WEAPON_COUNT;++i)if(auto* w=WeaponTypeClass::As_Pointer((WeaponType)i))weapons.push_back({i,WeaponLabel(w->IniName)});
    for(int i=0;i<UNIT_COUNT;++i)Type("Vehicles",UnitTypeClass::As_Reference((UnitType)i));
    for(int i=0;i<INFANTRY_COUNT;++i)Type("Infantry",InfantryTypeClass::As_Reference((InfantryType)i));
    for(int i=0;i<AIRCRAFT_COUNT;++i)Type("Aircraft",AircraftTypeClass::As_Reference((AircraftType)i));
    for(int i=0;i<VESSEL_COUNT;++i)Type("Ships",VesselTypeClass::As_Reference((VesselType)i));
    for(int i=0;i<STRUCT_COUNT;++i) {
        auto& t=BuildingTypeClass::As_Reference((StructType)i);Type("Buildings",t);
        const std::string key=std::string("Buildings / ")+t.IniName+"/",name="Buildings / "+Label(t)+" / ";
        Add(key+"Capacity",name+"Ore storage",t.Capacity,0,100000,[&t](int v){t.Capacity=v;});
        Add(key+"Power",name+"Power produced",t.Power,0,10000,[&t](int v){t.Power=v;});
        Add(key+"Drain",name+"Power consumed",t.Drain,0,10000,[&t](int v){t.Drain=v;});
    }
    for(int i=0;i<Weapons.Count() && i<WEAPON_COUNT;++i)if(auto* w=WeaponTypeClass::As_Pointer((WeaponType)i)) {
        const std::string key=std::string("Weapons / ")+w->IniName+"/",name=std::string("Weapons / ")+WeaponLabel(w->IniName)+" / ";
        Add(key+"Attack",name+"Damage (negative heals)",w->Attack,-1000,10000,[w](int v){w->Attack=v;});
        Add(key+"ROF",name+"Reload ticks",w->ROF,1,10000,[w](int v){w->ROF=v;});
        Add(key+"Range",name+"Range (256 per cell)",w->Range,0,8192,[w](int v){w->Range=v;});
        Add(key+"Burst",name+"Burst shots",w->Burst,1,16,[w](int v){w->Burst=v;});
    }
}
void RA_RestoreRules() {for(auto& r:entries)r.set(r.original);active=false;}
void RA_ApplyRules() {
    active=false;
    // Never alter network matches or replay playback. Reapply after scenario INI
    // overrides, before objects/house power totals are constructed.
    if(Session.Play || (Session.Type!=GAME_NORMAL && Session.Type!=GAME_SKIRMISH))return;
    for(int i=0;i<RA_RuleCount();++i){auto& r=entries[i];int v=RA_LoadRule(r.key.c_str(),r.original,r.low,r.high);if(RA_RuleValueValid(i,v)&&v!=r.original){r.set(v);active=true;}}
}
int RA_RulesActive(){return active;}
int RA_RuleCount(){return (int)entries.size();}
const char* RA_RuleName(int i){return i>=0&&i<RA_RuleCount()?entries[i].name.c_str():"";}
const char* RA_RuleKey(int i){return i>=0&&i<RA_RuleCount()?entries[i].key.c_str():"";}
int RA_RuleDefault(int i){return i>=0&&i<RA_RuleCount()?entries[i].original:0;}
int RA_RuleMin(int i){return i>=0&&i<RA_RuleCount()?entries[i].low:0;}
int RA_RuleMax(int i){return i>=0&&i<RA_RuleCount()?entries[i].high:0;}
int RA_RuleChoiceCount(int i){return i>=0&&i<RA_RuleCount()?(int)entries[i].choices.size():0;}
int RA_RuleChoiceValue(int i,int c){return c>=0&&c<RA_RuleChoiceCount(i)?entries[i].choices[c].value:0;}
const char* RA_RuleChoiceLabel(int i,int c){return c>=0&&c<RA_RuleChoiceCount(i)?entries[i].choices[c].label.c_str():"";}
int RA_RuleValueValid(int i,int v){if(i<0||i>=RA_RuleCount()||v<entries[i].low||v>entries[i].high)return 0;if(entries[i].choices.empty())return 1;for(auto& c:entries[i].choices)if(c.value==v)return 1;return 0;}
