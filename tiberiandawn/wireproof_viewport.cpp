#include "function.h"
#include "common/video.h"
#include "common/wireproof_viewport.h"
#include "common/wireproof_orders.h"
#include "common/wireproof_camera.h"
#include "common/wireproof_menu_layout.h"
#include <algorithm>
#include <cmath>

void WP_Update_Battlefield_Viewport(bool active, bool menu, bool classic)
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
    const bool adaptive=!classic && (active || menu || (InMainLoop && GameActive));
    if (adaptive) Video_Adaptive_Size(width, height);
    if(active && height>width){width=(int)std::lround(width/1.625);height=(int)std::lround(height/1.625);}
    const float uiScale=active?WPOrders::Shared().uiScale()/100.0f:1.0f;
    if(active){width=(int)std::lround(width/uiScale);height=(int)std::lround(height/uiScale);}
    const int right = width - (Map.IsSidebarActive ? Map.SideBarWidth : 0);
    const int view_height=height;
    const int slots=WPCamera::PortraitSidebarSlots(width,height);
    const int visibleSlots=WPCamera::SidebarSlots(height,182,48,24,24);
    const int bottom=Map.IsSidebarActive && slots?std::min(height,182+std::min(slots,visibleSlots)*48+24):height;
    const int worldRight=bottom<height?width:right;
    const float zoom=active?WPOrders::Shared().zoomQuarters()/4.0f/uiScale:1.0f;
    Video_Set_Battlefield(adaptive, right, Map.Get_Tab_Height(), width, height, zoom,bottom);
    static float previous_zoom = 1.0f;
    // Below 1x, render additional world pixels into a larger backing surface;
    // the presentation keeps the sidebar/top bar at their normal size.
    if (active && (zoom<1.0f || bottom<height)) {
        width=(int)std::max(width,(int)std::ceil(worldRight/zoom)+(width-right));
        height=std::max(height,Map.Get_Tab_Height()+(int)std::ceil((height-Map.Get_Tab_Height())/zoom));
    }
    // Keep three legacy 160px top tabs distinct before compact presentation.
    if(active)width=std::max(width,480);
    static float previous_ui_scale=1.0f;
    const bool ui_changed=uiScale!=previous_ui_scale;previous_ui_scale=uiScale;
    if (ScreenWidth == width && ScreenHeight == height && !ui_changed) {
        const int target_w = (int)std::ceil(worldRight / zoom);
        const int target_h = (int)std::ceil((view_height - Map.Get_Tab_Height()) / zoom);
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
    const int center_x = Coord_X(Map.TacticalCoord) + Map.TacLeptonWidth / 2;
    const int center_y = Coord_Y(Map.TacticalCoord) + Map.TacLeptonHeight / 2;
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
    Map.Set_View_Dimensions(0, Map.Get_Tab_Height(), (int)std::ceil(worldRight / zoom),
        (int)std::ceil((view_height - Map.Get_Tab_Height()) / zoom));
    if (zoom!=previous_zoom) Map.Set_Tactical_Position(XY_Coord(std::max(0,center_x-Map.TacLeptonWidth/2),
        std::max(0,center_y-Map.TacLeptonHeight/2)));
    previous_zoom=zoom;
    HidPage.Clear();
    SeenBuff.Clear();
    Map.Flag_To_Redraw(true);
    Show_Mouse();
}

// Fixed-resolution score, movie and campaign-map art must not inherit a
// battlefield crop/zoom just because the enclosing mission loop is still active.
void WP_Begin_Campaign_Presentation()
{
    WPOrders::Shared().publish(false,0);
    WP_Update_Battlefield_Viewport(false,false,true);
    Video_Clear_HD_Artwork();
    Video_Set_Touch_Selection_Box(false,0,0,0,0);
}

// Main menu and its load dialog share the same responsive background.
void WP_Draw_Menu_Background()
{
    GraphicBufferClass title(640,400,nullptr,0);
    Load_Title_Screen(TitlePicture,&title,Palette);
    const double aspect=double(ScreenWidth)/ScreenHeight;
    int cropW=160,cropH=270;
    if(double(cropW)/cropH>aspect)cropW=MAX(1,int(cropH*aspect));
    else cropH=MAX(1,int(cropW/aspect));
    title.Scale(HidPage,(160-cropW)/2,(270-cropH)/2,0,0,cropW,cropH,ScreenWidth,ScreenHeight);
    const int footerHeight=WPMenu::Calculate(ScreenWidth,ScreenHeight,6).footerHeight;
    const int logoW=footerHeight*640/130;
    title.Scale(HidPage,0,270,(ScreenWidth-logoW)/2,ScreenHeight-footerHeight,
                640,130,logoW,footerHeight);
}
