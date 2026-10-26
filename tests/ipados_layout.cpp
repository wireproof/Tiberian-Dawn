#include "common/ipados_layout.h"

#include <cassert>
#include <cmath>
#include <iostream>
#include <utility>

namespace
{
void Assert_Contained(const IPadLayout& layout)
{
    const int safe_left = layout.safe_area.left;
    const int safe_top = layout.safe_area.top;
    const int safe_right = layout.output_width - layout.safe_area.right;
    const int safe_bottom = layout.output_height - layout.safe_area.bottom;
    assert(layout.viewport.width >= 1);
    assert(layout.viewport.height >= 1);
    assert(layout.viewport.x >= safe_left);
    assert(layout.viewport.y >= safe_top);
    assert(layout.viewport.x + layout.viewport.width <= safe_right);
    assert(layout.viewport.y + layout.viewport.height <= safe_bottom);
}

void Assert_Classic_Aspect(const IPadLayout& layout)
{
    const double aspect = static_cast<double>(layout.viewport.width) / layout.viewport.height;
    assert(std::fabs(aspect - 1.6) < 0.003);
}

void Assert_Center_Maps_To_Game_Center(const IPadLayout& layout)
{
    int game_x = 0;
    int game_y = 0;
    Map_IPad_Output_Point(layout,
                          layout.viewport.x + layout.viewport.width * 0.5f,
                          layout.viewport.y + layout.viewport.height * 0.5f,
                          game_x,
                          game_y);
    assert(std::abs(game_x - layout.game_width/2) <= 1);
    assert(std::abs(game_y - layout.game_height/2) <= 1);
}
}

