#pragma once
#include <mutex>
namespace WPCheats {
struct Snapshot {
    bool available=false, invincible=false, reveal=false;
    int infantry=4, vehicles=4, aircraft=4;
    int money=0, power=0, drain=0;
};
struct Actions { int money=0, power=0; };
class State {
    std::mutex mutex;
    Snapshot state;
    Actions pending;
public:
    Snapshot snapshot() { std::lock_guard<std::mutex> lock(mutex); return state; }
    void publish(bool available,int money,int power,int drain) {
        std::lock_guard<std::mutex> lock(mutex);
        state.available=available;state.money=money;state.power=power;state.drain=drain;
        if(!available) pending={};
    }
    void reset() { std::lock_guard<std::mutex> lock(mutex);state={};pending={}; }
    void invincible(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available)state.invincible=value; }
    void reveal(bool value) { std::lock_guard<std::mutex> lock(mutex);if(state.available)state.reveal=value; }
    void speed(int category,int quarters) {
        std::lock_guard<std::mutex> lock(mutex);if(!state.available)return;
        quarters=quarters<1?1:quarters>12?12:quarters;
        if(category==0)state.infantry=quarters;
        else if(category==1)state.vehicles=quarters;
        else if(category==2)state.aircraft=quarters;
    }
    void addMoney(int amount) { std::lock_guard<std::mutex> lock(mutex);if(state.available&&amount>0&&amount<=100000)pending.money=pending.money>900000?1000000:pending.money+amount; }
    void addPower(int amount) { std::lock_guard<std::mutex> lock(mutex);if(state.available&&amount>0&&amount<=1000)pending.power=pending.power>9000?10000:pending.power+amount; }
    Actions take() { std::lock_guard<std::mutex> lock(mutex);auto result=pending;pending={};return result; }
};
inline State& Shared() { static State state;return state; }
}
