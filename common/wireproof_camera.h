#ifndef WIREPROOF_CAMERA_H
#define WIREPROOF_CAMERA_H
#include <algorithm>
namespace WPCamera {
// Clamp signed world coordinates before packing into the legacy unsigned format.
// A viewport larger than the map stays pinned to the map origin.
inline int ClampAxis(int position, int delta, int minimum, int extent, int viewport) {
    const long long maximum=static_cast<long long>(minimum)+std::max(0,extent-viewport);
    const long long desired=static_cast<long long>(position)+delta;
    return static_cast<int>(std::max(static_cast<long long>(minimum),std::min(maximum,desired)));
}
inline int SidebarSlots(int height,int top,int row,int arrows,int capacity) {
    return std::max(1,std::min(capacity,(height-top-arrows)/std::max(1,row)));
}
}
#endif
