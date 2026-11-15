#include "function.h"
#include "wireproof_production.h"
#include "common/wireproof_orders.h"
#include "common/wireproof_production_queue.h"
#include <vector>
#include <cstring>
namespace {
WPProduction::Queue queues[4];
int cancelling[4]={-1,-1,-1,-1};
bool cancellationSent[4]={};
CELL rallies[2]={};bool restored=false;
struct Departure {TargetClass target;CELL cell;int frame;};
std::vector<Departure> departures;
int Category(int type) {
    if(type==RTTI_INFANTRYTYPE || type==RTTI_INFANTRY)return 0;
    if(type==RTTI_UNITTYPE || type==RTTI_UNIT)return 1;
    if(type==RTTI_AIRCRAFTTYPE || type==RTTI_AIRCRAFT)return 2;
    if(type==RTTI_VESSELTYPE || type==RTTI_VESSEL)return 3;
    return -1;
}
bool Available() {return PlayerPtr && !Session.Play;}
void SaveRallies() {
    if(!PlayerPtr)return;
    CCFileClass file(CONFIG_FILE_NAME);INIClass ini;ini.Load(file);
    ini.Put_String("WireproofRARally","Scenario",Scen.ScenarioName);
    ini.Put_Int("WireproofRARally","House",PlayerPtr->Class->House);
    ini.Put_Int("WireproofRARally","Infantry",rallies[0]);
    ini.Put_Int("WireproofRARally","Vehicles",rallies[1]);ini.Save(file);
}
void RestoreRallies() {
    if(restored || !PlayerPtr)return;restored=true;
    CCFileClass file(CONFIG_FILE_NAME);INIClass ini;ini.Load(file);char scenario[256]={};
    ini.Get_String("WireproofRARally","Scenario","",scenario,sizeof(scenario));
    if(std::strcmp(scenario,Scen.ScenarioName)!=0 || ini.Get_Int("WireproofRARally","House",-1)!=PlayerPtr->Class->House)return;
    const char* keys[]={"Infantry","Vehicles"};
    for(int i=0;i<2;++i){int cell=ini.Get_Int("WireproofRARally",keys[i],0);if(cell>0 && cell<MAP_CELL_TOTAL && Map.In_Radar((CELL)cell))rallies[i]=(CELL)cell;}
}
}
bool RA_QueueAdd(int type,int id){int c=Category(type);return Available() && c>=0 && queues[c].add(id);}
int RA_QueueCount(int type,int id){int c=Category(type);return c>=0?queues[c].count(id):0;}
void RA_QueueCancel(int type,int id,bool active){
    int c=Category(type);if(!Available() || c<0)return;
    if(active || queues[c].dispatched(id))cancelling[c]=id;
    queues[c].cancelWaiting(id);
}
void RA_QueueAcknowledge(int house,int type,int id){int c=Category(type);if(PlayerPtr && house==Houses.ID(PlayerPtr) && c>=0)queues[c].acknowledge(id);}
void RA_QueueCancelled(int house,int type){int c=Category(type);if(PlayerPtr && house==Houses.ID(PlayerPtr) && c>=0){cancelling[c]=-1;cancellationSent[c]=false;}}
void RA_ClearRallies(){rallies[0]=rallies[1]=0;departures.clear();restored=true;SaveRallies();WPOrders::Shared().rally(0);}
void RA_ResetProduction(){for(int i=0;i<4;++i){queues[i].clear();cancelling[i]=-1;cancellationSent[i]=false;}rallies[0]=rallies[1]=0;departures.clear();restored=false;}
void RA_ProductionTick(){
    if(!Available() || !GameActive)return;RestoreRallies();
    int factories[]={PlayerPtr->InfantryFactory,PlayerPtr->UnitFactory,PlayerPtr->AircraftFactory,PlayerPtr->VesselFactory};
    RTTIType types[]={RTTI_INFANTRYTYPE,RTTI_UNITTYPE,RTTI_AIRCRAFTTYPE,RTTI_VESSELTYPE};
    for(int c=0;c<4;++c){
        if(cancelling[c]>=0){if(!cancellationSent[c])cancellationSent[c]=OutList.Add(EventClass(EventClass::ABANDON,types[c],cancelling[c]));continue;}
        int id=queues[c].next(factories[c]!=-1);
        if(id>=0 && !OutList.Add(EventClass(EventClass::PRODUCE,types[c],id)))queues[c].retry();
    }
    for(auto it=departures.begin();it!=departures.end();){
        auto* unit=it->target.As_Techno();
        if(!unit || !unit->IsActive || (HouseClass*)unit->House!=PlayerPtr || Frame-it->frame>TICKS_PER_SECOND*120){it=departures.erase(it);continue;}
        if(unit->IsInLimbo || unit->IsTethered || Frame-it->frame<15){++it;continue;}
        if(unit->What_Am_I()==RTTI_INFANTRY && (((FootClass*)unit)->IsDriving || TargetClass(((FootClass*)unit)->NavCom).Is_Valid() || unit->Mission==MISSION_MOVE || unit->MissionQueue!=MISSION_NONE)){++it;continue;}
        if(OutList.Add(EventClass(it->target,MISSION_MOVE,TARGET_NONE,TargetClass(it->cell))))it=departures.erase(it);else ++it;
    }
}
void RA_RallyNew(TechnoClass* unit){
    if(!Available() || !unit || (HouseClass*)unit->House!=PlayerPtr)return;
    RestoreRallies();int c=Category(unit->What_Am_I());
    if(c<0 || c>1 || !rallies[c])return;
    if(c==1 && ((UnitClass*)unit)->Class->Type==UNIT_HARVESTER)return;
    if(departures.size()<128)departures.push_back({TargetClass(unit),rallies[c],Frame});
}
bool RA_RallyClick(int cell){
    int mode=WPOrders::Shared().snapshot().rally;if(!mode)return false;
    if(Available() && cell>0 && cell<MAP_CELL_TOTAL && Map.In_Radar((CELL)cell) && Map[(CELL)cell].Is_Visible(PlayerPtr)){
        RestoreRallies();rallies[mode-1]=(CELL)cell;SaveRallies();WPOrders::Shared().rally(0);Map.Flag_To_Redraw(true);
    }return true;
}

void RA_RallyForget(TechnoClass* unit) {
    if(!unit)return;
    const auto target=TargetClass(unit).As_Target();
    for(auto it=departures.begin();it!=departures.end();)
        if(it->target.As_Target()==target)it=departures.erase(it);else ++it;
}
