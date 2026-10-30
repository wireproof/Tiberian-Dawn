#include "function.h"
#include "wireproof_production.h"
#include "common/wireproof_production_queue.h"
#include "common/wireproof_orders.h"
#include <vector>
namespace {
WPProduction::Queue queues[3];
int cancelling[3]={-1,-1,-1};
bool cancelSent[3]={false,false,false};
CELL rally[2]={0,0};
bool rallyLoaded=false;
void persistRallies(){
 if(!PlayerPtr)return;
 CCFileClass file(CONFIG_FILE_NAME);INIClass ini;ini.Load(file);
 const char* section="WireproofRally";
 ini.Put_Int(section,"Scenario",Scen.Scenario);
 ini.Put_Int(section,"House",PlayerPtr->Class->House);
 ini.Put_Int(section,"Infantry",rally[0]);
 ini.Put_Int(section,"Vehicles",rally[1]);
 ini.Save(file);
}
void restoreRallies(){
 if(rallyLoaded||!PlayerPtr)return;
 rallyLoaded=true;
 CCFileClass file(CONFIG_FILE_NAME);INIClass ini;ini.Load(file);
 const char* section="WireproofRally";
 if(ini.Get_Int(section,"Scenario",-1)!=(int)Scen.Scenario||
    ini.Get_Int(section,"House",-1)!=(int)PlayerPtr->Class->House)return;
 const char* keys[]={"Infantry","Vehicles"};
 for(int c=0;c<2;++c){int cell=ini.Get_Int(section,keys[c],0);
  if(cell>0&&cell<MAP_CELL_TOTAL&&Map.In_Radar(cell))rally[c]=cell;}
}
struct Departure{TARGET target;CELL cell;int frame;};
std::vector<Departure> departures;
int category(int type){if(type==RTTI_INFANTRYTYPE||type==RTTI_INFANTRY)return 0;if(type==RTTI_UNITTYPE||type==RTTI_UNIT)return 1;if(type==RTTI_AIRCRAFTTYPE||type==RTTI_AIRCRAFT)return 2;return -1;}
bool available(){return PlayerPtr&&!PlaybackGame;}
}
bool WP_Queue_Add(int type,int id){int c=category(type);return available()&&c>=0&&queues[c].add(id);}
bool WP_Queue_Remove(int type,int id){int c=category(type);return available()&&c>=0&&queues[c].remove(id);}
bool WP_Queue_Cancel(int type,int id,bool active){
 int c=category(type);if(!available()||c<0)return false;
 // Unstarted entries cost nothing. ABANDON refunds the active factory's actual
 // expenditure; block dispatch until that event executes, including a PRODUCE
 // already in flight when the hold arrived.
 if(active||queues[c].dispatched(id))cancelling[c]=id;
 queues[c].cancelWaiting(id);return true;
}
void WP_Queue_Cancelled(int house,int type){int c=category(type);if(PlayerPtr&&house==Houses.ID(PlayerPtr)&&c>=0){cancelling[c]=-1;cancelSent[c]=false;}}
int WP_Queue_Count(int type,int id){int c=category(type);return c>=0?queues[c].count(id):0;}
void WP_Queue_Acknowledge(int house,int type,int id){int c=category(type);if(PlayerPtr&&house==Houses.ID(PlayerPtr)&&c>=0)queues[c].acknowledge(id);}
void WP_Rally_Clear(){rally[0]=rally[1]=0;departures.clear();rallyLoaded=true;persistRallies();WPOrders::Shared().rally(0);}
void WP_Production_Reset(){for(int c=0;c<3;++c){queues[c].clear();cancelling[c]=-1;cancelSent[c]=false;}rally[0]=rally[1]=0;rallyLoaded=false;departures.clear();WPOrders::Shared().rally(0);}
void WP_Production_Tick(){
 if(!available()||!GameActive||!InMainLoop)return;
 restoreRallies();
 const int factories[]={PlayerPtr->InfantryFactory,PlayerPtr->UnitFactory,PlayerPtr->AircraftFactory};
 const RTTIType types[]={RTTI_INFANTRYTYPE,RTTI_UNITTYPE,RTTI_AIRCRAFTTYPE};
 for(int c=0;c<3;++c){
  if(cancelling[c]>=0){if(!cancelSent[c])cancelSent[c]=OutList.Add(EventClass(EventClass::ABANDON,types[c],cancelling[c]));continue;}
  int id=queues[c].next(factories[c]!=-1);if(id>=0&&!OutList.Add(EventClass(EventClass::PRODUCE,types[c],id)))queues[c].retry();
 }
 for(auto it=departures.begin();it!=departures.end();){
  TechnoClass*t=As_Techno(it->target);
  if(!t||!t->IsActive||t->House!=PlayerPtr||Frame-it->frame>TICKS_PER_SECOND*120){it=departures.erase(it);continue;}
  if(t->IsInLimbo||t->IsTethered||Frame-it->frame<15){++it;continue;}
  // Infantry still has a short exit walk and salute after untethering. A
  // movement event during that handoff can be overwritten by the exit mission.
  if(t->What_Am_I()==RTTI_INFANTRY && (((FootClass*)t)->IsDriving || Target_Legal(((FootClass*)t)->NavCom) || t->Mission==MISSION_MOVE || t->MissionQueue!=MISSION_NONE)){++it;continue;}
  if(OutList.Add(EventClass(it->target,MISSION_MOVE,TARGET_NONE,::As_Target(it->cell))))it=departures.erase(it);else ++it;
 }
}
void WP_Rally_Forget(TechnoClass*unit){if(!unit)return;for(auto i=departures.begin();i!=departures.end();)if(i->target==unit->As_Target())i=departures.erase(i);else ++i;}
void WP_Rally_New(TechnoClass*unit){
 if(!available()||!unit||unit->House!=PlayerPtr)return;
 int c=category(unit->What_Am_I());if(c<0||c>1||!rally[c])return;
 if(c==1&&((UnitClass*)unit)->Class->Type==UNIT_HARVESTER)return;
 if(departures.size()<128)departures.push_back({unit->As_Target(),rally[c],Frame});
}
bool WP_Rally_Click(int cell,bool ground){
 int mode=WPOrders::Shared().snapshot().rally;
 if(!mode && ground && CurrentObject.Count()==1 && CurrentObject[0]->What_Am_I()==RTTI_BUILDING){
  BuildingClass*b=(BuildingClass*)CurrentObject[0];
  if(b->House==PlayerPtr){if(b->Class->Type==STRUCT_BARRACKS||b->Class->Type==STRUCT_HAND)mode=1;else if(b->Class->Type==STRUCT_WEAP||b->Class->Type==STRUCT_AIRSTRIP)mode=2;}
 }
 if(!mode)return false;
 if(available()&&cell>0&&cell<MAP_CELL_TOTAL&&Map.In_Radar(cell)&&Map[cell].Is_Visible(PlayerPtr)){
  restoreRallies();rally[mode-1]=cell;persistRallies();WPOrders::Shared().rally(0);Map.Flag_To_Redraw(true);
  OutList.Add(EventClass(ANIM_MOVE_FLASH,PlayerPtr->Class->House,Cell_Coord(cell)));
 }
 return true;
}
