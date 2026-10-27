#include "function.h"
#include "wireproof_production.h"
#include "common/wireproof_production_queue.h"
#include "common/wireproof_orders.h"
#include <vector>
namespace {
WPProduction::Queue queues[3];
CELL rally[2]={0,0};
struct Departure{TARGET target;CELL cell;int frame;};
std::vector<Departure> departures;
int category(int type){if(type==RTTI_INFANTRYTYPE||type==RTTI_INFANTRY)return 0;if(type==RTTI_UNITTYPE||type==RTTI_UNIT)return 1;if(type==RTTI_AIRCRAFTTYPE||type==RTTI_AIRCRAFT)return 2;return -1;}
bool available(){return PlayerPtr&&!PlaybackGame;}
}
bool WP_Queue_Add(int type,int id){int c=category(type);return available()&&c>=0&&queues[c].add(id);}
bool WP_Queue_Remove(int type,int id){int c=category(type);return available()&&c>=0&&queues[c].remove(id);}
int WP_Queue_Count(int type,int id){int c=category(type);return c>=0?queues[c].count(id):0;}
void WP_Queue_Acknowledge(int house,int type,int id){int c=category(type);if(PlayerPtr&&house==Houses.ID(PlayerPtr)&&c>=0)queues[c].acknowledge(id);}
void WP_Rally_Clear(){rally[0]=rally[1]=0;departures.clear();WPOrders::Shared().rally(0);}
void WP_Production_Reset(){for(auto&q:queues)q.clear();WP_Rally_Clear();}
void WP_Production_Tick(){
 if(!available()||!GameActive||!InMainLoop)return;
 const int factories[]={PlayerPtr->InfantryFactory,PlayerPtr->UnitFactory,PlayerPtr->AircraftFactory};
 const RTTIType types[]={RTTI_INFANTRYTYPE,RTTI_UNITTYPE,RTTI_AIRCRAFTTYPE};
 for(int c=0;c<3;++c){int id=queues[c].next(factories[c]!=-1);if(id>=0&&!OutList.Add(EventClass(EventClass::PRODUCE,types[c],id)))queues[c].retry();}
 for(auto it=departures.begin();it!=departures.end();){
  TechnoClass*t=As_Techno(it->target);
  if(!t||!t->IsActive||t->House!=PlayerPtr||Frame-it->frame>TICKS_PER_SECOND*120){it=departures.erase(it);continue;}
  if(t->IsInLimbo||t->IsTethered||Frame-it->frame<15){++it;continue;}
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
  rally[mode-1]=cell;WPOrders::Shared().rally(0);Map.Flag_To_Redraw(true);
  OutList.Add(EventClass(ANIM_MOVE_FLASH,PlayerPtr->Class->House,Cell_Coord(cell)));
 }
 return true;
}
