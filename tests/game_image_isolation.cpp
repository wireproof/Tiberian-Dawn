// Run scripts/test-game-image-isolation.py on macOS. Uses actual engine headers.
#include "common/wireproof_laptop.h"
#include "common/wireproof_cheats.h"
#include <cassert>
#include <cstdio>
#include <dlfcn.h>

static int saved = 0;
namespace WPCheats {
Snapshot LoadPreferences() {
    Snapshot result;
#ifdef PROBE_PLUGIN
    result.invincible = true;
#endif
    return result;
}
void SavePreferences(const Snapshot&) { ++saved; }
}
static void* laptopState(int index) {
    switch(index) {
    case 0: return &WPLaptop::Enabled();
    case 1: return &WPLaptop::FoldedPortrait();
    case 2: return &WPLaptop::PortraitWindow();
    case 3: return &WPLaptop::AlwaysPortrait();
    case 4: return &WPLaptop::BuildOpen();
    case 5: return &WPLaptop::MovieActive();
    default: return &WPLaptop::SidebarVisible();
    }
}
#ifdef PROBE_PLUGIN
extern "C" void* pluginLaptop(int index) { return laptopState(index); }
extern "C" void* pluginCheats() { return &WPCheats::Shared(); }
extern "C" bool pluginExercise() {
    const bool preference = WPCheats::Shared().snapshot().invincible;
    WPCheats::Shared().publish(true, 0, 0, 0);
    WPCheats::Shared().invincible(false);
    WPLaptop::SetEnabled(true);
    WPLaptop::SetFoldedPortrait(true);
    return preference && saved == 1 && WPLaptop::Active();
}
#else
int main(int argc, char** argv) {
    assert(argc == 2);
    void* hostCheats = &WPCheats::Shared();
    assert(!WPCheats::Shared().snapshot().invincible);
    for(int i=0;i<7;++i) assert(laptopState(i));
    void* image = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!image) { std::puts(dlerror()); return 1; }
    auto laptop = reinterpret_cast<void* (*)(int)>(dlsym(image, "pluginLaptop"));
    auto cheats = reinterpret_cast<void* (*)()>(dlsym(image, "pluginCheats"));
    auto exercise = reinterpret_cast<bool (*)()>(dlsym(image, "pluginExercise"));
    assert(laptop && cheats && exercise);
    for(int i=0;i<7;++i) assert(laptopState(i) != laptop(i));
    assert(hostCheats != cheats());
    assert(exercise());
    assert(saved == 0 && !WPLaptop::Active() && !WPLaptop::Enabled().load());
    WPCheats::Shared().publish(true, 0, 0, 0);
    WPCheats::Shared().invincible(true);
    assert(saved == 1);
    // Leave the image resident, just as the combined app does.
}
#endif
