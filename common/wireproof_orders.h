#include <algorithm>
#ifndef WIREPROOF_ORDERS_H
#define WIREPROOF_ORDERS_H
#include <mutex>
#include <deque>
#include <cmath>
namespace WPOrders {
enum Kind { Stop, Guard, Scatter, Attack, Move, Cancel, Recall, Assign, Add, Center };
struct Stick { float x=0, y=0, intensity=0; };
struct Command { Kind kind; int group; };
struct Snapshot { bool active; int selected; int force; };
// UI threads only enqueue intentions. The game thread owns all game objects.
class State {
    std::mutex mutex;
    std::deque<Command> pending;
    Snapshot state = {false,0,0};
    bool pan_held = false;
    bool map_drag = false;
    Stick joystick;
    int zoom_quarters = 6;
    int joystick_size = 4, joystick_speed = 4;
public:
    void publish(bool active, int selected) {
        std::lock_guard<std::mutex> lock(mutex);
        state.active=active; state.selected=selected;
        if (!active) { pending.clear(); state.force=0; pan_held=false; map_drag=false; joystick={}; }
        if (!selected) state.force=0;
    }
    void setZoomQuarters(int value) { std::lock_guard<std::mutex> lock(mutex); zoom_quarters=value<2?2:value>12?12:value; }
    int zoomQuarters() { std::lock_guard<std::mutex> lock(mutex); return zoom_quarters; }
    void stepZoom(int delta) { std::lock_guard<std::mutex> lock(mutex); int value=zoom_quarters+delta; zoom_quarters=value<2?2:value>12?12:value; }
    int joystickSetting(bool speed) { std::lock_guard<std::mutex> lock(mutex); return speed?joystick_speed:joystick_size; }
    void setJoystickSetting(bool speed,int value) { std::lock_guard<std::mutex> lock(mutex); (speed?joystick_speed:joystick_size)=std::max(speed?1:2,std::min(speed?12:8,value)); }
    void hold_pan(bool held) { std::lock_guard<std::mutex> lock(mutex); pan_held=held && state.active; }
    void setMapDrag(bool value) { std::lock_guard<std::mutex> lock(mutex);map_drag=value && state.active;joystick={}; }
    bool mapDrag() { std::lock_guard<std::mutex> lock(mutex);return map_drag; }
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
    bool enqueue(Kind kind, int group=0) {
        std::lock_guard<std::mutex> lock(mutex);
        if (!state.active || pending.size()>=32 || group<0 || group>9) return false;
        if ((kind==Assign || kind==Attack || kind==Move) && !state.selected) return false;
        pending.push_back({kind,group}); return true;
    }
    bool take(Command& cmd) {
        std::lock_guard<std::mutex> lock(mutex);
        if (pending.empty()) return false;
        cmd=pending.front(); pending.pop_front(); return true;
    }
    void force(int mode) { std::lock_guard<std::mutex> lock(mutex); state.force=state.active && state.selected ? mode : 0; }
};
State& Shared();
}
#endif
