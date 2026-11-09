#ifndef WIREPROOF_LAPTOP_H
#define WIREPROOF_LAPTOP_H

#include <atomic>

namespace WPLaptop {
inline std::atomic<bool>& Enabled() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& FoldedPortrait() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& PortraitWindow() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& AlwaysPortrait() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& BuildOpen() { static std::atomic<bool> value{true}; return value; }
inline std::atomic<bool>& MovieActive() { static std::atomic<bool> value{false}; return value; }
// The lower production deck remains available when the classic upper sidebar is hidden.
inline std::atomic<bool>& SidebarVisible() { static std::atomic<bool> value{false}; return value; }
inline void SetEnabled(bool value) { Enabled().store(value, std::memory_order_relaxed); }
inline void SetFoldedPortrait(bool value) { FoldedPortrait().store(value, std::memory_order_relaxed); }
inline void SetPortraitWindow(bool value) { PortraitWindow().store(value, std::memory_order_relaxed); }
inline void SetAlwaysPortrait(bool value) { AlwaysPortrait().store(value, std::memory_order_relaxed); }
inline bool Active() {
    return (Enabled().load(std::memory_order_relaxed)
            && FoldedPortrait().load(std::memory_order_relaxed))
        || (AlwaysPortrait().load(std::memory_order_relaxed)
            && PortraitWindow().load(std::memory_order_relaxed));
}
}

#endif
