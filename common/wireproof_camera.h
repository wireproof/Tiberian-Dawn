#ifndef WIREPROOF_CAMERA_H
#define WIREPROOF_CAMERA_H
#include <algorithm>
#include <cmath>
namespace WPCamera {
// Clamp signed world coordinates before packing into the legacy unsigned format.
// A viewport larger than the map stays pinned to the map origin.
inline int ClampAxis(int position, int delta, int minimum, int extent, int viewport) {
    const long long maximum=static_cast<long long>(minimum)+std::max(0,extent-viewport);
    const long long desired=static_cast<long long>(position)+delta;
    return static_cast<int>(std::max(static_cast<long long>(minimum),std::min(maximum,desired)));
}
// A hosted cover can retain the inner window bounds and reserve a substantial
// edge strip instead. Normalize by dimension so rotation preserves the profile.
inline bool CoverDisplay(double width,double height,double left,double top,double right,double bottom) {
    const double usableW=std::max(1.0,width-left-right), usableH=std::max(1.0,height-top-bottom);
    return std::max(usableW,usableH)/std::min(usableW,usableH)>=1.65
        || std::max(left,right)/std::max(1.0,width)>=0.10
        || std::max(top,bottom)/std::max(1.0,height)>=0.10;
}
// Deliberately damped pinch: doubling finger separation changes zoom ~26%.
inline int PinchZoomQuarters(int initial, double ratio) {
    if(!std::isfinite(ratio) || ratio<=0)return initial;
    return std::max(2,std::min(12,(int)std::lround(initial*std::pow(ratio,1.0/3.0))));
}
inline int PortraitSidebarSlots(int width,int height) { return height>width ? 5 : 0; }
inline int SidebarSlots(int height,int top,int row,int arrows,int capacity) {
    return std::max(1,std::min(capacity,(height-top-arrows)/std::max(1,row)));
}
}
#endif
