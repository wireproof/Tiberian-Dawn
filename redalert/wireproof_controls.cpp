// Native UI communicates only through snapshots and queued intentions. All
// simulation access stays on the engine thread and uses RA's event protocol.
#include "function.h"
#include "wireproof_controls.h"
#include "wireproof_production.h"
#ifdef IPADOS_PORT
#include "common/ipados_touch.h"
#include "common/wireproof_laptop.h"
void RA_SaveDeckPreferences(bool,bool);
void RA_EnsureCommandDeck();
#endif
#include "common/wireproof_orders.h"
#include "common/wireproof_cheats.h"
#include "common/settings.h"
#include <algorithm>
#include <vector>
#include <cmath>
#include <atomic>
#include <cstring>
#include "common/video.h"
void Keyboard_Process(KeyNumType& input);

namespace {
bool SinglePlayer() { return PlayerPtr && !Session.Play &&
    (Session.Type==GAME_NORMAL || Session.Type==GAME_SKIRMISH); }
WPCheats::Snapshot cheats;
std::vector<unsigned char> shroud;
bool revealed=false;
float oldZoom=0;int oldRight=0;
std::atomic<bool> optionsRequested{false};
const char* SpecialName(int id) {
    static const char* names[]={"Sonar Pulse","Nuclear Missile","Chronosphere","Parabombs",
        "Paratroopers","Spy Plane","Iron Curtain","GPS Satellite"};
    return id>=0 && id<SPC_COUNT?names[id]:"Special weapon";
}
template<class Pool> void RestoreSight(Pool& pool) {
    for(int i=0;i<pool.Count();++i){auto* unit=pool.Ptr(i);
        if(unit && (HouseClass*)unit->House==PlayerPtr && !unit->IsInLimbo && unit->Strength>0)
            Map.Sight_From(Coord_Cell(unit->Center_Coord()),unit->Class->SightRange,PlayerPtr,false);
    }
}
const char* SpecialAsset(int id) {
    static const char* assets[]={"SW_SONARPULSE","SW_NUKE","SW_CHRONO","SW_PARABOMB","SW_PARAINFANTRY","SW_SPYMISSION","SW_IRONCURTAIN","SW_GPS"};
    return id>=0 && id<SPC_COUNT?assets[id]:"";
}
void TickCheats() {
    if(!SinglePlayer()) { cheats={}; WPCheats::Shared().publish(false,0,0,0); return; }
    bool wasUnlocked=cheats.unlock,wasHealth=cheats.damagedHealth;
    cheats=WPCheats::Shared().snapshot();
    if(wasUnlocked!=cheats.unlock)PlayerPtr->IsRecalcNeeded=true;
    if(wasHealth!=cheats.damagedHealth)Map.Flag_To_Redraw(true);
    auto actions=WPCheats::Shared().take();
    if(actions.money)PlayerPtr->Refund_Money(actions.money);
    if(actions.power)PlayerPtr->Adjust_Power(actions.power);
    if(cheats.weapons)for(int i=0;i<SPC_COUNT;++i)
        if(PlayerPtr->SuperWeapon[i].Is_Present() && !PlayerPtr->SuperWeapon[i].Is_Ready())
            PlayerPtr->SuperWeapon[i].Forced_Charge();
    if(cheats.reveal!=revealed) {
        if(cheats.reveal) {
            shroud.resize(MAP_CELL_TOTAL);
            for(int i=0;i<MAP_CELL_TOTAL;++i) {
                shroud[i]=(Map[(CELL)i].Is_Mapped(PlayerPtr)?1:0)|(Map[(CELL)i].Is_Visible(PlayerPtr)?2:0);
                Map[(CELL)i].Set_Mapped(PlayerPtr);Map[(CELL)i].Set_Visible(PlayerPtr);
            }
        } else if(shroud.size()==MAP_CELL_TOTAL) {
            for(int i=0;i<MAP_CELL_TOTAL;++i) {
                Map[(CELL)i].Set_Mapped(PlayerPtr,(shroud[i]&1)!=0);
                Map[(CELL)i].Set_Visible(PlayerPtr,(shroud[i]&2)!=0);
            }
            RestoreSight(Units);RestoreSight(Infantry);RestoreSight(Aircraft);RestoreSight(Vessels);RestoreSight(Buildings);
            shroud.clear();
        }
        revealed=cheats.reveal;Map.Flag_To_Redraw(true);
    }
}
}
void RA_RequestOptions() { optionsRequested.store(true); }
bool RA_BuildAnywhere(const void* house) {return SinglePlayer() && house==PlayerPtr && cheats.anywhere;}
bool RA_UnlockBuildType(const void* house,const char* name) {
    if(!SinglePlayer() || house!=PlayerPtr || !cheats.unlock || !name)return false;
    // Explicit playable military roster. Never unlock civilians, dinosaurs,
    // ants, map props or delivery-only aircraft merely because rules changed.
    static const char* roster[]={"1TNK","2TNK","3TNK","4TNK","V2RL","APC","MNLY","JEEP","HARV","MCV","ARTY","MRJ","MGG","TTNK","CTNK","QTNK","DTRK","STNK",
        "E1","E2","E3","E4","E6","E7","SPY","THF","MEDI","DOG","SHOK","MECH","MIG","YAK","HELI","HIND","TRAN","SS","DD","CA","PT","LST","MSUB",
        "FACT","POWR","APWR","PROC","SILO","DOME","BARR","TENT","KENN","WEAP","SYRD","SPEN","HPAD","AFLD","FIX","ATEK","STEK","MSLO","IRON","PDOX","SAM","AGUN","GUN","FTUR","TSLA","GAP","PBOX","HBOX","SBAG","FENC","BRIK"};
    for(const char* item:roster)if(std::strcmp(name,item)==0)return true;
    return false;
}
int RA_ScaleSpeed(const void* house,int base,int category) {
    if(!SinglePlayer() || house!=PlayerPtr)return base;
    int quarters=category==0?cheats.infantry:category==1?cheats.vehicles:cheats.aircraft;
    return std::min(int(MPH_LIGHT_SPEED),base*quarters/4);
}
bool RA_PlayerInvincible(const void* house) { return SinglePlayer() && house==PlayerPtr && cheats.invincible; }
bool RA_FreeProduction(const void* house) { return SinglePlayer() && house==PlayerPtr && cheats.free; }
bool RA_InstantProduction(const void* house) { return SinglePlayer() && house==PlayerPtr && cheats.instant; }
void RA_ResetControls() {
    WPOrders::Shared().publish(false,0);WPCheats::Shared().reset();cheats={};shroud.clear();revealed=false;optionsRequested.store(false);RA_ResetProduction();oldZoom=0;oldRight=0;
}
void RA_BeginPresentation() {
    // Scoreboards, campaign maps and movies must never inherit tactical crop,
    // force commands or native overlays. Keep production/rallies and reusable
    // cheat choices intact for movies that return to the current mission.
    WPOrders::Shared().publish(false,0);WPCheats::Shared().publish(false,0,0,0);
    Video_Set_Battlefield(false,0,0,SeenBuff.Get_Width(),SeenBuff.Get_Height(),1.f);
    Video_Set_HD_World_Artwork_Visible(false);Video_Clear_HD_Artwork();
    oldZoom=0;oldRight=0;
}
void RA_ProcessControls() {
#ifdef IPADOS_PORT
    static bool installed=false;if(!installed){RA_EnsureCommandDeck();installed=true;}
#endif
    using namespace WPOrders;
    const bool active=GameActive && GameInFocus && SpecialDialog==SDLG_NONE && !Session.Play;
    Shared().publish(active,CurrentObject.Count());
    Shared().publishArtwork(Settings.Video.ArtworkMode!=0);
    Shared().publishMapState(Map.PendingObjectPtr!=nullptr,Map.IsSidebarActive);
    WPCheats::Shared().publish(active && SinglePlayer(),PlayerPtr?PlayerPtr->Available_Money():0,
        PlayerPtr?PlayerPtr->Power:0,PlayerPtr?PlayerPtr->Drain:0);
    if(!active || !PlayerPtr)return;
    Video_Set_HD_World_Artwork_Visible(true);
    // RA's tactical dimensions are cell counts (unlike TD's pixel API).
    // Keep the legacy backing buffer; zoom in through shared SDL composition.
#ifdef IPADOS_PORT
    static bool wasDock=false,sidebarBeforeDock=false;
    const bool dock=WPLaptop::Active();
    if(dock && !wasDock){sidebarBeforeDock=Map.IsSidebarActive;Map.SidebarClass::Activate(0);}
    else if(!dock && wasDock)Map.SidebarClass::Activate(sidebarBeforeDock?1:0);
    else if(dock && Map.IsSidebarActive)Map.SidebarClass::Activate(0);
    if(dock!=wasDock){Refresh_Video_Layout();oldZoom=0;}wasDock=dock;
#endif
    const int right=SeenBuff.Get_Width()-(Map.IsSidebarActive?SidebarClass::SIDE_WIDTH*RESFACTOR:0);
    const int top=8*RESFACTOR;
    Shared().setZoomQuarters(std::max(4,Shared().zoomQuarters()));
    const float zoom=Shared().zoomQuarters()/4.f;
    Video_Set_Battlefield(true,right,top,SeenBuff.Get_Width(),SeenBuff.Get_Height(),zoom);

    if(zoom!=oldZoom || oldRight!=right) {
        int cx=Coord_X(Map.TacticalCoord)+Map.TacLeptonWidth/2;
        int cy=Coord_Y(Map.TacticalCoord)+Map.TacLeptonHeight/2;
        Map.Set_View_Dimensions(0,top,int(std::ceil(right/zoom/CELL_PIXEL_W)),
            int(std::ceil((SeenBuff.Get_Height()-top)/zoom/CELL_PIXEL_H)));
        Map.Set_Tactical_Position(XY_Coord(std::max(0,cx-Map.TacLeptonWidth/2),std::max(0,cy-Map.TacLeptonHeight/2)));
        oldZoom=zoom;oldRight=right;Map.Flag_To_Redraw(true);
    }
#ifdef IPADOS_PORT
    float panX=0,panY=0;
    if(Consume_IPadOS_Touch_Pan(panX,panY)) {
        int width,height;Video_Presentation_Size(width,height);
        float speed=Settings.Touch.ScrollSpeed==0?.7f:Settings.Touch.ScrollSpeed==2?1.4f:1.f;
        int dx=-int(std::round(panX*width*speed/zoom)),dy=-int(std::round(panY*height*speed/zoom));
        if(dx || dy) {int distance=Pixel_To_Lepton(int(std::round(std::sqrt(double(dx)*dx+double(dy)*dy))));
            Map.Scroll_Map((DirType)Desired_Facing256(0,0,dx,dy),distance,true);Map.Flag_To_Redraw(true);}
    }
#endif
    RA_ProductionTick();
    TickCheats();
    if(optionsRequested.exchange(false)){SpecialDialog=SDLG_OPTIONS;Shared().publish(false,0);return;}
    std::vector<Production> production;
    for(int c=0;c<SidebarClass::COLUMNS;++c) {
        const auto& strip=Map.Column[c];
        for(int i=0;i<strip.BuildableCount;++i) {
            const auto& item=strip.Buildables[i];
            if(item.BuildableType==RTTI_SPECIAL) {
                const int id=item.BuildableID;
                if(id>=0 && id<SPC_COUNT)production.emplace_back(int(RTTI_SPECIAL),id,SpecialName(id),SpecialAsset(id),0,3,0,PlayerPtr->SuperWeapon[id].Is_Ready());
                continue;
            }
            auto* type=Fetch_Techno_Type(item.BuildableType,item.BuildableID);
            if(!type)continue;
            auto* factory=item.Factory==-1?nullptr:Factories.Raw_Ptr(item.Factory);
            const char* name=Text_String(type->Full_Name());
            production.emplace_back(int(item.BuildableType),item.BuildableID,name?name:type->IniName,type->IniName,
                (factory?1:0)+RA_QueueCount(item.BuildableType,item.BuildableID),item.BuildableType==RTTI_BUILDINGTYPE?0:item.BuildableType==RTTI_INFANTRYTYPE?1:2,
                factory?factory->Completion():0,factory && factory->Has_Completed(),factory && !factory->Is_Building() && !factory->Has_Completed());
        }
    }
    Shared().publishProduction(std::move(production));
    static unsigned radarTick=0;
    if((++radarTick%8)==0) {
        Radar radar;radar.existing=Map.Is_Radar_Existing();radar.active=Map.Is_Radar_Active();
        radar.width=Map.MapCellWidth;radar.height=Map.MapCellHeight;radar.mapX=Map.MapCellX;radar.mapY=Map.MapCellY;
        const int camera=Coord_Cell(Map.TacticalCoord);
        radar.cameraX=Cell_X(camera)-radar.mapX;radar.cameraY=Cell_Y(camera)-radar.mapY;
        radar.cameraWidth=Lepton_To_Cell(Map.TacLeptonWidth);radar.cameraHeight=Lepton_To_Cell(Map.TacLeptonHeight);
        if(radar.active && radar.width>0 && radar.height>0 && radar.width<=256 && radar.height<=256) {
            radar.rgba.resize(size_t(radar.width)*radar.height*4);
            const unsigned char* palette=(const unsigned char*)GamePalette.Get_Data();
            for(int y=0;y<radar.height;++y)for(int x=0;x<radar.width;++x) {
                const auto& cell=Map[XY_Cell(x+radar.mapX,y+radar.mapY)];
                int color=cell.Is_Visible(PlayerPtr)?cell.Cell_Color(true):BLACK;
                if(color==TBLACK)color=cell.Cell_Color(false);
                color=std::max(0,std::min(color,255));
                auto* pixel=&radar.rgba[(size_t(y)*radar.width+x)*4];
                pixel[0]=palette[color*3]<<2;pixel[1]=palette[color*3+1]<<2;pixel[2]=palette[color*3+2]<<2;pixel[3]=255;
            }
        }
        Shared().publishRadar(std::move(radar));
    }
    Command cmd;
    while(Shared().take(cmd)) {
#ifdef IPADOS_PORT
        if(cmd.kind==ToggleLaptop || cmd.kind==TogglePortraitDeck){
            if(cmd.kind==ToggleLaptop)WPLaptop::SetEnabled(!WPLaptop::Enabled().load());
            else WPLaptop::SetAlwaysPortrait(!WPLaptop::AlwaysPortrait().load());
            RA_SaveDeckPreferences(WPLaptop::Enabled().load(),WPLaptop::AlwaysPortrait().load());
            Refresh_Video_Layout();Map.Flag_To_Redraw(true);continue;
        }
#endif
        if(cmd.kind==ToggleArtwork) {Settings.Video.ArtworkMode=!Settings.Video.ArtworkMode;Map.Flag_To_Redraw(true);continue;}
        if(cmd.kind==Attack || cmd.kind==Move) {Shared().force(cmd.kind==Attack?1:2);continue;}
        if(cmd.kind==Cancel) {Shared().force(0);Shared().rally(0);Map.Cancel_Player_Action();continue;}
        if(cmd.kind==RallyInfantry || cmd.kind==RallyVehicles){Map.Cancel_Player_Action();Shared().rally(cmd.kind==RallyInfantry?1:2);continue;}
        if(cmd.kind==ClearRallies){RA_ClearRallies();continue;}
        if(cmd.kind==RadarCenter) {
            int x=std::max(Map.MapCellX,std::min(cmd.itemType,Map.MapCellX+Map.MapCellWidth-1));
            int y=std::max(Map.MapCellY,std::min(cmd.itemID,Map.MapCellY+Map.MapCellHeight-1));
            Map.Set_Tactical_Position(Cell_Coord(XY_Cell(std::max(Map.MapCellX,x-Lepton_To_Cell(Map.TacLeptonWidth)/2),std::max(Map.MapCellY,y-Lepton_To_Cell(Map.TacLeptonHeight)/2))));
            Map.Flag_To_Redraw(true);continue;
        }
        if(cmd.kind==UseSpecial || cmd.kind==BuildItem || cmd.kind==QueueUnit || cmd.kind==CancelBuildItem || cmd.kind==CancelUnit) {
            for(int c=0;c<SidebarClass::COLUMNS;++c)for(int i=0;i<Map.Column[c].BuildableCount;++i) {
                const auto& item=Map.Column[c].Buildables[i];
                if(item.BuildableID!=cmd.itemID || (cmd.kind==UseSpecial?item.BuildableType!=RTTI_SPECIAL:int(item.BuildableType)!=cmd.itemType))continue;
                if(cmd.kind==UseSpecial) {
                    if(cmd.itemID<0 || cmd.itemID>=SPC_COUNT)continue;
                    auto& weapon=PlayerPtr->SuperWeapon[cmd.itemID];
                    if(weapon.Is_Ready()) {
                        if(cmd.itemID==SPC_SONAR_PULSE)OutList.Add(EventClass(EventClass::SPECIAL_PLACE,SPC_SONAR_PULSE,0));
                        else {Map.IsTargettingMode=(SpecialWeaponType)cmd.itemID;Unselect_All();Speak(VOX_SELECT_TARGET);}
                    } else weapon.Impatient_Click();
                    continue;
                }
                auto* factory=item.Factory==-1?nullptr:Factories.Raw_Ptr(item.Factory);
                if(cmd.kind==QueueUnit) {
                    if(factory && !factory->Is_Building() && !factory->Has_Completed())
                        OutList.Add(EventClass(EventClass::PRODUCE,item.BuildableType,item.BuildableID));
                    else RA_QueueAdd(item.BuildableType,item.BuildableID);
                    continue;
                }
                if(cmd.kind==CancelUnit) {RA_QueueCancel(item.BuildableType,item.BuildableID,factory!=nullptr);continue;}
                if(cmd.kind==CancelBuildItem) {
                    if(factory) {if(Map.PendingObjectPtr)Map.Cancel_Player_Action();OutList.Add(EventClass(factory->Is_Building()?EventClass::SUSPEND:EventClass::ABANDON,item.BuildableType,item.BuildableID));}
                } else if(factory && factory->Has_Completed()) {
                    auto* pending=factory->Get_Object();
                    if(pending && pending->What_Am_I()==RTTI_BUILDING) {
                        auto* builder=pending->Who_Can_Build_Me(false,false);
                        if(builder) {PlayerPtr->Manual_Place(builder,(BuildingClass*)pending);Shared().armBuildingPlacement();}
                    }
                } else if((!factory || !factory->Is_Building()) && !PlayerPtr->Is_Hack_Prevented(item.BuildableType,item.BuildableID))
                    OutList.Add(EventClass(EventClass::PRODUCE,item.BuildableType,item.BuildableID));
            }
            continue;
        }
        if(cmd.kind==Recall || cmd.kind==Assign || cmd.kind==Add || cmd.kind==Center) {
            if(cmd.kind==Recall || cmd.kind==Center)Unselect_All();
            Handle_Team(cmd.group,cmd.kind==Assign?2:1);
            if(cmd.kind==Center){Map.Center_Map();Map.Flag_To_Redraw(true);}
            continue;
        }
        if(cmd.kind==Stop || cmd.kind==Guard || cmd.kind==Scatter) {
            KeyNumType key=cmd.kind==Stop?Options.KeyStop:cmd.kind==Guard?Options.KeyGuard:Options.KeyScatter;
            Keyboard_Process(key);
        }
    }
}
