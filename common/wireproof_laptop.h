#ifndef WIREPROOF_LAPTOP_H
#define WIREPROOF_LAPTOP_H

#include <atomic>

namespace WPLaptop {
inline std::atomic<bool>& Enabled() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& FoldedPortrait() { static std::atomic<bool> value{false}; return value; }
inline std::atomic<bool>& BuildOpen() { static std::atomic<bool> value{true}; return value; }
inline void SetEnabled(bool value) { Enabled().store(value, std::memory_order_relaxed); }
inline void SetFoldedPortrait(bool value) { FoldedPortrait().store(value, std::memory_order_relaxed); }
inline bool Active() {
    return Enabled().load(std::memory_order_relaxed)
        && FoldedPortrait().load(std::memory_order_relaxed);
}
}

#endif
