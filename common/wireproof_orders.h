#include <algorithm>
#ifndef WIREPROOF_ORDERS_H
#define WIREPROOF_ORDERS_H
#include <mutex>
#include <deque>
#include <cmath>
#include <string>
#include <vector>
#include <cstdint>
namespace WPOrders {
#ifdef MACOS_PORT
int LoadUIScale();
#endif
enum Kind { Stop, Guard, Scatter, Attack, Move, Cancel, Recall, Assign, Add, Center, RallyInfantry, RallyVehicles, ClearRallies, QueueUnit, CancelUnit, BuildItem, CancelBuildItem, ToggleArtwork, ToggleLaptop, UseSpecial, RadarCenter, TogglePortraitDeck };
struct Stick { float x=0, y=0, intensity=0; };
struct Command {
    Kind kind; int group; int itemType; int itemID;
    Command() : kind(Cancel),group(0),itemType(0),itemID(0) {}
    Command(Kind command,int selectedGroup,int type=0,int id=0)
        : kind(command),group(selectedGroup),itemType(type),itemID(id) {}
};
struct Production {
    int type; int id; std::string name, asset; int queued, category, progress; bool ready, paused;
    Production(int itemType,int itemID,const std::string& itemName,const std::string& assetName,int count,int group,
               int completion=0,bool completed=false,bool held=false)
        : type(itemType),id(itemID),name(itemName),asset(assetName),queued(count),category(group),
          progress(completion),ready(completed),paused(held) {}
};
struct Snapshot { bool active; int selected; int force; int rally; bool remastered, placing, sidebar;
    Snapshot(bool a=false,int s=0,int f=0):active(a),selected(s),force(f),rally(0),remastered(false),placing(false),sidebar(false){} };
struct Radar {
    int width=0,height=0,mapX=0,mapY=0,cameraX=0,cameraY=0,cameraWidth=0,cameraHeight=0;
    bool existing=false,active=false;
    std::vector<uint8_t> rgba;
};
// UI threads only enqueue intentions. The game thread owns all game objects.
class State {
    std::mutex mutex;
    std::deque<Command> pending;
    std::vector<Production> production;
    Radar radar;
    Snapshot state = {false,0,0};
    bool pan_held = false;
    bool map_drag = false;
    bool placement_armed = false;
    Stick joystick;
    int zoom_quarters = 6;
    int ui_scale = 100;
    int joystick_size = 4, joystick_speed = 4;
public:
#ifdef MACOS_PORT
    State() { ui_scale=std::max(75,std::min(150,LoadUIScale())); }
#endif
    int uiScale() { std::lock_guard<std::mutex> lock(mutex);return ui_scale; }
    void setUIScale(int value) { std::lock_guard<std::mutex> lock(mutex);ui_scale=std::max(75,std::min(150,value)); }
    void publish(bool active, int selected) {
        std::lock_guard<std::mutex> lock(mutex);
        state.active=active; state.selected=selected;
        if (!active) { pending.clear(); production.clear(); radar=Radar(); state.force=0; state.rally=0; state.placing=false; placement_armed=false; pan_held=false; joystick={}; }
        if (!selected) state.force=0;
    }
    void setZoomQuarters(int value) { std::lock_guard<std::mutex> lock(mutex); zoom_quarters=value<2?2:value>12?12:value; }
    int zoomQuarters() { std::lock_guard<std::mutex> lock(mutex); return zoom_quarters; }
    void stepZoom(int delta) { std::lock_guard<std::mutex> lock(mutex); int value=zoom_quarters+delta; zoom_quarters=value<2?2:value>12?12:value; }
    int joystickSetting(bool speed) { std::lock_guard<std::mutex> lock(mutex); return speed?joystick_speed:joystick_size; }
    void setJoystickSetting(bool speed,int value) { std::lock_guard<std::mutex> lock(mutex); (speed?joystick_speed:joystick_size)=std::max(speed?1:2,std::min(speed?12:8,value)); }
    void hold_pan(bool held) { std::lock_guard<std::mutex> lock(mutex); pan_held=held && state.active; }
    void setMapDrag(bool value) { std::lock_guard<std::mutex> lock(mutex);map_drag=value && state.active;joystick={}; }
    bool mapDrag() { std::lock_guard<std::mutex> lock(mutex);return map_drag && state.active && !state.placing; }
    bool panHeld() { std::lock_guard<std::mutex> lock(mutex); return pan_held; }
    void setStick(float x,float y) {
        std::lock_guard<std::mutex> lock(mutex);
        joystick={};
        if(!state.active || !std::isfinite(x) || !std::isfinite(y))return;
        const float length=std::sqrt(x*x+y*y);
        if(length<=0.12f || !std::isfinite(length))return;
        joystick.x=x/length;joystick.y=y/length;
        joystick.intensity=(std::fmin(length,1.0f)-0.12f)/0.88f;
    }
    Stick stick() { std::lock_guard<std::mutex> lock(mutex); return joystick; }
    Snapshot snapshot() { std::lock_guard<std::mutex> lock(mutex); return state; }
    void publishArtwork(bool remastered) { std::lock_guard<std::mutex> lock(mutex); state.remastered=remastered; }
    void armBuildingPlacement() { std::lock_guard<std::mutex> lock(mutex);placement_armed=true; }
    void publishMapState(bool placing,bool sidebar) {
        std::lock_guard<std::mutex> lock(mutex);
        if(!placing)placement_armed=false;
        state.placing=placing && placement_armed;
        state.sidebar=sidebar;
    }
    void publishProduction(std::vector<Production> value) {
        std::lock_guard<std::mutex> lock(mutex); production=std::move(value);
    }
    std::vector<Production> productionSnapshot() {
        std::lock_guard<std::mutex> lock(mutex); return production;
    }
    void publishRadar(Radar value) { std::lock_guard<std::mutex> lock(mutex);radar=std::move(value); }
    Radar radarSnapshot() { std::lock_guard<std::mutex> lock(mutex);return radar; }
    bool enqueueRadarCenter(int x,int y) {
        std::lock_guard<std::mutex> lock(mutex);
        if(!state.active || x<0 || y<0)return false;
        // A drag should follow the latest finger position, not replay every
        // intermediate position several frames later.
        pending.erase(std::remove_if(pending.begin(),pending.end(),[](const Command& command) {
            return command.kind==RadarCenter;
        }),pending.end());
        if(pending.size()>=32)return false;
        pending.push_back({RadarCenter,0,x,y});return true;
    }
    bool enqueueProduction(bool cancel,int type,int id,bool building=false) {
        std::lock_guard<std::mutex> lock(mutex);
        if (!state.active || pending.size()>=32 || type<0 || id<0) return false;
        pending.push_back({building?(cancel?CancelBuildItem:BuildItem):(cancel?CancelUnit:QueueUnit),0,type,id}); return true;
    }
    bool enqueueSpecial(int id) {
        std::lock_guard<std::mutex> lock(mutex);
        if (!state.active || pending.size()>=32 || id<0) return false;
        pending.push_back({UseSpecial,0,0,id}); return true;
    }
    bool enqueue(Kind kind, int group=0) {
        std::lock_guard<std::mutex> lock(mutex);
        if (!state.active || pending.size()>=32 || group<0 || group>9) return false;
        if ((kind==Attack || kind==Move) && !state.selected) return false;
        pending.push_back({kind,group}); return true;
    }
    bool take(Command& cmd) {
        std::lock_guard<std::mutex> lock(mutex);
        if (pending.empty()) return false;
        cmd=pending.front(); pending.pop_front(); return true;
    }
    void rally(int mode) { std::lock_guard<std::mutex> lock(mutex);state.rally=mode>=0&&mode<=2?mode:0; }
    void force(int mode) { std::lock_guard<std::mutex> lock(mutex); state.force=state.active && state.selected ? mode : 0; }
};
State& Shared();
}
#endif
