#ifndef WIREPROOF_MENU_LAYOUT_H
#define WIREPROOF_MENU_LAYOUT_H
#include <algorithm>
namespace WPMenu {
struct Layout { int x,y,width,height,footerHeight,buttonHeight,step; };
inline Layout Calculate(int width,int height,int count) {
    Layout r{};
    r.footerHeight=std::min(height/3,width*130/640);
    r.width=std::min(520,width-32);r.x=(width-r.width)/2;r.y=12;
    r.height=height-r.footerHeight-24;
    r.step=std::max(1,(r.height-40)/std::max(1,count));
    r.buttonHeight=std::min(32,std::max(18,r.step-10));
    return r;
}
}
#endif
