#ifndef WIREPROOF_ORDERS_H
#define WIREPROOF_ORDERS_H
#include <mutex>
#include <deque>
namespace WPOrders {
enum Kind { Stop, Guard, Scatter, Attack, Move, Cancel, Recall, Assign, Add, Center };
struct Command { Kind kind; int group; };
struct Snapshot { bool active; int selected; int force; };
// UI threads only enqueue intentions. The game thread owns all game objects.
class State {
    std::mutex mutex;
    std::deque<Command> pending;
    Snapshot state = {false,0,0};
    bool pan_held = false;
public:
    void publish(bool active, int selected) {
        std::lock_guard<std::mutex> lock(mutex);
        state.active=active; state.selected=selected;
        if (!active) { pending.clear(); state.force=0; pan_held=false; }
        if (!selected) state.force=0;
    }
    void hold_pan(bool held) { std::lock_guard<std::mutex> lock(mutex); pan_held=held && state.active; }
    bool panHeld() { std::lock_guard<std::mutex> lock(mutex); return pan_held; }
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
