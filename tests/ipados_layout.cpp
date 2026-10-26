#include "common/ipados_layout.h"

#include <cassert>
#include <cmath>
#include <iostream>

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
    assert(std::abs(game_x - 320) <= 1);
    assert(std::abs(game_y - 200) <= 1);
}
}

int main()
{
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
        assert(fill.viewport.width==dimensions.width-80);
        assert(fill.viewport.height==dimensions.height-70);
        int x,y; Map_IPad_Output_Point(fill,fill.viewport.x+fill.viewport.width-1,fill.viewport.y+fill.viewport.height-1,x,y);
        assert(x==639 && y==399);
    }
    std::cout << "iPad layout hardening matrix passed\n";
    return 0;
}
