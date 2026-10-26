#ifndef VIDEO_H
#define VIDEO_H

#include "rect.h"
#include <cstdint>

enum GBC_Enum
{
    GBC_NONE = 0,
    GBC_VIDEOMEM = 1,
    GBC_VISIBLE = 2,
};

class VideoSurface;

class Video
{
public:
    Video();
    virtual ~Video();

    static Video& Shared();

    VideoSurface* CreateSurface(int w, int h, GBC_Enum flags);
};

class VideoSurface
{
public:
    virtual ~VideoSurface()
    {
    }

    virtual void* GetData() const = 0;
    virtual int GetPitch() const = 0;
    virtual bool IsAllocated() const = 0;

    virtual void AddAttachedSurface(VideoSurface* surface) = 0;
    virtual bool IsReadyToBlit() = 0;
    virtual bool LockWait() = 0;
    virtual bool Unlock() = 0;
    virtual void Blt(const Rect& destRect, VideoSurface* src, const Rect& srcRect, bool mask) = 0;
    virtual void FillRect(const Rect& rect, unsigned char color) = 0;
};

class SurfaceMonitorClass
{
public:
    SurfaceMonitorClass();
    virtual ~SurfaceMonitorClass()
    {
    }

    virtual void Restore_Surfaces() = 0;
    virtual void Set_Surface_Focus(bool in_focus) = 0;
    virtual void Release() = 0;

    bool SurfacesRestored;
};

extern SurfaceMonitorClass& AllSurfaces; // List of all surfaces

bool Set_Video_Mode(int w, int h, int bits_per_pixel);
void Get_Video_Scale(float& x, float& y);
void Set_Video_Cursor_Clip(bool clipped);
void Move_Video_Mouse(float xrel, float yrel);
void Get_Video_Mouse(int& x, int& y);
void Refresh_Video_Layout();
float Video_Battlefield_Zoom();
void Video_Presentation_Size(int& width, int& height);
void Video_Publish_Order_Icon(int kind);
void Video_Set_Battlefield(bool active, int right, int top, int view_width, int view_height, float zoom, int sidebar_bottom = 0);
void Video_Adaptive_Size(int& width, int& height);
void Video_Set_Logical_Size(int width, int height);
#if defined(IPADOS_PORT) || defined(MACOS_PORT) || defined(VISIONOS_PORT)
void Set_Video_Mouse_Window(float window_x, float window_y, int& game_x, int& game_y);
#endif
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
void Set_Video_Mouse_Normalized(float normalized_x, float normalized_y, int& game_x, int& game_y);
int Video_Game_Pixels_For_Window_Points(float points);
void Set_Video_Render_Active(bool active);
void Video_Record_Input_Timestamp(uint32_t timestamp_ms);
void Video_Set_Touch_Feedback(int game_x, int game_y, bool pencil, bool released);
enum TouchFeedbackKind
{
    TOUCH_FEEDBACK_NEUTRAL = 0,
    TOUCH_FEEDBACK_MOVE = 1,
    TOUCH_FEEDBACK_ATTACK = 2,
};
void Video_Set_Touch_Feedback_Kind(TouchFeedbackKind kind);
void Video_Clear_Touch_Feedback(void);
void Video_Set_Touch_Input(bool touch_input);
bool Video_Touch_Help_Expired();
void Video_Set_Touch_Selection_Box(bool active, int x1, int y1, int x2, int y2);
// 0 = original/action cursor, 1 = normal pointer eligible for HD artwork.
void Video_Set_Cursor_Kind(int kind);
void Video_Set_Selection_Overlay(const void* object,
                                 int x,
                                 int y,
                                 int width,
                                 int height,
                                 unsigned char palette_index);
void Video_Remove_Selection_Overlay(const void* object);
void Video_Set_HD_Buggy_Component(const void* object,
                                  int component,
                                  int frame,
                                  int center_x,
                                  int center_y,
                                  unsigned char palette_index);
// vehicle_kind: 0 = Nod buggy, 1 = GDI Humvee, 2 = GDI MCV, 3 = Nod MCV.
void Video_Set_HD_Vehicle_Component(const void* object,
                                    int vehicle_kind,
                                    int component,
                                    int frame,
                                    int center_x,
                                    int center_y,
                                    unsigned char palette_index);
void Video_Set_HD_Infantry(const void* object,
                           int frame,
                           int center_x,
                           int center_y,
                           unsigned char palette_index);
// faction_kind: 0 = GDI, 1 = Nod. frame: 0 = power plant,
// 1 = infantry production, 2 = construction yard. activity_frame is -1 for
// static art, 0..19 for the yard and 20..29 for infantry production.
void Video_Set_HD_Building(const void* object,
                           int faction_kind,
                           int frame,
                           int activity_frame,
                           int center_x,
                           int center_y,
                           int width,
                           int height,
                           int completion,
                           int damage,
                           bool repairing,
                           unsigned char palette_index);
void Video_Set_HD_Health(const void* object,
                         bool visible,
                         int x,
                         int y,
                         int width,
                         int fill_width,
                         unsigned char palette_index);
void Video_Set_HD_Artwork_Clip(int x, int y, int width, int height);
void Video_Set_HD_World_Artwork_Visible(bool visible);
void Video_Offset_HD_World_Artwork(int x, int y);
void Video_Remove_HD_Artwork(const void* object);
void Video_Clear_HD_Artwork();
bool Video_Uses_HD_Buggy_Artwork();
bool Video_Uses_HD_Humvee_Artwork();
bool Video_Uses_HD_Minigunner_Artwork();
bool Video_Uses_HD_MCV_Artwork(bool nod);
bool Video_Uses_HD_Infrastructure_Artwork(bool nod);
bool Video_Uses_HD_Infrastructure_Activity_Artwork(bool nod);
bool Video_Uses_Modern_Artwork();
void Set_IPadOS_Text_Input_Rect(int game_x, int game_y, int game_w, int game_h);
int Video_Get_Effective_Frame_Limit();
bool Video_Render_Frame();
#endif
void Toggle_Video_Fullscreen();
void Reset_Video_Mode();
unsigned Get_Free_Video_Memory();
void Wait_Blit();

/*
** Set desired cursor image in game palette.
*/
void Set_Video_Cursor(void* cursor, int w, int h, int hotx, int hoty);

/*
 *  Flags returned by Get_Video_Hardware_Capabilities
 */
/* Hardware blits supported? */
#define VIDEO_BLITTER 1

/* Hardware blits asyncronous? */
#define VIDEO_BLITTER_ASYNC 2

/* Can palette changes be synced to vertical refresh? */
#define VIDEO_SYNC_PALETTE 4

/* Is the video cards memory bank switched? */
#define VIDEO_BANK_SWITCHED 8

/* Can the blitter do filled rectangles? */
#define VIDEO_COLOR_FILL 16

/* Is there no hardware assistance avaailable at all? */
#define VIDEO_NO_HARDWARE_ASSIST 32

unsigned Get_Video_Hardware_Capabilities();

void Wait_Vert_Blank();
void Set_DD_Palette(void* palette);

#endif // VIDEO_H