int main()
{
    // Portrait/landscape use more map pixels, not nonuniform image stretching.
    for (const auto size : {std::pair<int,int>{900,1280}, {1280,900}, {2400,1080}, {1668,2388}}) {
        int w=640,h=400;
        Calculate_Adaptive_Game_Size(size.first,size.second,w,h);
        const auto fit=Calculate_IPad_Layout(size.first,size.second,size.first,size.second,w,h,{0,0,0,0},false);
        assert(std::abs(fit.viewport.width-size.first)<=2);
        assert(std::abs(fit.viewport.height-size.second)<=2);
        assert(w>=640 && h>=400 && w<=2048 && h<=2048);
    }
    int underX=550,underY=600;
    Map_Battlefield_Point(underX,underY,480,16,640,800,1.0f,446);
    assert(underX==550 && underY==600);
    Map_Battlefield_Point(underX,underY,480,16,640,800,2.0f,446);
    assert(underX==275 && underY==308);
    int x=300,y=216;
    Unzoom_IPad_Battlefield_Point(x,y,480,16,2.0f);
    assert(x==150 && y==116);
    x=500;y=216;
    Unzoom_IPad_Battlefield_Point(x,y,480,16,3.0f);
    assert(x==500 && y==216); // sidebar remains fixed
    x=300;y=8;
    Unzoom_IPad_Battlefield_Point(x,y,480,16,3.0f);
    assert(x==300 && y==8); // top bar remains fixed

    // Zoom-out must reveal more map, not reject scales below 1x.
    x=300;y=216; Unzoom_IPad_Battlefield_Point(x,y,480,16,0.5f);
    assert(x==600 && y==416);
    x=300;y=216; Unzoom_IPad_Battlefield_Point(x,y,480,16,0.75f);
    assert(x==400 && y==282);
    for (int q=2;q<=12;++q) {
        x=500;y=216; Unzoom_IPad_Battlefield_Point(x,y,480,16,q/4.0f);
        assert(x==500 && y==216);
        x=300;y=8; Unzoom_IPad_Battlefield_Point(x,y,480,16,q/4.0f);
        assert(x==300 && y==8);
    }

    for (int q=2;q<=12;++q) {
        const float z=q/4.0f;
        const int backing=std::max(640,(int)std::ceil(480/z)+160);
        x=500;y=100; Map_Battlefield_Point(x,y,480,16,640,backing,z);
        assert(x==backing-140 && y==100); // build bar hit targets follow backing storage
        x=400;y=8; Map_Battlefield_Point(x,y,480,16,640,backing,z);
        assert(x==backing-240 && y==8); // credits/top-right UI remains fixed
        x=20;y=8; Map_Battlefield_Point(x,y,480,16,640,backing,z);
        assert(x==20 && y==8); // Options remains left anchored
        x=300;y=216; Map_Battlefield_Point(x,y,480,16,640,backing,z);
        assert(x==(int)(300/z) && y==16+(int)(200/z));
    }

    IPadLayout landscape = Calculate_IPad_Layout(2420, 1668, 1210, 834, 640, 400, {0, 0, 0, 0}, false);
    assert(landscape.viewport.width == 2420);
    assert(landscape.viewport.height == 1513);
    assert(landscape.viewport.x == 0);
    assert(landscape.viewport.y == 77);
    assert(!landscape.compact);
    Assert_Contained(landscape);
    Assert_Classic_Aspect(landscape);
    Assert_Center_Maps_To_Game_Center(landscape);

    int game_x = -1;
    int game_y = -1;
    Map_IPad_Window_Point(landscape, 605.0f, 417.0f, game_x, game_y);
    assert(std::abs(game_x - 320) <= 1);
    assert(std::abs(game_y - 200) <= 1);
    Map_IPad_Normalized_Point(landscape, 0.5f, 0.5f, game_x, game_y);
    assert(std::abs(game_x - 320) <= 1);
    assert(std::abs(game_y - 200) <= 1);
    assert(IPad_Game_Pixels_For_Window_Points(landscape, 8.0f) == 5);
    assert(IPad_Game_Pixels_For_Window_Points(landscape, 44.0f) == 24);

    IPadLayout portrait = Calculate_IPad_Layout(1668, 2420, 834, 1210, 640, 400, {0, 48, 0, 40}, false);
    Assert_Contained(portrait);
    Assert_Classic_Aspect(portrait);
    Assert_Center_Maps_To_Game_Center(portrait);
    assert(IPad_Game_Pixels_For_Window_Points(portrait, 8.0f) == 7);
    assert(IPad_Game_Pixels_For_Window_Points(portrait, 44.0f) == 34);

    IPadLayout stage_manager =
        Calculate_IPad_Layout(1000, 1400, 500, 700, 640, 400, {20, 50, 10, 30}, false);
    assert(stage_manager.viewport.width == 970);
    assert(stage_manager.viewport.height == 606);
    assert(stage_manager.viewport.x == 20);
    assert(stage_manager.viewport.y == 407);
    assert(stage_manager.compact);
    Assert_Contained(stage_manager);
    Assert_Classic_Aspect(stage_manager);
    assert(IPad_Game_Pixels_For_Window_Points(stage_manager, 8.0f) == 11);
    assert(IPad_Game_Pixels_For_Window_Points(stage_manager, 44.0f) == 59);

    Map_IPad_Output_Point(stage_manager, -100.0f, -100.0f, game_x, game_y);
    assert(game_x == 0 && game_y == 0);
    Map_IPad_Output_Point(stage_manager, 5000.0f, 5000.0f, game_x, game_y);
    assert(game_x == 639 && game_y == 399);

    IPadLayout integer = Calculate_IPad_Layout(2420, 1668, 1210, 834, 640, 400, {0, 0, 0, 0}, true);
    assert(integer.viewport.width == 1920);
    assert(integer.viewport.height == 1200);
    assert(integer.viewport.x == 250);
    assert(integer.viewport.y == 234);
    Assert_Contained(integer);

    // Pixel-perfect mode must fall back to a contained fractional fit when a
    // Stage Manager window is physically smaller than the classic surface.
    IPadLayout tiny = Calculate_IPad_Layout(500, 300, 500, 300, 640, 400, {10, 0, 10, 0}, true);
    assert(tiny.viewport.width == 480);
    assert(tiny.viewport.height == 300);
    assert(tiny.viewport.x == 10);
    assert(tiny.viewport.y == 0);
    assert(tiny.compact);
    Assert_Contained(tiny);
    Assert_Classic_Aspect(tiny);

    IPadLayout external = Calculate_IPad_Layout(3840, 2160, 1920, 1080, 640, 400, {100, 0, 100, 0}, false);
    assert(external.viewport.width == 3456);
    assert(external.viewport.height == 2160);
    assert(external.viewport.x == 192);
    assert(external.viewport.y == 0);
    Assert_Contained(external);
    Assert_Classic_Aspect(external);

    IPadLayout hostile = Calculate_IPad_Layout(50, 40, 0, 0, 640, 400, {-30, 100, 200, -4}, true);
    Assert_Contained(hostile);
    assert(hostile.compact);

    for (auto dimensions : {IPadViewport{0,0,900,2100}, IPadViewport{0,0,2100,1800}, IPadViewport{0,0,1800,2100}}) {
        auto fill=Calculate_IPad_Layout(dimensions.width,dimensions.height,dimensions.width/2,dimensions.height/2,640,400,{20,40,60,30},false,true);
        Assert_Contained(fill); Assert_Center_Maps_To_Game_Center(fill);
        assert(fill.viewport.x==20+(dimensions.width-80-fill.viewport.width)/2);
        if (dimensions.width>=dimensions.height) {
            assert(fill.viewport.width==dimensions.width-80);
            assert(fill.viewport.height==dimensions.height-70);
        } else Assert_Classic_Aspect(fill);
        int x,y; Map_IPad_Output_Point(fill,fill.viewport.x+fill.viewport.width-1,fill.viewport.y+fill.viewport.height-1,x,y);
        assert(x>=638 && y>=398);
    }
    // Recompute from each current surface: inner -> cover -> rotated cover ->
    // inner. Never carry an offset or scale from the previous display forward.
    for (const auto dims : {IPadViewport{0,0,2854,2008}, IPadViewport{0,0,2400,1080},
                            IPadViewport{0,0,1080,2400}, IPadViewport{0,0,2854,2008}}) {
        for (bool fill : {false, true}) {
            auto current = Calculate_IPad_Layout(dims.width,dims.height,dims.width/2,dims.height/2,
                                                 640,400,{96,0,30,24},false,fill);
            Assert_Contained(current);
            Assert_Center_Maps_To_Game_Center(current);
            int x,y;
            Map_IPad_Normalized_Point(current,
                (current.viewport.x+current.viewport.width*0.5f)/dims.width,
                (current.viewport.y+current.viewport.height*0.5f)/dims.height,x,y);
            assert(std::abs(x-320)<=1 && std::abs(y-200)<=1);
        }
    }
    // Adaptive gameplay fits fractionally even when menu pixel-perfect mode
    // is selected: no integer-scale borders on cover or opened portrait.
    for(const auto dims : {IPadViewport{0,0,2560,1800},IPadViewport{0,0,1800,2560}}) {
        int w=640,h=400;
        Calculate_Adaptive_Game_Size(dims.width,dims.height,w,h);
        auto fitted=Calculate_IPad_Layout(dims.width,dims.height,dims.width/2,dims.height/2,
                                          w,h,{0,0,0,0},false,false);
        Assert_Contained(fitted);
        assert(dims.width-fitted.viewport.width<=2);
        assert(dims.height-fitted.viewport.height<=2);
        Assert_Center_Maps_To_Game_Center(fitted);
    }
    std::cout << "iPad layout hardening matrix passed\n";
    return 0;
}
