#include "function.h"
#include "common/video.h"
#include "common/wireproof_viewport.h"
#include <algorithm>
#include <cmath>

void WP_Update_Battlefield_Viewport(bool active)
{
#ifdef IPADOS_PORT
    static bool icons_published = false;
    if (active && !icons_published) {
        Map.Override_Mouse_Shape(MOUSE_CAN_ATTACK);
        Video_Publish_Order_Icon(0);
        Map.Override_Mouse_Shape(MOUSE_CAN_MOVE);
        Video_Publish_Order_Icon(1);
        Map.Revert_Mouse_Shape();
        icons_published = true;
    }
#endif
    int width = 640, height = 400;
    if (active) Video_Adaptive_Size(width, height);
    const int right = width - (Map.IsSidebarActive ? Map.SideBarWidth : 0);
    Video_Set_Battlefield(active, right, Map.Get_Tab_Height());
    static float previous_zoom = 1.0f;
    const float zoom = Video_Battlefield_Zoom();
    if (ScreenWidth == width && ScreenHeight == height) {
        const int target_w = (int)std::ceil(right / zoom);
        const int target_h = (int)std::ceil((height - Map.Get_Tab_Height()) / zoom);
        if (Map.TacLeptonWidth != Pixel_To_Lepton(target_w) || Map.TacLeptonHeight != Pixel_To_Lepton(target_h)) {
            const int center_x = Coord_X(Map.TacticalCoord) + Map.TacLeptonWidth / 2;
            const int center_y = Coord_Y(Map.TacticalCoord) + Map.TacLeptonHeight / 2;
            Map.Set_View_Dimensions(0, Map.Get_Tab_Height(), target_w, target_h);
            if (zoom != previous_zoom)
                Map.Set_Tactical_Position(XY_Coord(std::max(0, center_x - Map.TacLeptonWidth / 2),
                    std::max(0, center_y - Map.TacLeptonHeight / 2)));
            Map.Flag_To_Redraw(true);
        }
        previous_zoom = zoom;
        return;
    }
    // Only run between frames: all old views are reattached before drawing.
    Hide_Mouse();
    Video_Clear_HD_Artwork();
    Video_Set_Touch_Selection_Box(false, 0, 0, 0, 0);
    VisiblePage.Un_Init();
    HiddenPage.Un_Init();
    ScreenWidth = width;
    ScreenHeight = height;
    VisiblePage.Init(width, height, nullptr, 0, (GBC_Enum)(GBC_VISIBLE | GBC_VIDEOMEM));
    HiddenPage.Init(width, height, nullptr, 0, (GBC_Enum)GBC_VIDEOMEM);
    SeenBuff.Attach(&VisiblePage, 0, 0, width, height);
    HidPage.Attach(&HiddenPage, 0, 0, width, height);
    WindowList[WINDOW_MAIN][WINDOWWIDTH] = width;
    WindowList[WINDOW_MAIN][WINDOWHEIGHT] = height;
    Set_Logic_Page(HidPage);
    Video_Set_Logical_Size(width, height);
    Map.Resize_Apple_Viewport();
    Map.Set_View_Dimensions(0, Map.Get_Tab_Height(), (int)std::ceil(right / zoom),
        (int)std::ceil((height - Map.Get_Tab_Height()) / zoom));
    HidPage.Clear();
    SeenBuff.Clear();
    Map.Flag_To_Redraw(true);
    Show_Mouse();
}
