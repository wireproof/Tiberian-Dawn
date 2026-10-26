#pragma once
#include <mutex>
namespace WPCheats {
struct Snapshot {
    bool available=false, invincible=false, reveal=false, instant=false, free=false, weapons=false, anywhere=false;
    int infantry=4, vehicles=4, aircraft=4;
    int money=0, power=0, drain=0;
};
struct Actions { int money=0, power=0; };
class State {
    std::mutex mutex;
    Snapshot state;
    Actions pending;
    void (*savePreferences)(const Snapshot&)=nullptr;
    void persist() { if(savePreferences)savePreferences(state); }
public:
    explicit State(Snapshot preferences={}, void (*save)(const Snapshot&)=nullptr) : state(preferences), savePreferences(save) {
        state.available=false;state.money=state.power=state.drain=0;
        state.infantry=clampSpeed(state.infantry);state.vehicles=clampSpeed(state.vehicles);state.aircraft=clampSpeed(state.aircraft);
    }
    static int clampSpeed(int value) { return value<1?1:value>12?12:value; }
    Snapshot snapshot() { std::lock_guard<std::mutex> lock(mutex); return state; }
    void publish(bool available,int money,int power,int drain) {
        std::lock_guard<std::mutex> lock(mutex);
        state.available=available;state.money=money;state.power=power;state.drain=drain;
        if(!available) pending={};
    }
    void reset() { std::lock_guard<std::mutex> lock(mutex);state.available=false;state.money=state.power=state.drain=0;pending={}; }
    void invincible(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.invincible=value;persist();} }
    void reveal(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.reveal=value;persist();} }
    void instant(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.instant=value;persist();} }
    void free(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.free=value;persist();} }
    void weapons(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.weapons=value;persist();} }
    void anywhere(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available){state.anywhere=value;persist();} }
    void speed(int category,int quarters) {
        std::lock_guard<std::mutex> lock(mutex);if(!state.available)return;
        quarters=quarters<1?1:quarters>12?12:quarters;
        if(category==0)state.infantry=quarters;
        else if(category==1)state.vehicles=quarters;
        else if(category==2)state.aircraft=quarters;
        else return;
        persist();
    }
    void addMoney(int amount) { std::lock_guard<std::mutex> lock(mutex);if(state.available&&amount>0&&amount<=100000)pending.money=pending.money>900000?1000000:pending.money+amount; }
    void addPower(int amount) { std::lock_guard<std::mutex> lock(mutex);if(state.available&&amount>0&&amount<=1000)pending.power=pending.power>9000?10000:pending.power+amount; }
    Actions take() { std::lock_guard<std::mutex> lock(mutex);auto result=pending;pending={};return result; }
};
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
Snapshot LoadPreferences();
void SavePreferences(const Snapshot&);
inline State& Shared() { static State state(LoadPreferences(),SavePreferences);return state; }
#else
inline State& Shared() { static State state;return state; }
#endif
}
