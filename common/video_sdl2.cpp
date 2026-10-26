//
// Copyright 2020 Electronic Arts Inc.
//
// TiberianDawn.DLL and RedAlert.dll and corresponding source code is free
// software: you can redistribute it and/or modify it under the terms of
// the GNU General Public License as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.

// TiberianDawn.DLL and RedAlert.dll and corresponding source code is distributed
// in the hope that it will be useful, but with permitted additional restrictions
// under Section 7 of the GPL. See the GNU General Public License in LICENSE.TXT
// distributed with this program. You should have received a copy of the
// GNU General Public License along with permitted additional restrictions
// with this program. If not, see https://github.com/electronicarts/CnC_Remastered_Collection

/***************************************************************************
 **   C O N F I D E N T I A L --- W E S T W O O D   A S S O C I A T E S   **
 ***************************************************************************
 *                                                                         *
 *                 Project Name : Westwood Win32 Library                   *
 *                                                                         *
 *                    File Name : DDRAW.CPP                                *
 *                                                                         *
 *                   Programmer : Philip W. Gorrow                         *
 *                                                                         *
 *                   Start Date : October 10, 1995                         *
 *                                                                         *
 *                  Last Update : October 10, 1995   []                    *
 *                                                                         *
 *-------------------------------------------------------------------------*
 * Functions:                                                              *
 * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

/*=========================================================================*/
/* The following PRIVATE functions are in this file:                       */
/*=========================================================================*/

/*= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =*/

#include "gbuffer.h"
#include "palette.h"
#include "video.h"
#include "wwkeyboard.h"
#include "wwmouse.h"
#include "settings.h"
#include "debugstring.h"
#include "app_lifecycle.h"
#include "ipados_layout.h"

#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>
#include <SDL.h>

#if defined(IPADOS_PORT) || defined(MACOS_PORT)
#define TIBERIAN_DAWN_APPLE_PORT 1
#endif

#ifdef IPADOS_PORT
#include "../platform/apple/ipados_platform.h"
#endif
#ifdef TIBERIAN_DAWN_APPLE_PORT
#include "hd_asset_pack.h"
#include "ipados_palette_renderer.h"
#include "paths.h"
#include <mach/mach.h>
#include <sys/resource.h>
#endif

extern WWKeyboardClass* Keyboard;
static SDL_Window* window;
static SDL_Renderer* renderer;
static SDL_Palette* palette;
static Uint32 pixel_format;
static SDL_Rect render_dst;
static int renderer_output_w;
static int renderer_output_h;
static int window_points_w;
static int window_points_h;
#ifdef TIBERIAN_DAWN_APPLE_PORT
static IPadLayout ipad_layout;
#endif

#ifdef TIBERIAN_DAWN_APPLE_PORT
extern "C" void TiberianDawn_GetSafeAreaInsets(SDL_Window* sdl_window,
                                              int output_width,
                                              int output_height,
                                              int* left,
                                              int* top,
                                              int* right,
                                              int* bottom);
extern "C" int TiberianDawn_IsLowPowerModeEnabled(void);
extern "C" int TiberianDawn_GetThermalState(void);
extern "C" void TiberianDawn_SetCompactWindowWarning(bool visible);
#endif

#ifdef TIBERIAN_DAWN_APPLE_PORT
namespace
{
std::atomic<uint32_t> pending_input_timestamp(0);
HDAssetPack modern_art_pack;
bool modern_art_pack_checked = false;
uint64_t palette_generation = 1;
uint64_t cursor_generation = 1;
int cursor_kind = 0;
uint64_t selection_generation = 1;
uint64_t hd_buggy_generation = 1;
bool hd_buggy_renderer_available = false;
bool hd_humvee_renderer_available = false;
bool hd_minigunner_renderer_available = false;
bool hd_gdi_mcv_renderer_available = false;
bool hd_nod_mcv_renderer_available = false;
bool hd_gdi_infrastructure_renderer_available = false;
bool hd_nod_infrastructure_renderer_available = false;
bool hd_gdi_infrastructure_activity_renderer_available = false;
bool hd_nod_infrastructure_activity_renderer_available = false;
IPadPaletteRect hd_artwork_clip = {0, 0, 0, 0};
bool hd_world_artwork_visible = true;
Uint8 previous_palette[256 * 3] = {0};
bool has_previous_palette = false;
bool force_present = true;
bool render_active = true;
bool last_frame_idle = false;
bool low_power_mode = false;
int thermal_state = 0;
Uint32 power_state_checked_at = 0;

struct TouchFeedbackState
{
    int x = 0;
    int y = 0;
    bool active = false;
    bool pencil = false;
    TouchFeedbackKind kind = TOUCH_FEEDBACK_NEUTRAL;
    Uint32 expires_at = 0;
    uint64_t generation = 1;
};

TouchFeedbackState touch_feedback;

struct TouchSelectionBoxState
{
    bool active = false;
    int x1 = 0;
    int y1 = 0;
    int x2 = 0;
    int y2 = 0;
    uint64_t generation = 1;
};

TouchSelectionBoxState touch_selection_box;
bool touch_input_active = false;

struct RegisteredSelectionOverlay
{
    const void* object = nullptr;
    IPadPaletteRect logical = {};
    std::uint8_t palette_index = 0;
};

std::vector<RegisteredSelectionOverlay> selection_overlays;

struct RegisteredHDBuggy
{
    const void* object = nullptr;
    int body_x = 0;
    int body_y = 0;
    int turret_x = 0;
    int turret_y = 0;
    int body_frame = -1;
    int turret_frame = -1;
    int health_x = 0;
    int health_y = 0;
    int health_width = 0;
    int health_fill_width = 0;
    std::uint8_t palette_index = 0;
    std::uint8_t health_palette_index = 0;
    bool health_visible = false;
    int atlas_kind = 0;
};

std::vector<RegisteredHDBuggy> hd_buggies;

struct RegisteredHDInfantry
{
    const void* object = nullptr;
    int center_x = 0;
    int center_y = 0;
    int frame = -1;
    int health_x = 0;
    int health_y = 0;
    int health_width = 0;
    int health_fill_width = 0;
    std::uint8_t palette_index = 0;
    std::uint8_t health_palette_index = 0;
    bool health_visible = false;
};

std::vector<RegisteredHDInfantry> hd_infantry;

struct RegisteredHDBuilding
{
    const void* object = nullptr;
    int center_x = 0;
    int center_y = 0;
    int width = 0;
    int height = 0;
    int frame = -1;
    int activity_frame = -1;
    int completion = 255;
    int damage = 0;
    int health_x = 0;
    int health_y = 0;
    int health_width = 0;
    int health_fill_width = 0;
    std::uint8_t palette_index = 0;
    std::uint8_t health_palette_index = 0;
    bool health_visible = false;
    bool repairing = false;
    int faction_kind = 0;
};

std::vector<RegisteredHDBuilding> hd_buildings;

void Discover_Modern_Art_Pack()
{
    if (modern_art_pack_checked) return;
    modern_art_pack_checked = true;
    const std::string directory = Paths.Concatenate_Paths(Paths.User_Path(), "ModernArt");
    std::string error;
    if (modern_art_pack.Load(directory, error)) {
        DBG_INFO("Optional HD asset pack '%s' loaded: id=%s scale=%dx assets=%zu",
                 modern_art_pack.Manifest().Name.c_str(),
                 modern_art_pack.Manifest().Identifier.c_str(),
                 modern_art_pack.Manifest().Scale,
                 modern_art_pack.Manifest().Assets.size());
    } else {
        if (error != "manifest.ini not found") {
            DBG_WARN("Optional user HD asset pack rejected: %s; trying built-in proof pack", error.c_str());
        }
        // iPadOS places bundle resources beside the executable, while a
        // native macOS .app keeps them in Contents/Resources.
#ifdef MACOS_PORT
        const std::string resources_directory = Paths.Concatenate_Paths(Paths.Program_Path(), "../Resources");
        const std::string built_in_directory = Paths.Concatenate_Paths(resources_directory.c_str(), "ModernArt");
#else
        const std::string built_in_directory = Paths.Concatenate_Paths(Paths.Program_Path(), "ModernArt");
#endif
        if (modern_art_pack.Load(built_in_directory, error)) {
            DBG_INFO("Built-in HD asset pack '%s' loaded: id=%s scale=%dx assets=%zu",
                     modern_art_pack.Manifest().Name.c_str(),
                     modern_art_pack.Manifest().Identifier.c_str(),
                     modern_art_pack.Manifest().Scale,
                     modern_art_pack.Manifest().Assets.size());
        } else {
            DBG_WARN("Built-in HD asset pack unavailable: %s; original artwork fallback active", error.c_str());
        }
    }
}

std::string Modern_Cursor_Path()
{
    const HDAssetEntry* cursor = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("cursor.default") : nullptr;
    return cursor ? modern_art_pack.Absolute_Path(*cursor) : std::string();
}

std::string Modern_Buggy_Atlas_Path()
{
    const HDAssetEntry* buggy = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("unit.buggy") : nullptr;
    return buggy ? modern_art_pack.Absolute_Path(*buggy) : std::string();
}

std::string Modern_Humvee_Atlas_Path()
{
    const HDAssetEntry* humvee = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("unit.humvee") : nullptr;
    return humvee ? modern_art_pack.Absolute_Path(*humvee) : std::string();
}

std::string Modern_Minigunner_Atlas_Path()
{
    const HDAssetEntry* minigunner = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("infantry.minigunner") : nullptr;
    return minigunner ? modern_art_pack.Absolute_Path(*minigunner) : std::string();
}

std::string Modern_GDI_MCV_Atlas_Path()
{
    const HDAssetEntry* mcv = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("unit.mcv.gdi") : nullptr;
    return mcv ? modern_art_pack.Absolute_Path(*mcv) : std::string();
}

std::string Modern_Nod_MCV_Atlas_Path()
{
    const HDAssetEntry* mcv = modern_art_pack.Is_Loaded() ? modern_art_pack.Find("unit.mcv.nod") : nullptr;
    return mcv ? modern_art_pack.Absolute_Path(*mcv) : std::string();
}

std::string Modern_GDI_Infrastructure_Atlas_Path()
{
    const HDAssetEntry* infrastructure = modern_art_pack.Is_Loaded()
                                                   ? modern_art_pack.Find("building.infrastructure.gdi")
                                                   : nullptr;
    return infrastructure ? modern_art_pack.Absolute_Path(*infrastructure) : std::string();
}

std::string Modern_Nod_Infrastructure_Atlas_Path()
{
    const HDAssetEntry* infrastructure = modern_art_pack.Is_Loaded()
                                                   ? modern_art_pack.Find("building.infrastructure.nod")
                                                   : nullptr;
    return infrastructure ? modern_art_pack.Absolute_Path(*infrastructure) : std::string();
}

std::string Modern_GDI_Infrastructure_Activity_Atlas_Path()
{
    const HDAssetEntry* infrastructure = modern_art_pack.Is_Loaded()
                                                   ? modern_art_pack.Find("building.infrastructure.activity.gdi")
                                                   : nullptr;
    return infrastructure ? modern_art_pack.Absolute_Path(*infrastructure) : std::string();
}

std::string Modern_Nod_Infrastructure_Activity_Atlas_Path()
{
    const HDAssetEntry* infrastructure = modern_art_pack.Is_Loaded()
                                                   ? modern_art_pack.Find("building.infrastructure.activity.nod")
                                                   : nullptr;
    return infrastructure ? modern_art_pack.Absolute_Path(*infrastructure) : std::string();
}

int Modern_Asset_Scale()
{
    return modern_art_pack.Is_Loaded() ? modern_art_pack.Manifest().Scale : 4;
}

struct VideoTelemetry
{
    Uint32 interval_started_at = 0;
    uint64_t attempts = 0;
    uint64_t presents = 0;
    uint64_t uploads = 0;
    uint64_t unchanged_skips = 0;
    uint64_t inactive_skips = 0;
    double present_ms = 0.0;
    double input_latency_ms = 0.0;
    double max_input_latency_ms = 0.0;
    uint64_t input_samples = 0;
    double previous_cpu_seconds = 0.0;
};

VideoTelemetry telemetry;

const char* Thermal_State_Name(int state)
{
    static const char* const names[] = {"nominal", "fair", "serious", "critical"};
    return state >= 0 && state < 4 ? names[state] : "unknown";
}

void Update_Power_State()
{
    const Uint32 now = SDL_GetTicks();
    if (power_state_checked_at != 0 && now - power_state_checked_at < 1000) {
        return;
    }

    power_state_checked_at = now;
    const bool new_low_power_mode = TiberianDawn_IsLowPowerModeEnabled() != 0;
    const int new_thermal_state = TiberianDawn_GetThermalState();
    if (new_low_power_mode != low_power_mode || new_thermal_state != thermal_state) {
        low_power_mode = new_low_power_mode;
        thermal_state = new_thermal_state;
        DBG_INFO("iPad power policy changed: low_power=%s thermal=%s",
                 low_power_mode ? "on" : "off",
                 Thermal_State_Name(thermal_state));
    }
}

double Process_CPU_Seconds()
{
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0) {
        return 0.0;
    }
    return usage.ru_utime.tv_sec + usage.ru_utime.tv_usec / 1000000.0 + usage.ru_stime.tv_sec
           + usage.ru_stime.tv_usec / 1000000.0;
}

double Resident_Megabytes()
{
    mach_task_basic_info_data_t info;
    mach_msg_type_number_t count = MACH_TASK_BASIC_INFO_COUNT;
    if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, reinterpret_cast<task_info_t>(&info), &count)
        != KERN_SUCCESS) {
        return 0.0;
    }
    return info.resident_size / (1024.0 * 1024.0);
}

void Report_Telemetry_If_Due()
{
    const Uint32 now = SDL_GetTicks();
    if (telemetry.interval_started_at == 0) {
        telemetry.interval_started_at = now;
        telemetry.previous_cpu_seconds = Process_CPU_Seconds();
        return;
    }

    const Uint32 elapsed_ms = now - telemetry.interval_started_at;
    if (elapsed_ms < 5000) {
        return;
    }

    const double elapsed_seconds = elapsed_ms / 1000.0;
    const double cpu_seconds = Process_CPU_Seconds();
    const double cpu_percent = elapsed_seconds > 0.0
                                   ? (cpu_seconds - telemetry.previous_cpu_seconds) * 100.0 / elapsed_seconds
                                   : 0.0;
    const double average_present_ms = telemetry.presents > 0 ? telemetry.present_ms / telemetry.presents : 0.0;
    const double average_latency_ms = telemetry.input_samples > 0
                                          ? telemetry.input_latency_ms / telemetry.input_samples
                                          : 0.0;

    DBG_INFO("iPad perf: target=%d fps actual=%.1f uploads=%.1f/s unchanged=%llu inactive=%llu "
             "present=%.2fms cpu=%.1f%% resident=%.1fMB touch=%.1f/%.1fms low_power=%s thermal=%s",
             Video_Get_Effective_Frame_Limit(),
             telemetry.presents / elapsed_seconds,
             telemetry.uploads / elapsed_seconds,
             static_cast<unsigned long long>(telemetry.unchanged_skips),
             static_cast<unsigned long long>(telemetry.inactive_skips),
             average_present_ms,
             cpu_percent,
             Resident_Megabytes(),
             average_latency_ms,
             telemetry.max_input_latency_ms,
             low_power_mode ? "on" : "off",
             Thermal_State_Name(thermal_state));

    telemetry = VideoTelemetry();
    telemetry.interval_started_at = now;
    telemetry.previous_cpu_seconds = cpu_seconds;
}
}
#endif

static struct
{
    int GameW;
    int GameH;
    bool Clip;
    float ScaleX{1.0f};
    float ScaleY{1.0f};
    void* Raw;
    int W;
    int H;
    int HotX;
    int HotY;
    float X;
    float Y;
    SDL_Cursor* Pending;
    SDL_Cursor* Current;
    SDL_Surface* Surface;
} hwcursor;

#define ARRAY_SIZE(x) int(sizeof(x) / sizeof(x[0]))
#define MAKEFORMAT(f)                                                                                                  \
    {                                                                                                                  \
        SDL_PIXELFORMAT_##f, #f                                                                                        \
    }
Uint32 SettingsPixelFormat()
{
    /*
    ** Known good RGB formats for both the surface and texture.
    */
    static struct
    {
        Uint32 format;
        std::string name;
    } formats[] = {
        MAKEFORMAT(ARGB8888),
        MAKEFORMAT(RGBA8888),
        MAKEFORMAT(ABGR8888),
        MAKEFORMAT(BGRA8888),
        MAKEFORMAT(RGB24),
        MAKEFORMAT(BGR24),
        MAKEFORMAT(RGB888),
        MAKEFORMAT(BGR888),
        MAKEFORMAT(RGB555),
        MAKEFORMAT(BGR555),
        MAKEFORMAT(RGB565),
        MAKEFORMAT(BGR565),
    };

    std::string str = Settings.Video.PixelFormat;

    for (auto& c : str) {
        c = toupper(c);
    }

    for (int i = 0; i < ARRAY_SIZE(formats); i++) {
        if (str.compare(formats[i].name) == 0) {
            return formats[i].format;
        }
    }

    return SDL_PIXELFORMAT_UNKNOWN;
}

static void Update_HWCursor();

#ifdef TIBERIAN_DAWN_APPLE_PORT
static bool battlefield_active = false;
static int battlefield_view_w = 0, battlefield_view_h = 0;
static int Presentation_Width() { return battlefield_view_w>0?battlefield_view_w:hwcursor.GameW; }
static int Presentation_Height() { return battlefield_view_h>0?battlefield_view_h:hwcursor.GameH; }
#endif

static void Update_HWCursor_Settings(bool geometry_only = false)
{
    if (window == nullptr || renderer == nullptr || hwcursor.GameW <= 0 || hwcursor.GameH <= 0) {
        return;
    }

    /*
    ** Renderer coordinates are drawable pixels, while SDL mouse coordinates
    ** are UIKit points. Keep both sizes so Retina windows and Stage Manager
    ** use the same mapping as normalized touch input.
    */
    const SDL_Rect previous_destination = render_dst;
    const int previous_points_w = window_points_w;
    const int previous_points_h = window_points_h;
    int previous_output_w = renderer_output_w;
    int previous_output_h = renderer_output_h;
    SDL_GetRendererOutputSize(renderer, &renderer_output_w, &renderer_output_h);
    SDL_GetWindowSize(window, &window_points_w, &window_points_h);

    if (renderer_output_w <= 0 || renderer_output_h <= 0 || window_points_w <= 0 || window_points_h <= 0) {
        return;
    }

    int safe_left = 0;
    int safe_top = 0;
    int safe_right = 0;
    int safe_bottom = 0;
#ifdef TIBERIAN_DAWN_APPLE_PORT
    TiberianDawn_GetSafeAreaInsets(window,
                                renderer_output_w,
                                renderer_output_h,
                                &safe_left,
                                &safe_top,
                                &safe_right,
                                &safe_bottom);
#endif

    /*
    ** Update screen boxing settings.
    */
    float ar = (float)hwcursor.GameW / hwcursor.GameH;
#ifdef TIBERIAN_DAWN_APPLE_PORT
    ipad_layout = Calculate_IPad_Layout(renderer_output_w,
                                        renderer_output_h,
                                        window_points_w,
                                        window_points_h,
                                        Presentation_Width(),
                                        Presentation_Height(),
                                        {safe_left, safe_top, safe_right, safe_bottom},
                                        !battlefield_active && Settings.Video.PresentationMode == 1,
                                        !battlefield_active && Settings.Video.PresentationMode == 3);
    render_dst.x = ipad_layout.viewport.x;
    render_dst.y = ipad_layout.viewport.y;
    render_dst.w = ipad_layout.viewport.width;
    render_dst.h = ipad_layout.viewport.height;
    TiberianDawn_SetCompactWindowWarning(ipad_layout.compact);
#else
    if (Settings.Video.Boxing) {
        size_t colonPos = Settings.Video.BoxingAspectRatio.find(":");
        std::string arW;
        std::string arH;

        /*
        ** If we don't have a valid string for aspect ratio, default back to 4:3.
        */
        if (colonPos == std::string::npos) {
            arW = "4";
            arH = "3";
        } else {
            size_t arLen = Settings.Video.BoxingAspectRatio.length();
            arW = Settings.Video.BoxingAspectRatio.substr(0, colonPos);
            arH = Settings.Video.BoxingAspectRatio.substr(colonPos + 1, arLen - colonPos);
        }

        ar = std::stof(arW) / std::stof(arH);

        render_dst.w = renderer_output_w;
        render_dst.h = render_dst.w / ar;
        if (render_dst.h > renderer_output_h) {
            render_dst.h = renderer_output_h;
            render_dst.w = render_dst.h * ar;
        }
        render_dst.x = (renderer_output_w - render_dst.w) / 2;
        render_dst.y = (renderer_output_h - render_dst.h) / 2;
    } else {
        render_dst.w = renderer_output_w;
        render_dst.h = renderer_output_h;
        render_dst.x = 0;
        render_dst.y = 0;
    }
#endif

    const bool geometry_changed = previous_output_w != renderer_output_w
                                  || previous_output_h != renderer_output_h
                                  || previous_points_w != window_points_w
                                  || previous_points_h != window_points_h
                                  || previous_destination.x != render_dst.x
                                  || previous_destination.y != render_dst.y
                                  || previous_destination.w != render_dst.w
                                  || previous_destination.h != render_dst.h;
    if (geometry_only && !geometry_changed) return;
#ifdef TIBERIAN_DAWN_APPLE_PORT
    if (geometry_changed) force_present = true;
#endif

    hwcursor.ScaleX = render_dst.w / (float)hwcursor.GameW;
    hwcursor.ScaleY = render_dst.h / (float)hwcursor.GameH;

    if (previous_output_w != renderer_output_w || previous_output_h != renderer_output_h) {
        DBG_INFO("Video layout: drawable %dx%d, viewport %dx%d at %d,%d",
                 renderer_output_w,
                 renderer_output_h,
                 render_dst.w,
                 render_dst.h,
                 render_dst.x,
                 render_dst.y);
    }

    /*
    ** Ensure cursor clip is in the desired state.
    */
    Set_Video_Cursor_Clip(hwcursor.Clip);

    /*
    ** Update visible cursor scaling.
    */
    Update_HWCursor();
}

class SurfaceMonitorClassDummy : public SurfaceMonitorClass
{

public:
    SurfaceMonitorClassDummy()
    {
    }

    virtual void Restore_Surfaces()
    {
    }

    virtual void Set_Surface_Focus(bool in_focus)
    {
    }

    virtual void Release()
    {
    }
};

SurfaceMonitorClassDummy AllSurfacesDummy;           // List of all direct draw surfaces
SurfaceMonitorClass& AllSurfaces = AllSurfacesDummy; // List of all direct draw surfaces

/***********************************************************************************************
 * Set_Video_Mode -- Initializes Direct Draw and sets the required Video Mode                  *
 *                                                                                             *
 * INPUT:           int width           - the width of the video mode in pixels                *
 *                  int height          - the height of the video mode in pixels               *
 *                  int bits_per_pixel  - the number of bits per pixel the video mode supports *
 *                                                                                             *
 * OUTPUT:     none                                                                            *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *   09/26/1995 PWG : Created.                                                                 *
 *=============================================================================================*/
bool Set_Video_Mode(int w, int h, int bits_per_pixel)
{
#ifdef IPADOS_PORT
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    SDL_SetHint(SDL_HINT_MOUSE_TOUCH_EVENTS, "0");
    SDL_SetHint(SDL_HINT_IOS_HIDE_HOME_INDICATOR, "2");
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight Portrait PortraitUpsideDown");
#endif
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS);
    SDL_ShowCursor(SDL_DISABLE);

    int win_w = w;
    int win_h = h;
    int win_flags = 0;
    Uint32 requested_pixel_format = SettingsPixelFormat();

#ifdef IPADOS_PORT
    Settings.Video.Windowed = true;
    Settings.Mouse.RawInput = false;
    win_flags = SDL_WINDOW_BORDERLESS | SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI;
#elif defined(MACOS_PORT)
    win_flags = SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI;
    if (!Settings.Video.Windowed) {
        win_w = Settings.Video.Width = 0;
        win_h = Settings.Video.Height = 0;
        win_flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
    } else {
        win_w = std::max(w, Settings.Video.WindowWidth);
        win_h = std::max(h, Settings.Video.WindowHeight);

        // Keep the first window comfortably inside the visible desktop,
        // including the menu bar and Dock, on smaller Mac displays.
        SDL_Rect usable = {};
        if (SDL_GetDisplayUsableBounds(0, &usable) == 0 && usable.w > 0 && usable.h > 0) {
            const int maximum_w = std::max(w, usable.w * 9 / 10);
            const int maximum_h = std::max(h, usable.h * 9 / 10);
            const float fit = std::min(1.0f,
                                       std::min(maximum_w / static_cast<float>(win_w),
                                                maximum_h / static_cast<float>(win_h)));
            win_w = std::max(w, static_cast<int>(std::floor(win_w * fit)));
            win_h = std::max(h, static_cast<int>(std::floor(win_h * fit)));
        }
        Settings.Video.WindowWidth = win_w;
        Settings.Video.WindowHeight = win_h;
    }
#else
    if (!Settings.Video.Windowed) {
        /*
        ** Native fullscreen if no proper width and height set.
        */
        if (Settings.Video.Width < w || Settings.Video.Height < h) {
            win_w = Settings.Video.Width = 0;
            win_h = Settings.Video.Height = 0;
            win_flags |= SDL_WINDOW_FULLSCREEN_DESKTOP;
        } else {
            win_w = Settings.Video.Width;
            win_h = Settings.Video.Height;
            win_flags |= SDL_WINDOW_FULLSCREEN;
        }
    } else if (Settings.Video.WindowWidth > w || Settings.Video.WindowHeight > h) {
        win_w = Settings.Video.WindowWidth;
        win_h = Settings.Video.WindowHeight;
    } else {
        Settings.Video.WindowWidth = win_w;
        Settings.Video.WindowHeight = win_h;
    }
#endif

    const char* window_title =
#ifdef MACOS_PORT
        "Tiberian Dawn";
#else
        "Vanilla Conquer";
#endif
    window = SDL_CreateWindow(window_title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, win_w, win_h, win_flags);
    if (window == nullptr) {
        DBG_ERROR("SDL_CreateWindow failed: %s", SDL_GetError());
        Reset_Video_Mode();
        return false;
    }

    DBG_INFO("Created SDL2 %s window in %dx%d",
             (win_flags & (SDL_WINDOW_FULLSCREEN | SDL_WINDOW_FULLSCREEN_DESKTOP)) ? "fullscreen" : "windowed",
             win_w,
             win_h);

    pixel_format = SDL_GetWindowPixelFormat(window);
    if (pixel_format == SDL_PIXELFORMAT_UNKNOWN || SDL_BITSPERPIXEL(pixel_format) < 16) {
        DBG_ERROR("SDL2 window pixel format unsupported: %s (%d bpp)",
                  SDL_GetPixelFormatName(pixel_format),
                  SDL_BITSPERPIXEL(pixel_format));
        Reset_Video_Mode();
        return false;
    }

    DBG_INFO("  pixel format: %s (%d bpp)", SDL_GetPixelFormatName(pixel_format), SDL_BITSPERPIXEL(pixel_format));

    DBG_INFO("SDL2 drivers available: (user preference '%s')", Settings.Video.Driver.c_str());
    int renderer_index = -1;
    for (int i = 0; i < SDL_GetNumRenderDrivers(); i++) {
        SDL_RendererInfo info;
        if (SDL_GetRenderDriverInfo(i, &info) == 0) {
            if (Settings.Video.Driver.compare(info.name) == 0) {
                renderer_index = i;
            }

            DBG_INFO(" %s%s", info.name, (i == renderer_index ? " (selected)" : ""));
        }
    }

    Uint32 renderer_flags = SDL_RENDERER_TARGETTEXTURE;
#ifdef TIBERIAN_DAWN_APPLE_PORT
    renderer_flags |= SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC;
#endif
    renderer = SDL_CreateRenderer(window, renderer_index, renderer_flags);
    if (renderer == nullptr) {
        DBG_ERROR("SDL_CreateRenderer failed: %s", SDL_GetError());
        Reset_Video_Mode();
        return false;
    }

    SDL_RendererInfo info;
    if (SDL_GetRendererInfo(renderer, &info) != 0) {
        DBG_ERROR("SDL_GetRendererInfo failed: %s", SDL_GetError());
        Reset_Video_Mode();
        return false;
    }

    DBG_INFO("Initialized SDL2 driver '%s'", info.name);
#ifdef TIBERIAN_DAWN_APPLE_PORT
    Discover_Modern_Art_Pack();
#endif
    DBG_INFO("  flags:");
    if (info.flags & SDL_RENDERER_SOFTWARE) {
        DBG_INFO("    SDL_RENDERER_SOFTWARE");
    }
    if (info.flags & SDL_RENDERER_ACCELERATED) {
        DBG_INFO("    SDL_RENDERER_ACCELERATED");
    }
    if (info.flags & SDL_RENDERER_PRESENTVSYNC) {
        DBG_INFO("    SDL_RENDERER_PRESENT_VSYNC");
    }
    if (info.flags & SDL_RENDERER_TARGETTEXTURE) {
        DBG_INFO("    SDL_RENDERER_TARGETTEXTURE");
    }

    DBG_INFO("  max texture size: %dx%d", info.max_texture_width, info.max_texture_height);

    DBG_INFO("  %d texture formats supported: (user preference '%s')",
             info.num_texture_formats,
             SDL_GetPixelFormatName(requested_pixel_format));

    /*
    ** Pick the first pixel format or the user requested one. It better be RGB.
    */
    pixel_format = SDL_PIXELFORMAT_UNKNOWN;
    for (int i = 0; i < info.num_texture_formats; i++) {
        if ((pixel_format == SDL_PIXELFORMAT_UNKNOWN && i == 0) || info.texture_formats[i] == requested_pixel_format) {
            pixel_format = info.texture_formats[i];
        }
    }

    for (int i = 0; i < info.num_texture_formats; i++) {
        DBG_INFO("    %s%s",
                 SDL_GetPixelFormatName(info.texture_formats[i]),
                 (pixel_format == info.texture_formats[i] ? " (selected)" : ""));
    }

    /*
    ** Set requested scaling algorithm.
    */
    if (!SDL_SetHintWithPriority(SDL_HINT_RENDER_SCALE_QUALITY, Settings.Video.Scaler.c_str(), SDL_HINT_OVERRIDE)) {
        DBG_WARN("  scaler '%s' is unsupported");
    } else {
        DBG_INFO("  scaler set to '%s'", Settings.Video.Scaler.c_str());
    }

    if (palette == nullptr) {
        palette = SDL_AllocPalette(256);
    }

    /*
    ** Set mouse scaling options.
    */
    hwcursor.GameW = w;
    hwcursor.GameH = h;
    hwcursor.X = w / 2;
    hwcursor.Y = h / 2;
    Update_HWCursor_Settings();

    /*
    ** Init gamepad.
    */
    if (Settings.Mouse.ControllerEnabled
#ifdef TIBERIAN_DAWN_APPLE_PORT
        || true
#endif
    ) {
#ifdef TIBERIAN_DAWN_APPLE_PORT
        Settings.Mouse.ControllerEnabled = true;
#endif
        SDL_Init(SDL_INIT_GAMECONTROLLER);
        Keyboard->Open_Controller();
    }

    return true;
}

void Toggle_Video_Fullscreen()
{
#ifdef IPADOS_PORT
    /* iPadOS owns window geometry, including Stage Manager full screen. */
    Refresh_Video_Layout();
    return;
#else
#ifdef MACOS_PORT
    // Preserve the user's manually resized window when entering full screen,
    // so Option-Return restores the exact previous size.
    if (Settings.Video.Windowed && window) {
        SDL_GetWindowSize(window, &Settings.Video.WindowWidth, &Settings.Video.WindowHeight);
    }
#endif
    Settings.Video.Windowed = !Settings.Video.Windowed;

    if (!Settings.Video.Windowed) {
        if (Settings.Video.Width == 0 || Settings.Video.Height == 0) {
            SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN_DESKTOP);
        } else {
            SDL_SetWindowSize(window, Settings.Video.Width, Settings.Video.Height);
            SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);
        }
    } else {
        SDL_SetWindowFullscreen(window, 0);
        SDL_SetWindowSize(window, Settings.Video.WindowWidth, Settings.Video.WindowHeight);
    }

    Update_HWCursor_Settings();
#endif
}

void Refresh_Video_Layout()
{
#ifdef TIBERIAN_DAWN_APPLE_PORT
    force_present = true;
#endif
    Update_HWCursor_Settings();
}

void Get_Video_Scale(float& x, float& y)
{
    x = hwcursor.ScaleX;
    y = hwcursor.ScaleY;
}

void Set_Video_Cursor_Clip(bool clipped)
{
    hwcursor.Clip = clipped;

    if (window) {
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
        /*
        ** Absolute pointer coordinates are used by both Apple ports. Pointer
        ** confinement conflicts with iPad windowing and prevents Mac users
        ** from reaching the title bar or resize handles during gameplay.
        */
        SDL_SetWindowGrab(window, SDL_FALSE);
        SDL_SetRelativeMouseMode(SDL_FALSE);
        return;
#else
        int relative;

        if (Settings.Video.Windowed) {
            SDL_SetWindowGrab(window, hwcursor.Clip ? SDL_TRUE : SDL_FALSE);
            relative = SDL_SetRelativeMouseMode(
                Settings.Mouse.ControllerEnabled || (Settings.Mouse.RawInput && hwcursor.Clip) ? SDL_TRUE : SDL_FALSE);

            /*
            ** When grabbing with raw input, move in-game cursor where the real cursor was and vice versa.
            */
            if (Settings.Mouse.RawInput) {
                if (hwcursor.Clip) {
                    int x, y;
                    SDL_GetMouseState(&x, &y);
                    hwcursor.X = x / hwcursor.ScaleX;
                    hwcursor.Y = y / hwcursor.ScaleY;
                } else {
                    SDL_WarpMouseInWindow(window, hwcursor.X * hwcursor.ScaleX, hwcursor.Y * hwcursor.ScaleY);
                }
            }
        } else {
            SDL_SetWindowGrab(window, SDL_TRUE);
            relative = SDL_SetRelativeMouseMode(Settings.Mouse.RawInput ? SDL_TRUE : SDL_FALSE);
        }

        if (relative < 0) {
            DBG_ERROR("Raw input not supported, disabling.");
            Settings.Mouse.RawInput = false;
        }
#endif
    }
}

void Move_Video_Mouse(float xrel, float yrel)
{
    if (Keyboard->Is_Gamepad_Active() || hwcursor.Clip || !Settings.Video.Windowed) {
        hwcursor.X += xrel * (Settings.Mouse.Sensitivity / 100.0f);
        hwcursor.Y += yrel * (Settings.Mouse.Sensitivity / 100.0f);
    }

    if (hwcursor.X >= hwcursor.GameW) {
        hwcursor.X = hwcursor.GameW - 1;
    } else if (hwcursor.X < 0) {
        hwcursor.X = 0;
    }

    if (hwcursor.Y >= hwcursor.GameH) {
        hwcursor.Y = hwcursor.GameH - 1;
    } else if (hwcursor.Y < 0) {
        hwcursor.Y = 0;
    }
}

void Get_Video_Mouse(int& x, int& y)
{
#ifdef IPADOS_PORT
    /* Touch and native visionOS gestures update the logical cursor directly.
     * SDL_GetMouseState remains at the last trackpad/pointer position when
     * touch-to-mouse synthesis is disabled. Reading it while a button is held
     * displaced the rubber-band rectangle from the finger and could leave the
     * classic tactical cursor stranded after a keyboard-dock transition. */
    x = hwcursor.X;
    y = hwcursor.Y;
#else
    if (Keyboard->Is_Gamepad_Active() || (Settings.Mouse.RawInput && (hwcursor.Clip || !Settings.Video.Windowed))) {
        x = hwcursor.X;
        y = hwcursor.Y;
    } else {
        int window_x = 0;
        int window_y = 0;
        SDL_GetMouseState(&window_x, &window_y);
#ifdef TIBERIAN_DAWN_APPLE_PORT
        Set_Video_Mouse_Window(window_x, window_y, x, y);
#else
        x = window_x / hwcursor.ScaleX;
        y = window_y / hwcursor.ScaleY;
#endif
    }
#endif
}

#ifdef TIBERIAN_DAWN_APPLE_PORT
// Updated only by the game thread between frames.
static float battlefield_zoom = 1.5f;
static int battlefield_right = 480, battlefield_top = 16;
void Video_Publish_Order_Icon(int kind) {
#ifdef IPADOS_PORT
    extern void WP_Publish_Order_Icon(int, const unsigned char*, int, int);
    if (!hwcursor.Raw || !palette) return;
    std::vector<unsigned char> rgba(hwcursor.W * hwcursor.H * 4);
    const unsigned char* pixels = (const unsigned char*)hwcursor.Raw;
    for (int i=0; i<hwcursor.W*hwcursor.H; ++i) {
        const SDL_Color c=palette->colors[pixels[i]];
        rgba[i*4]=c.r; rgba[i*4+1]=c.g; rgba[i*4+2]=c.b; rgba[i*4+3]=pixels[i]?255:0;
    }
    WP_Publish_Order_Icon(kind, rgba.data(), hwcursor.W, hwcursor.H);
#endif
}
float Video_Battlefield_Zoom() { return battlefield_active ? battlefield_zoom : 1.0f; }
void Video_Set_Battlefield(bool active, int right, int top, int view_width, int view_height, float zoom) {
    if (battlefield_active != active || battlefield_right != right || battlefield_top != top || battlefield_zoom!=zoom
        || battlefield_view_w!=view_width || battlefield_view_h!=view_height) force_present = true;
    battlefield_active = active; battlefield_right = right; battlefield_top = top;
    battlefield_view_w=view_width; battlefield_view_h=view_height; battlefield_zoom=zoom;
}
static void Unzoom_Battlefield_Point(int& x, int& y) {
    if (!battlefield_active) return;
    Map_Battlefield_Point(x,y,battlefield_right,battlefield_top,Presentation_Width(),hwcursor.GameW,battlefield_zoom);
}
static SDL_Rect Battlefield_Destination() {
    SDL_Rect result = render_dst;
    const float zoom = Video_Battlefield_Zoom();
    result.y += (int)std::lround(battlefield_top * (render_dst.h / float(Presentation_Height())) * (1 - zoom));
    result.w = (int)std::lround(result.w * zoom * hwcursor.GameW / Presentation_Width());
    result.h = (int)std::lround(result.h * zoom * hwcursor.GameH / Presentation_Height());
    return result;
}

void Video_Presentation_Size(int& width, int& height) { width=Presentation_Width(); height=Presentation_Height(); }

void Video_Adaptive_Size(int& width, int& height)
{
    Update_HWCursor_Settings(true);
    const int available_w = renderer_output_w - ipad_layout.safe_area.left - ipad_layout.safe_area.right;
    const int available_h = renderer_output_h - ipad_layout.safe_area.top - ipad_layout.safe_area.bottom;
    Calculate_Adaptive_Game_Size(available_w, available_h, width, height);
}

void Video_Set_Logical_Size(int width, int height)
{
    hwcursor.GameW = width; hwcursor.GameH = height;
    hwcursor.X = std::min(hwcursor.X, float(width - 1));
    hwcursor.Y = std::min(hwcursor.Y, float(height - 1));
    force_present = true;
    Update_HWCursor_Settings();
}

static void Set_Video_Mouse_Output(float pixel_x, float pixel_y, int& game_x, int& game_y)
{
    Map_IPad_Output_Point(ipad_layout, pixel_x, pixel_y, game_x, game_y);
    Unzoom_Battlefield_Point(game_x, game_y);
    hwcursor.X = game_x;
    hwcursor.Y = game_y;
}

void Set_Video_Mouse_Window(float window_x, float window_y, int& game_x, int& game_y)
{
    if (renderer_output_w <= 0 || renderer_output_h <= 0 || window_points_w <= 0 || window_points_h <= 0) {
        Refresh_Video_Layout();
    }

    Map_IPad_Window_Point(ipad_layout, window_x, window_y, game_x, game_y);
    Unzoom_Battlefield_Point(game_x, game_y);
    hwcursor.X = game_x;
    hwcursor.Y = game_y;
}

void Set_Video_Mouse_Normalized(float normalized_x, float normalized_y, int& game_x, int& game_y)
{
    if (renderer_output_w <= 0 || renderer_output_h <= 0) {
        Refresh_Video_Layout();
    }

    Map_IPad_Normalized_Point(ipad_layout, normalized_x, normalized_y, game_x, game_y);
    Unzoom_Battlefield_Point(game_x, game_y);
    hwcursor.X = game_x;
    hwcursor.Y = game_y;
}

int Video_Game_Pixels_For_Window_Points(float points)
{
    if (renderer_output_w <= 0 || renderer_output_h <= 0 || window_points_w <= 0 || window_points_h <= 0) {
        Refresh_Video_Layout();
    }
    return std::max(1, (int)std::ceil(IPad_Game_Pixels_For_Window_Points(ipad_layout, points) / Video_Battlefield_Zoom()));
}
#endif

/***********************************************************************************************
 * Reset_Video_Mode -- Resets video mode and deletes Direct Draw Object                        *
 *                                                                                             *
 * INPUT:		none                                                                            *
 *                                                                                             *
 * OUTPUT:     none                                                                            *
 *                                                                                             *
 * WARNINGS:                                                                                   *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *   09/26/1995 PWG : Created.                                                                 *
 *=============================================================================================*/
void Reset_Video_Mode(void)
{
#ifdef TIBERIAN_DAWN_APPLE_PORT
    selection_overlays.clear();
    ++selection_generation;
    hd_buggies.clear();
    hd_infantry.clear();
    hd_buildings.clear();
    hd_artwork_clip = {0, 0, 0, 0};
    hd_world_artwork_visible = true;
    ++hd_buggy_generation;
#endif
    if (hwcursor.Pending) {
        SDL_FreeCursor(hwcursor.Pending);
        hwcursor.Pending = nullptr;
    }

    if (hwcursor.Current) {
        SDL_FreeCursor(hwcursor.Current);
        hwcursor.Current = nullptr;
    }

    if (hwcursor.Surface) {
        SDL_FreeSurface(hwcursor.Surface);
        hwcursor.Surface = nullptr;
    }

    SDL_DestroyRenderer(renderer);
    renderer = nullptr;

    SDL_FreePalette(palette);
    palette = nullptr;

    SDL_DestroyWindow(window);
    window = nullptr;

    Keyboard->Close_Controller();
}

static void Update_HWCursor()
{
    float scale_x = 1.0f;
    float scale_y = 1.0f;
    int scaled_w = hwcursor.W;
    int scaled_h = hwcursor.H;

    /*
    ** Pre-scale cursor *only* if we are not emulating a hw cursor.
    */
    if (Settings.Video.HardwareCursor) {
        scale_x = hwcursor.ScaleX;
        scale_y = hwcursor.ScaleY;
        scaled_w *= scale_x;
        scaled_h *= scale_y;
    }

    /*
    ** Allocate or reallocate surface if it has the wrong size.
    */
    if (hwcursor.Surface == nullptr || hwcursor.Surface->w != scaled_w || hwcursor.Surface->h != scaled_h) {
        if (hwcursor.Surface) {
            SDL_FreeSurface(hwcursor.Surface);
        }

        /*
        ** Real HW cursor needs to be scaled up. Emulated can use original cursor data.
        */
        if (Settings.Video.HardwareCursor) {
            hwcursor.Surface = SDL_CreateRGBSurfaceWithFormat(0, scaled_w, scaled_h, 8, SDL_PIXELFORMAT_INDEX8);
        } else {
            hwcursor.Surface =
                SDL_CreateRGBSurfaceFrom(hwcursor.Raw, hwcursor.W, hwcursor.H, 8, hwcursor.W, 0, 0, 0, 0);
        }

        SDL_SetSurfacePalette(hwcursor.Surface, palette);
        SDL_SetColorKey(hwcursor.Surface, SDL_TRUE, 0);
    }

    /*
    ** Prepare HW cursor by scaling up and creating the SDL version.
    */
    if (Settings.Video.HardwareCursor) {
        uint8_t* src = (uint8_t*)hwcursor.Raw;
        uint8_t* dst = (uint8_t*)hwcursor.Surface->pixels;
        int src_pitch = hwcursor.W;
        int dst_pitch = hwcursor.Surface->pitch;

        for (int y = 0; y < scaled_h; y++) {
            for (int x = 0; x < scaled_w; x++) {
                dst[dst_pitch * y + x] = src[src_pitch * (int)(y / scale_y) + (int)(x / scale_x)];
            }
        }

        if (hwcursor.Pending) {
            SDL_FreeCursor(hwcursor.Pending);
        }

        /*
        ** Queue new cursor to be set during frame flip.
        */
        hwcursor.Pending =
            SDL_CreateColorCursor(hwcursor.Surface, hwcursor.HotX * hwcursor.ScaleX, hwcursor.HotY * hwcursor.ScaleY);
    }
}

void Set_Video_Cursor(void* cursor, int w, int h, int hotx, int hoty)
{
    hwcursor.Raw = cursor;
    hwcursor.W = w;
    hwcursor.H = h;
    hwcursor.HotX = hotx;
    hwcursor.HotY = hoty;

#ifdef TIBERIAN_DAWN_APPLE_PORT
    ++cursor_generation;
    force_present = true;
#endif

    Update_HWCursor();
}

#ifdef TIBERIAN_DAWN_APPLE_PORT
void Video_Set_Cursor_Kind(int kind)
{
    const int normalized = kind == 1 ? 1 : 0;
    if (cursor_kind == normalized) return;
    cursor_kind = normalized;
    ++cursor_generation;
    force_present = true;
}
#endif

/***********************************************************************************************
 * Get_Free_Video_Memory -- returns amount of free video memory                                *
 *                                                                                             *
 *                                                                                             *
 *                                                                                             *
 * INPUT:    Nothing                                                                           *
 *                                                                                             *
 * OUTPUT:   bytes of available video RAM                                                      *
 *                                                                                             *
 * WARNINGS: None                                                                              *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *    11/29/95 12:52PM ST : Created                                                            *
 *=============================================================================================*/
unsigned int Get_Free_Video_Memory(void)
{
    return 1000000000;
}

/***********************************************************************************************
 * Get_Video_Hardware_Caps -- returns bitmask of direct draw video hardware support            *
 *                                                                                             *
 *                                                                                             *
 *                                                                                             *
 * INPUT:    Nothing                                                                           *
 *                                                                                             *
 * OUTPUT:   hardware flags                                                                    *
 *                                                                                             *
 * WARNINGS: Must call Set_Video_Mode 1st to create the direct draw object                     *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *    1/12/96 9:14AM ST : Created                                                              *
 *=============================================================================================*/
unsigned Get_Video_Hardware_Capabilities(void)
{
    return VIDEO_BLITTER;
}

/***********************************************************************************************
 * Wait_Vert_Blank -- Waits for the start (leading edge) of a vertical blank                   *
 *                                                                                             *
 * INPUT:                                                                                      *
 *                                                                                             *
 * OUTPUT:                                                                                     *
 *                                                                                             *
 * WARNINGS:                                                                                   *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *=============================================================================================*/
void Wait_Vert_Blank(void)
{
}

/***********************************************************************************************
 * Set_Palette -- set a direct draw palette                                                    *
 *                                                                                             *
 *                                                                                             *
 *                                                                                             *
 * INPUT:    ptr to 768 rgb palette bytes                                                      *
 *                                                                                             *
 * OUTPUT:   Nothing                                                                           *
 *                                                                                             *
 * WARNINGS: None                                                                              *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *    10/11/95 3:33PM ST : Created                                                             *
 *=============================================================================================*/
void Set_DD_Palette(void* rpalette)
{
#ifdef TIBERIAN_DAWN_APPLE_PORT
    if (has_previous_palette && std::memcmp(previous_palette, rpalette, sizeof(previous_palette)) == 0) {
        return;
    }
    std::memcpy(previous_palette, rpalette, sizeof(previous_palette));
    has_previous_palette = true;
#endif
    SDL_Color colors[256];

    unsigned char* rcolors = (unsigned char*)rpalette;
    for (int i = 0; i < 256; i++) {
        colors[i].r = (unsigned char)rcolors[i * 3] << 2;
        colors[i].g = (unsigned char)rcolors[i * 3 + 1] << 2;
        colors[i].b = (unsigned char)rcolors[i * 3 + 2] << 2;
        colors[i].a = 0xFF;
    }

    /*
    ** First color is transparent. This needs to be set so that hardware cursor has transparent
    ** surroundings when converting from 8-bit to 32-bit.
    */
    colors[0].a = 0;

    SDL_SetPaletteColors(palette, colors, 0, 256);

#ifdef TIBERIAN_DAWN_APPLE_PORT
    ++palette_generation;
    force_present = true;
#endif

    /*
    ** Cursor needs to be updated when palette changes.
    */
    Update_HWCursor();
}

/***********************************************************************************************
 * Wait_Blit -- waits for the DirectDraw blitter to become idle                                *
 *                                                                                             *
 *                                                                                             *
 *                                                                                             *
 * INPUT:    Nothing                                                                           *
 *                                                                                             *
 * OUTPUT:   Nothing                                                                           *
 *                                                                                             *
 * WARNINGS: None                                                                              *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *   07-25-95 03:53pm ST : Created                                                             *
 *=============================================================================================*/

void Wait_Blit(void)
{
}

/***********************************************************************************************
 * SMC::SurfaceMonitorClass -- constructor for surface monitor class                           *
 *                                                                                             *
 *                                                                                             *
 *                                                                                             *
 * INPUT:    Nothing                                                                           *
 *                                                                                             *
 * OUTPUT:   Nothing                                                                           *
 *                                                                                             *
 * WARNINGS: None                                                                              *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *    11/3/95 3:23PM ST : Created                                                              *
 *=============================================================================================*/

SurfaceMonitorClass::SurfaceMonitorClass()
{
    SurfacesRestored = false;
}

/*
** VideoSurfaceDDraw
*/
class VideoSurfaceSDL2;
static VideoSurfaceSDL2* frontSurface = nullptr;

class VideoSurfaceSDL2 : public VideoSurface
{
public:
    VideoSurfaceSDL2(int w, int h, GBC_Enum flags)
        : flags(flags)
        , windowSurface(nullptr)
        , texture(nullptr)
#ifdef TIBERIAN_DAWN_APPLE_PORT
        , lastPaletteGeneration(0)
        , lastCursorGeneration(0)
        , lastSelectionGeneration(0)
        , lastHDBuggyGeneration(0)
        , lastTouchFeedbackGeneration(0)
        , lastTouchSelectionGeneration(0)
        , lastCursorX(-1)
        , lastCursorY(-1)
        , hadSoftwareCursor(false)
        , hasLastFrame(false)
        , paletteRenderer(nullptr)
#endif
    {
        surface = SDL_CreateRGBSurface(0, w, h, 8, 0, 0, 0, 0);
        SDL_SetSurfacePalette(surface, palette);

        if (flags & GBC_VISIBLE) {
            windowSurface = SDL_CreateRGBSurfaceWithFormat(0, w, h, SDL_BITSPERPIXEL(pixel_format), pixel_format);
            texture = SDL_CreateTexture(renderer, windowSurface->format->format, SDL_TEXTUREACCESS_STREAMING, w, h);
#ifdef TIBERIAN_DAWN_APPLE_PORT
            const std::string modern_cursor_path = Modern_Cursor_Path();
            const std::string buggy_atlas_path = Modern_Buggy_Atlas_Path();
            const std::string humvee_atlas_path = Modern_Humvee_Atlas_Path();
            const std::string minigunner_atlas_path = Modern_Minigunner_Atlas_Path();
            const std::string gdi_mcv_atlas_path = Modern_GDI_MCV_Atlas_Path();
            const std::string nod_mcv_atlas_path = Modern_Nod_MCV_Atlas_Path();
            const std::string gdi_infrastructure_atlas_path = Modern_GDI_Infrastructure_Atlas_Path();
            const std::string nod_infrastructure_atlas_path = Modern_Nod_Infrastructure_Atlas_Path();
            const std::string gdi_infrastructure_activity_atlas_path =
                Modern_GDI_Infrastructure_Activity_Atlas_Path();
            const std::string nod_infrastructure_activity_atlas_path =
                Modern_Nod_Infrastructure_Activity_Atlas_Path();
            paletteRenderer = IPad_Palette_Create(renderer,
                                                  w,
                                                  h,
                                                  modern_cursor_path.c_str(),
                                                  buggy_atlas_path.c_str(),
                                                  humvee_atlas_path.c_str(),
                                                  minigunner_atlas_path.c_str(),
                                                  gdi_mcv_atlas_path.c_str(),
                                                  nod_mcv_atlas_path.c_str(),
                                                  gdi_infrastructure_atlas_path.c_str(),
                                                  nod_infrastructure_atlas_path.c_str(),
                                                  gdi_infrastructure_activity_atlas_path.c_str(),
                                                  nod_infrastructure_activity_atlas_path.c_str(),
                                                  Modern_Asset_Scale());
            hd_buggy_renderer_available = IPad_Palette_Has_Buggy_Artwork(paletteRenderer);
            hd_humvee_renderer_available = IPad_Palette_Has_Humvee_Artwork(paletteRenderer);
            hd_minigunner_renderer_available = IPad_Palette_Has_Minigunner_Artwork(paletteRenderer);
            hd_gdi_mcv_renderer_available = IPad_Palette_Has_GDI_MCV_Artwork(paletteRenderer);
            hd_nod_mcv_renderer_available = IPad_Palette_Has_Nod_MCV_Artwork(paletteRenderer);
            hd_gdi_infrastructure_renderer_available = IPad_Palette_Has_GDI_Infrastructure_Artwork(paletteRenderer);
            hd_nod_infrastructure_renderer_available = IPad_Palette_Has_Nod_Infrastructure_Artwork(paletteRenderer);
            hd_gdi_infrastructure_activity_renderer_available =
                IPad_Palette_Has_GDI_Infrastructure_Activity_Artwork(paletteRenderer);
            hd_nod_infrastructure_activity_renderer_available =
                IPad_Palette_Has_Nod_Infrastructure_Activity_Artwork(paletteRenderer);
#endif
            frontSurface = this;
        }
    }

    virtual ~VideoSurfaceSDL2()
    {
        if (frontSurface == this) {
            frontSurface = nullptr;
#ifdef TIBERIAN_DAWN_APPLE_PORT
            hd_buggy_renderer_available = false;
            hd_humvee_renderer_available = false;
            hd_minigunner_renderer_available = false;
            hd_gdi_mcv_renderer_available = false;
            hd_nod_mcv_renderer_available = false;
            hd_gdi_infrastructure_renderer_available = false;
            hd_nod_infrastructure_renderer_available = false;
            hd_gdi_infrastructure_activity_renderer_available = false;
            hd_nod_infrastructure_activity_renderer_available = false;
#endif
        }

#ifdef TIBERIAN_DAWN_APPLE_PORT
        IPad_Palette_Destroy(paletteRenderer);
        paletteRenderer = nullptr;
#endif

        SDL_FreeSurface(surface);

        if (texture) {
            SDL_DestroyTexture(texture);
        }

        if (windowSurface) {
            SDL_FreeSurface(windowSurface);
        }
    }

    virtual void* GetData() const
    {
        return surface->pixels;
    }
    virtual int GetPitch() const
    {
        return surface->pitch;
    }
    virtual bool IsAllocated() const
    {
        return false;
    }

    virtual void AddAttachedSurface(VideoSurface* surface)
    {
    }

    virtual bool IsReadyToBlit()
    {
        return true;
    }

    virtual bool LockWait()
    {
        return (SDL_LockSurface(surface) == 0);
    }

    virtual bool Unlock()
    {
        SDL_UnlockSurface(surface);
        return true;
    }

    virtual void Blt(const Rect& destRect, VideoSurface* src, const Rect& srcRect, bool mask)
    {
        SDL_BlitSurface(((VideoSurfaceSDL2*)src)->surface, (SDL_Rect*)(&srcRect), surface, (SDL_Rect*)&destRect);
    }

    virtual void FillRect(const Rect& rect, unsigned char color)
    {
        SDL_Rect rectSDL = {rect.X, rect.Y, rect.Width + 1, rect.Height + 1};
        SDL_FillRect(surface, &rectSDL, color);
    }

    bool RenderSurface()
    {
        void* pixels;
        int pitch;

#ifdef TIBERIAN_DAWN_APPLE_PORT
        ++telemetry.attempts;
        Update_Power_State();
        if (touch_feedback.active
            && static_cast<Sint32>(SDL_GetTicks() - touch_feedback.expires_at) >= 0) {
            touch_feedback.active = false;
            ++touch_feedback.generation;
        }

        const Uint32 window_flags = window ? SDL_GetWindowFlags(window) : 0;
        const bool drawable = render_active && Is_App_In_Foreground() && window != nullptr && renderer != nullptr
                              && (window_flags & (SDL_WINDOW_HIDDEN | SDL_WINDOW_MINIMIZED)) == 0;
        if (!drawable) {
            ++telemetry.inactive_skips;
            last_frame_idle = true;
            Report_Telemetry_If_Due();
            return false;
        }

        // UIKit/Metal drawable geometry may settle after the SDL resize event
        // during rotation, folding or window resizing. Refresh before deriving
        // any rendering or input coordinates, including otherwise idle frames.
        Update_HWCursor_Settings(true);

        int cursor_x = -1;
        int cursor_y = -1;
        const bool software_cursor = !touch_input_active && !Settings.Video.HardwareCursor
                                     && !Get_Mouse_State() && hwcursor.Surface != nullptr;
        if (software_cursor) {
            Get_Video_Mouse(cursor_x, cursor_y);
        }

        IPadPaletteRect indexed_update = {0, 0, surface->w, surface->h};
        bool indexed_pixels_changed = !hasLastFrame;
        if (hasLastFrame) {
            int left = surface->w;
            int top = surface->h;
            int right = -1;
            int bottom = -1;
            for (int y = 0; y < surface->h; ++y) {
                const Uint8* row = static_cast<const Uint8*>(surface->pixels) + y * surface->pitch;
                const Uint8* previous = &lastIndexedPixels[y * surface->w];
                if (std::memcmp(row, previous, surface->w) == 0) continue;

                int row_left = 0;
                while (row_left < surface->w && row[row_left] == previous[row_left]) ++row_left;
                int row_right = surface->w - 1;
                while (row_right > row_left && row[row_right] == previous[row_right]) --row_right;
                left = std::min(left, row_left);
                top = std::min(top, y);
                right = std::max(right, row_right);
                bottom = y;
            }
            indexed_pixels_changed = right >= left && bottom >= top;
            indexed_update = indexed_pixels_changed
                                 ? IPadPaletteRect{left, top, right - left + 1, bottom - top + 1}
                                 : IPadPaletteRect{0, 0, 0, 0};
        }

        const bool visible_change = force_present || indexed_pixels_changed
                                    || lastPaletteGeneration != palette_generation
                                    || lastCursorGeneration != cursor_generation
                                    || lastSelectionGeneration != selection_generation
                                    || lastHDBuggyGeneration != hd_buggy_generation
                                    || lastTouchFeedbackGeneration != touch_feedback.generation
                                    || lastTouchSelectionGeneration != touch_selection_box.generation
                                    || hadSoftwareCursor != software_cursor || lastCursorX != cursor_x
                                    || lastCursorY != cursor_y;
        if (!visible_change) {
            ++telemetry.unchanged_skips;
            last_frame_idle = true;
            Report_Telemetry_If_Due();
            return false;
        }

        if (indexed_pixels_changed) {
            lastIndexedPixels.resize(surface->w * surface->h);
            for (int y = indexed_update.y; y < indexed_update.y + indexed_update.height; ++y) {
                const Uint8* row = static_cast<const Uint8*>(surface->pixels) + y * surface->pitch;
                std::memcpy(&lastIndexedPixels[y * surface->w + indexed_update.x],
                            row + indexed_update.x,
                            indexed_update.width);
            }
        }
#endif

        bool metal_rendered = false;
#ifdef TIBERIAN_DAWN_APPLE_PORT
        const SDL_Rect base_destination = render_dst;
        render_dst = Battlefield_Destination();
        IPadPaletteCursor metal_cursor = {};
        std::vector<IPadSelectionOverlay> metal_selections;
        std::vector<IPadHDBuildingOverlay> metal_buildings;
        std::vector<IPadHDBuggyOverlay> metal_buggies;
        std::vector<IPadHDInfantryOverlay> metal_infantry;
        if (Settings.Video.ArtworkMode != 0 && !hd_buildings.empty()) {
            const float scale_x = render_dst.w / static_cast<float>(surface->w);
            const float scale_y = render_dst.h / static_cast<float>(surface->h);
            std::vector<RegisteredHDBuilding> sorted_buildings = hd_buildings;
            std::stable_sort(sorted_buildings.begin(),
                             sorted_buildings.end(),
                             [](const RegisteredHDBuilding& first, const RegisteredHDBuilding& second) {
                                 return first.center_y < second.center_y;
                             });
            metal_buildings.reserve(sorted_buildings.size());
            for (const RegisteredHDBuilding& registered : sorted_buildings) {
                const int half_width = registered.width / 2;
                const int half_height = registered.height / 2;
                const int left = render_dst.x
                                 + static_cast<int>(std::lround((registered.center_x - half_width) * scale_x));
                const int top = render_dst.y
                                + static_cast<int>(std::lround((registered.center_y - half_height) * scale_y));
                const int right = render_dst.x
                                  + static_cast<int>(std::lround((registered.center_x
                                                                  + registered.width - half_width) * scale_x));
                const int bottom = render_dst.y
                                   + static_cast<int>(std::lround((registered.center_y
                                                                   + registered.height - half_height) * scale_y));
                const int health_left = render_dst.x
                                        + static_cast<int>(std::lround(registered.health_x * scale_x));
                const int health_top = render_dst.y
                                       + static_cast<int>(std::lround(registered.health_y * scale_y));
                const int health_right = render_dst.x
                                         + static_cast<int>(std::lround((registered.health_x
                                                                         + registered.health_width) * scale_x));
                const int health_bottom = render_dst.y
                                          + static_cast<int>(std::lround((registered.health_y + 4) * scale_y));
                IPadHDBuildingOverlay overlay;
                overlay.destination = {left, top, std::max(1, right - left), std::max(1, bottom - top)};
                overlay.health_destination = {health_left,
                                              health_top,
                                              std::max(1, health_right - health_left),
                                              std::max(1, health_bottom - health_top)};
                overlay.frame = registered.frame;
                overlay.activity_frame = registered.activity_frame;
                overlay.health_fill_width = std::max(
                    0,
                    static_cast<int>(std::lround(registered.health_fill_width * scale_x)));
                overlay.completion = registered.completion;
                overlay.damage = registered.damage;
                overlay.palette_index = registered.palette_index;
                overlay.health_palette_index = registered.health_palette_index;
                overlay.health_visible = registered.health_visible;
                overlay.repairing = registered.repairing;
                overlay.faction_kind = registered.faction_kind;
                metal_buildings.push_back(overlay);
            }
        }
        if (Settings.Video.ArtworkMode != 0 && !hd_buggies.empty()) {
            const float scale_x = render_dst.w / static_cast<float>(surface->w);
            const float scale_y = render_dst.h / static_cast<float>(surface->h);
            std::vector<RegisteredHDBuggy> sorted_buggies = hd_buggies;
            std::stable_sort(sorted_buggies.begin(), sorted_buggies.end(), [](const RegisteredHDBuggy& first,
                                                                             const RegisteredHDBuggy& second) {
                return first.body_y < second.body_y;
            });
            metal_buggies.reserve(sorted_buggies.size());
            for (const RegisteredHDBuggy& registered : sorted_buggies) {
                const auto destination = [&](int center_x, int center_y) {
                    const int half_size = registered.atlas_kind >= 2 ? 16 : 12;
                    const int left = render_dst.x
                                     + static_cast<int>(std::lround((center_x - half_size) * scale_x));
                    const int top = render_dst.y
                                    + static_cast<int>(std::lround((center_y - half_size) * scale_y));
                    const int right = render_dst.x
                                      + static_cast<int>(std::lround((center_x + half_size) * scale_x));
                    const int bottom = render_dst.y
                                       + static_cast<int>(std::lround((center_y + half_size) * scale_y));
                    return IPadPaletteRect{left, top, std::max(1, right - left), std::max(1, bottom - top)};
                };
                IPadHDBuggyOverlay overlay;
                overlay.body_destination = destination(registered.body_x, registered.body_y);
                overlay.turret_destination = destination(registered.turret_x, registered.turret_y);
                const int health_left = render_dst.x
                                        + static_cast<int>(std::lround(registered.health_x * scale_x));
                const int health_top = render_dst.y
                                       + static_cast<int>(std::lround(registered.health_y * scale_y));
                const int health_right = render_dst.x
                                         + static_cast<int>(std::lround((registered.health_x
                                                                         + registered.health_width) * scale_x));
                const int health_bottom = render_dst.y
                                          + static_cast<int>(std::lround((registered.health_y + 4) * scale_y));
                overlay.health_destination = {health_left,
                                              health_top,
                                              std::max(1, health_right - health_left),
                                              std::max(1, health_bottom - health_top)};
                overlay.body_frame = registered.body_frame;
                overlay.turret_frame = registered.turret_frame;
                overlay.health_fill_width = std::max(
                    0,
                    static_cast<int>(std::lround(registered.health_fill_width * scale_x)));
                overlay.palette_index = registered.palette_index;
                overlay.health_palette_index = registered.health_palette_index;
                overlay.health_visible = registered.health_visible;
                overlay.atlas_kind = registered.atlas_kind;
                metal_buggies.push_back(overlay);
            }
        }
        if (Settings.Video.ArtworkMode != 0 && !hd_infantry.empty()) {
            const float scale_x = render_dst.w / static_cast<float>(surface->w);
            const float scale_y = render_dst.h / static_cast<float>(surface->h);
            std::vector<RegisteredHDInfantry> sorted_infantry = hd_infantry;
            std::stable_sort(sorted_infantry.begin(),
                             sorted_infantry.end(),
                             [](const RegisteredHDInfantry& first, const RegisteredHDInfantry& second) {
                                 return first.center_y < second.center_y;
                             });
            metal_infantry.reserve(sorted_infantry.size());
            for (const RegisteredHDInfantry& registered : sorted_infantry) {
                const int left = render_dst.x
                                 + static_cast<int>(std::lround((registered.center_x - 12) * scale_x));
                const int top = render_dst.y
                                + static_cast<int>(std::lround((registered.center_y - 12) * scale_y));
                const int right = render_dst.x
                                  + static_cast<int>(std::lround((registered.center_x + 12) * scale_x));
                const int bottom = render_dst.y
                                   + static_cast<int>(std::lround((registered.center_y + 12) * scale_y));
                const int health_left = render_dst.x
                                        + static_cast<int>(std::lround(registered.health_x * scale_x));
                const int health_top = render_dst.y
                                       + static_cast<int>(std::lround(registered.health_y * scale_y));
                const int health_right = render_dst.x
                                         + static_cast<int>(std::lround((registered.health_x
                                                                         + registered.health_width) * scale_x));
                const int health_bottom = render_dst.y
                                          + static_cast<int>(std::lround((registered.health_y + 4) * scale_y));
                IPadHDInfantryOverlay overlay;
                overlay.destination = {left, top, std::max(1, right - left), std::max(1, bottom - top)};
                overlay.health_destination = {health_left,
                                              health_top,
                                              std::max(1, health_right - health_left),
                                              std::max(1, health_bottom - health_top)};
                overlay.frame = registered.frame;
                overlay.health_fill_width = std::max(
                    0,
                    static_cast<int>(std::lround(registered.health_fill_width * scale_x)));
                overlay.palette_index = registered.palette_index;
                overlay.health_palette_index = registered.health_palette_index;
                overlay.health_visible = registered.health_visible;
                metal_infantry.push_back(overlay);
            }
        }
        if (hd_world_artwork_visible && Settings.Video.ArtworkMode != 0 && !selection_overlays.empty()) {
            const float scale_x = render_dst.w / static_cast<float>(surface->w);
            const float scale_y = render_dst.h / static_cast<float>(surface->h);
            metal_selections.reserve(selection_overlays.size());
            for (const RegisteredSelectionOverlay& registered : selection_overlays) {
                const int left = render_dst.x + static_cast<int>(std::lround(registered.logical.x * scale_x));
                const int top = render_dst.y + static_cast<int>(std::lround(registered.logical.y * scale_y));
                const int right = render_dst.x
                                  + static_cast<int>(std::lround((registered.logical.x
                                                                  + registered.logical.width) * scale_x));
                const int bottom = render_dst.y
                                   + static_cast<int>(std::lround((registered.logical.y
                                                                   + registered.logical.height) * scale_y));
                IPadSelectionOverlay overlay = {{left,
                                                 top,
                                                 std::max(1, right - left),
                                                 std::max(1, bottom - top)},
                                                registered.palette_index};
                metal_selections.push_back(overlay);
            }
        }
        render_dst = base_destination;
        if (software_cursor) {
            const float cursor_scale = Settings.Video.LargeCursor ? 2.5f : 1.0f;
            const bool cursor_world=battlefield_active && cursor_y>=battlefield_top && cursor_x<(hwcursor.GameW-(Presentation_Width()-battlefield_right));
            const int cursor_padding=battlefield_active && !cursor_world && cursor_x>=hwcursor.GameW-320 ? hwcursor.GameW-Presentation_Width():0;
            const int game_x = cursor_x - static_cast<int>(hwcursor.HotX * cursor_scale);
            const int game_y = cursor_y - static_cast<int>(hwcursor.HotY * cursor_scale);
            metal_cursor.pixels = hwcursor.Surface->pixels;
            metal_cursor.pitch = hwcursor.Surface->pitch;
            metal_cursor.width = hwcursor.Surface->w;
            metal_cursor.height = hwcursor.Surface->h;
            metal_cursor.hotspot_x = hwcursor.HotX;
            metal_cursor.hotspot_y = hwcursor.HotY;
            metal_cursor.kind = cursor_kind;
            metal_cursor.destination.x = render_dst.x + static_cast<int>((game_x-cursor_padding) * render_dst.w / float(Presentation_Width()));
            metal_cursor.destination.y = render_dst.y + static_cast<int>(game_y * render_dst.h / float(Presentation_Height()));
            metal_cursor.destination.width = std::max(1, static_cast<int>(hwcursor.Surface->w * cursor_scale * render_dst.w / float(Presentation_Width())));
            metal_cursor.destination.height = std::max(1, static_cast<int>(hwcursor.Surface->h * cursor_scale * render_dst.h / float(Presentation_Height())));
            if (cursor_world) {
                const SDL_Rect world = Battlefield_Destination();
                metal_cursor.destination.x = world.x + (int)std::lround(game_x * world.w / float(surface->w));
                metal_cursor.destination.y = world.y + (int)std::lround(game_y * world.h / float(surface->h));
                metal_cursor.destination.width = (int)std::lround(metal_cursor.destination.width * battlefield_zoom);
                metal_cursor.destination.height = (int)std::lround(metal_cursor.destination.height * battlefield_zoom);
            }
            metal_cursor.visible = true;
            metal_cursor.pixels_changed = lastCursorGeneration != cursor_generation || !hadSoftwareCursor;
        }

        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
        if (paletteRenderer) {
            const IPadPaletteRect viewport = {render_dst.x, render_dst.y, render_dst.w, render_dst.h};
            IPadPaletteRect world_clip = viewport;
            if (hd_artwork_clip.width > 0 && hd_artwork_clip.height > 0) {
                const float scale_x = render_dst.w / static_cast<float>(surface->w);
                const float scale_y = render_dst.h / static_cast<float>(surface->h);
                const int clip_left = std::max(
                    viewport.x,
                    render_dst.x + static_cast<int>(std::lround(hd_artwork_clip.x * scale_x)));
                const int clip_top = std::max(
                    viewport.y,
                    render_dst.y + static_cast<int>(std::lround(hd_artwork_clip.y * scale_y)));
                const int clip_right = std::min(
                    viewport.x + viewport.width,
                    render_dst.x
                        + static_cast<int>(std::lround((hd_artwork_clip.x + hd_artwork_clip.width) * scale_x)));
                const int clip_bottom = std::min(
                    viewport.y + viewport.height,
                    render_dst.y
                        + static_cast<int>(std::lround((hd_artwork_clip.y + hd_artwork_clip.height) * scale_y)));
                world_clip = {clip_left,
                              clip_top,
                              std::max(0, clip_right - clip_left),
                              std::max(0, clip_bottom - clip_top)};
            }
            if (battlefield_active) {
                const float sx = render_dst.w / float(Presentation_Width()), sy = render_dst.h / float(Presentation_Height());
                world_clip = {render_dst.x, render_dst.y + (int)std::lround(battlefield_top * sy),
                    (int)std::lround(battlefield_right * sx), render_dst.h - (int)std::lround(battlefield_top * sy)};
            }
            metal_rendered = IPad_Palette_Render(paletteRenderer,
                                                renderer,
                                                surface->pixels,
                                                surface->pitch,
                                                indexed_pixels_changed,
                                                indexed_update,
                                                previous_palette,
                                                lastPaletteGeneration != palette_generation,
                                                Settings.Video.PresentationMode,
                                                Settings.Video.ArtworkMode,
                                                viewport,
                                                world_clip,
                                                metal_buildings.empty() ? nullptr : metal_buildings.data(),
                                                static_cast<int>(metal_buildings.size()),
                                                metal_buggies.empty() ? nullptr : metal_buggies.data(),
                                                static_cast<int>(metal_buggies.size()),
                                                metal_infantry.empty() ? nullptr : metal_infantry.data(),
                                                static_cast<int>(metal_infantry.size()),
                                                metal_selections.empty() ? nullptr : metal_selections.data(),
                                                static_cast<int>(metal_selections.size()),
                                                metal_cursor,
                                                Video_Battlefield_Zoom(),
                                                battlefield_active ? battlefield_right : 0,
                                                battlefield_top, Presentation_Width(), Presentation_Height());
        }
#endif

        if (!metal_rendered) {
            SDL_BlitSurface(surface, NULL, windowSurface, NULL);

            if (Settings.Video.HardwareCursor) {
                /*
                ** Swap cursor before a frame is drawn. This reduces flickering when it's done only once per frame.
                */
                if (hwcursor.Pending) {
                    SDL_SetCursor(hwcursor.Pending);

                    if (hwcursor.Current) {
                        SDL_FreeCursor(hwcursor.Current);
                    }

                    hwcursor.Current = hwcursor.Pending;
                    hwcursor.Pending = nullptr;
                }

                /*
                ** Update hardware cursor visibility.
                */
#ifdef TIBERIAN_DAWN_APPLE_PORT
                SDL_ShowCursor(!touch_input_active && !Get_Mouse_State());
#else
                SDL_ShowCursor(!Get_Mouse_State());
#endif
            } else if (!Get_Mouse_State() && hwcursor.Surface != nullptr) {
                /*
                ** Draw software emulated cursor.
                */
                int x, y;
                SDL_Rect dst;

                Get_Video_Mouse(x, y);

                const float cursor_scale = Settings.Video.LargeCursor ? 2.5f : 1.0f;
                dst.x = x - static_cast<int>(hwcursor.HotX * cursor_scale);
                dst.y = y - static_cast<int>(hwcursor.HotY * cursor_scale);
                dst.w = static_cast<int>(hwcursor.Surface->w * cursor_scale);
                dst.h = static_cast<int>(hwcursor.Surface->h * cursor_scale);

                if (Settings.Video.LargeCursor) {
                    SDL_BlitScaled(hwcursor.Surface, nullptr, windowSurface, &dst);
                } else {
                    SDL_BlitSurface(hwcursor.Surface, nullptr, windowSurface, &dst);
                }
            }

            SDL_UpdateTexture(texture, NULL, windowSurface->pixels, windowSurface->pitch);
            // Touch/Pencil feedback changes SDL's persistent renderer color. Set
            // the letterbox clear color explicitly every frame so a previous
            // yellow or blue feedback ring cannot tint newly exposed margins
            // after a Stage Manager resize.
            SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
            SDL_RenderClear(renderer);
            SDL_RenderCopy(renderer, texture, NULL, &render_dst);
#ifdef TIBERIAN_DAWN_APPLE_PORT
            if (battlefield_active) {
                const float sx=render_dst.w/float(Presentation_Width()), sy=render_dst.h/float(Presentation_Height());
                auto copyPiece=[&](SDL_Rect src,int x,int y,int w,int h) {
                    SDL_Rect dst={render_dst.x+(int)std::lround(x*sx),render_dst.y+(int)std::lround(y*sy),
                        (int)std::lround(w*sx),(int)std::lround(h*sy)};
                    SDL_RenderCopy(renderer,texture,&src,&dst);
                };
                copyPiece({0,battlefield_top,(int)std::ceil(battlefield_right/battlefield_zoom),
                    (int)std::ceil((Presentation_Height()-battlefield_top)/battlefield_zoom)},
                    0,battlefield_top,battlefield_right,Presentation_Height()-battlefield_top);
                const int sidebar=Presentation_Width()-battlefield_right;
                if (sidebar) copyPiece({surface->w-sidebar,battlefield_top,sidebar,Presentation_Height()-battlefield_top},
                    battlefield_right,battlefield_top,sidebar,Presentation_Height()-battlefield_top);
                copyPiece({0,0,Presentation_Width()-320,battlefield_top},0,0,Presentation_Width()-320,battlefield_top);
                copyPiece({surface->w-320,0,320,battlefield_top},Presentation_Width()-320,0,320,battlefield_top);
            }
#endif
        }
#ifdef TIBERIAN_DAWN_APPLE_PORT
        const SDL_Rect feedback_base = render_dst;
        render_dst = Battlefield_Destination();
        if (touch_selection_box.active) {
            const float scale_x = render_dst.w / static_cast<float>(hwcursor.GameW);
            const float scale_y = render_dst.h / static_cast<float>(hwcursor.GameH);
            const int left_game = std::min(touch_selection_box.x1, touch_selection_box.x2);
            const int top_game = std::min(touch_selection_box.y1, touch_selection_box.y2);
            const int right_game = std::max(touch_selection_box.x1, touch_selection_box.x2);
            const int bottom_game = std::max(touch_selection_box.y1, touch_selection_box.y2);
            SDL_Rect box = {
                render_dst.x + static_cast<int>(std::lround(left_game * scale_x)),
                render_dst.y + static_cast<int>(std::lround(top_game * scale_y)),
                std::max(1, static_cast<int>(std::lround((right_game - left_game) * scale_x))),
                std::max(1, static_cast<int>(std::lround((bottom_game - top_game) * scale_y))),
            };
            SDL_Rect selection_clip=feedback_base;
            if (battlefield_active) {
                selection_clip.y += (int)std::lround(battlefield_top * feedback_base.h / float(Presentation_Height()));
                selection_clip.h -= selection_clip.y-feedback_base.y;
                selection_clip.w = (int)std::lround(battlefield_right * feedback_base.w / float(Presentation_Width()));
            }
            SDL_RenderSetClipRect(renderer, &selection_clip);
            SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
            if (Settings.Video.HighContrast) {
                SDL_Rect shadow = {box.x - 2, box.y - 2, box.w + 4, box.h + 4};
                SDL_SetRenderDrawColor(renderer, 0, 0, 0, 230);
                SDL_RenderDrawRect(renderer, &shadow);
            }
            SDL_SetRenderDrawColor(renderer, 255, 255, 255, 245);
            SDL_RenderDrawRect(renderer, &box);
            if (box.w > 4 && box.h > 4) {
                SDL_Rect inner = {box.x + 2, box.y + 2, box.w - 4, box.h - 4};
                SDL_SetRenderDrawColor(renderer, 255, 220, 80, 230);
                SDL_RenderDrawRect(renderer, &inner);
            }
            SDL_RenderSetClipRect(renderer, nullptr);
        }
        render_dst = feedback_base;
        if (touch_feedback.active) {
            if (battlefield_active && touch_feedback.x < battlefield_right / battlefield_zoom && touch_feedback.y >= battlefield_top)
                render_dst = Battlefield_Destination();
            const bool on_world=battlefield_active && touch_feedback.x < battlefield_right/battlefield_zoom && touch_feedback.y>=battlefield_top;
            const float scale_x = render_dst.w / float(on_world?hwcursor.GameW:Presentation_Width());
            const float scale_y = render_dst.h / float(on_world?hwcursor.GameH:Presentation_Height());
            const int padding=battlefield_active && !on_world && touch_feedback.x>=hwcursor.GameW-320 ? hwcursor.GameW-Presentation_Width():0;
            const int center_x = render_dst.x + static_cast<int>((touch_feedback.x-padding) * scale_x);
            const int center_y = render_dst.y + static_cast<int>(touch_feedback.y * scale_y);
            // Touch feedback is separate from the legacy game cursor.
            // Increase its visible ring without shifting the actual touch position.
            const int radius = (touch_feedback.pencil ? 20 : 32) * Settings.Video.TouchUIScale / 100;
            SDL_Point ring[33];
            for (int i = 0; i <= 32; ++i) {
                const float angle = static_cast<float>(i) * 6.28318530718f / 32.0f;
                ring[i].x = center_x + static_cast<int>(std::cos(angle) * radius);
                ring[i].y = center_y + static_cast<int>(std::sin(angle) * radius);
            }
            if (touch_feedback.kind == TOUCH_FEEDBACK_ATTACK) {
                SDL_SetRenderDrawColor(renderer, 255, 70, 60, 235);
            } else if (touch_feedback.kind == TOUCH_FEEDBACK_MOVE) {
                SDL_SetRenderDrawColor(renderer, 70, 235, 110, 230);
            } else if (touch_feedback.pencil) {
                SDL_SetRenderDrawColor(renderer, 80, 210, 255, 220);
            } else {
                SDL_SetRenderDrawColor(renderer, 255, 220, 80, 205);
            }
            SDL_RenderDrawLines(renderer, ring, 33);
            if (touch_feedback.kind == TOUCH_FEEDBACK_ATTACK) {
                const int inner = std::max(3, radius / 2);
                const int outer = radius + 6;
                SDL_RenderDrawLine(renderer, center_x - outer, center_y, center_x - inner, center_y);
                SDL_RenderDrawLine(renderer, center_x + inner, center_y, center_x + outer, center_y);
                SDL_RenderDrawLine(renderer, center_x, center_y - outer, center_x, center_y - inner);
                SDL_RenderDrawLine(renderer, center_x, center_y + inner, center_x, center_y + outer);
            } else if (touch_feedback.kind == TOUCH_FEEDBACK_MOVE) {
                const int tick_inner = radius + 2;
                const int tick_outer = radius + 6;
                SDL_RenderDrawLine(renderer, center_x - tick_outer, center_y, center_x - tick_inner, center_y);
                SDL_RenderDrawLine(renderer, center_x + tick_inner, center_y, center_x + tick_outer, center_y);
                SDL_RenderDrawLine(renderer, center_x, center_y - tick_outer, center_x, center_y - tick_inner);
                SDL_RenderDrawLine(renderer, center_x, center_y + tick_inner, center_x, center_y + tick_outer);
                SDL_RenderDrawPoint(renderer, center_x, center_y);
            }
            if (Settings.Video.HighContrast) {
                for (int i = 0; i <= 32; ++i) {
                    const float angle = static_cast<float>(i) * 6.28318530718f / 32.0f;
                    ring[i].x = center_x + static_cast<int>(std::cos(angle) * (radius + 3));
                    ring[i].y = center_y + static_cast<int>(std::sin(angle) * (radius + 3));
                }
                SDL_SetRenderDrawColor(renderer, 0, 0, 0, 245);
                SDL_RenderDrawLines(renderer, ring, 33);
            }
        }
        render_dst = feedback_base;
        const Uint64 present_started = SDL_GetPerformanceCounter();
#endif
        SDL_RenderPresent(renderer);
#ifdef TIBERIAN_DAWN_APPLE_PORT
        const Uint64 present_finished = SDL_GetPerformanceCounter();
        telemetry.present_ms += (present_finished - present_started) * 1000.0 / SDL_GetPerformanceFrequency();
        ++telemetry.presents;
        if (!metal_rendered || indexed_pixels_changed) ++telemetry.uploads;

        const Uint32 input_timestamp = pending_input_timestamp.exchange(0, std::memory_order_acq_rel);
        if (input_timestamp != 0) {
            const double latency = static_cast<Uint32>(SDL_GetTicks() - input_timestamp);
            telemetry.input_latency_ms += latency;
            telemetry.max_input_latency_ms = std::max(telemetry.max_input_latency_ms, latency);
            ++telemetry.input_samples;
        }

        lastPaletteGeneration = palette_generation;
        lastCursorGeneration = cursor_generation;
        lastSelectionGeneration = selection_generation;
        lastHDBuggyGeneration = hd_buggy_generation;
        lastTouchFeedbackGeneration = touch_feedback.generation;
        lastTouchSelectionGeneration = touch_selection_box.generation;
        lastCursorX = cursor_x;
        lastCursorY = cursor_y;
        hadSoftwareCursor = software_cursor;
        hasLastFrame = true;
        force_present = false;
        last_frame_idle = false;
        Report_Telemetry_If_Due();
#endif
        return true;
    }

private:
    SDL_Surface* surface;
    SDL_Surface* windowSurface;
    SDL_Texture* texture;
    GBC_Enum flags;
#ifdef TIBERIAN_DAWN_APPLE_PORT
    std::vector<Uint8> lastIndexedPixels;
    uint64_t lastPaletteGeneration;
    uint64_t lastCursorGeneration;
    uint64_t lastSelectionGeneration;
    uint64_t lastHDBuggyGeneration;
    uint64_t lastTouchFeedbackGeneration;
    uint64_t lastTouchSelectionGeneration;
    int lastCursorX;
    int lastCursorY;
    bool hadSoftwareCursor;
    bool hasLastFrame;
    IPadPaletteRenderer paletteRenderer;
#endif
};

#ifdef TIBERIAN_DAWN_APPLE_PORT
bool Video_Render_Frame()
{
    if (frontSurface) {
        return frontSurface->RenderSurface();
    }
    return false;
}

void Set_Video_Render_Active(bool active)
{
    render_active = active;
    if (active) {
        force_present = true;
        last_frame_idle = false;
    }
}

void Video_Record_Input_Timestamp(uint32_t timestamp_ms)
{
    pending_input_timestamp.store(timestamp_ms != 0 ? timestamp_ms : SDL_GetTicks(), std::memory_order_release);
    // An input event must immediately leave the 15 Hz idle cadence. This keeps
    // the first pointer/touch response as quick as subsequent ones.
    last_frame_idle = false;
}

void Video_Set_Touch_Feedback(int game_x, int game_y, bool pencil, bool released)
{
    Video_Set_Touch_Input(true);
    touch_feedback.x = std::max(0, std::min(game_x, hwcursor.GameW - 1));
    touch_feedback.y = std::max(0, std::min(game_y, hwcursor.GameH - 1));
    touch_feedback.pencil = pencil;
    touch_feedback.kind = TOUCH_FEEDBACK_NEUTRAL;
    touch_feedback.active = true;
    touch_feedback.expires_at = SDL_GetTicks() + (released ? 180 : 1000);
    ++touch_feedback.generation;
    force_present = true;
    last_frame_idle = false;
}

void Video_Set_Touch_Feedback_Kind(TouchFeedbackKind kind)
{
    if (!touch_feedback.active || touch_feedback.kind == kind) return;
    touch_feedback.kind = kind;
    // A semantic command marker should remain readable for a little longer
    // than the neutral touch-up flash, on both iPadOS and native visionOS.
    touch_feedback.expires_at = std::max(touch_feedback.expires_at, SDL_GetTicks() + 320);
    ++touch_feedback.generation;
    force_present = true;
    last_frame_idle = false;
}

void Video_Clear_Touch_Feedback(void)
{
    if (!touch_feedback.active) return;
    touch_feedback.active = false;
    ++touch_feedback.generation;
    force_present = true;
    last_frame_idle = false;
}

void Video_Set_Touch_Input(bool touch_input)
{
    if (touch_input_active == touch_input) return;
    touch_input_active = touch_input;
    force_present = true;
    last_frame_idle = false;
}

void Video_Set_Touch_Selection_Box(bool active, int x1, int y1, int x2, int y2)
{
    x1 = std::max(0, std::min(x1, hwcursor.GameW - 1));
    y1 = std::max(0, std::min(y1, hwcursor.GameH - 1));
    x2 = std::max(0, std::min(x2, hwcursor.GameW - 1));
    y2 = std::max(0, std::min(y2, hwcursor.GameH - 1));
    if (touch_selection_box.active == active && touch_selection_box.x1 == x1
        && touch_selection_box.y1 == y1 && touch_selection_box.x2 == x2
        && touch_selection_box.y2 == y2) return;
    touch_selection_box.active = active;
    touch_selection_box.x1 = x1;
    touch_selection_box.y1 = y1;
    touch_selection_box.x2 = x2;
    touch_selection_box.y2 = y2;
    ++touch_selection_box.generation;
    force_present = true;
    last_frame_idle = false;
}

void Video_Set_Selection_Overlay(const void* object,
                                 int x,
                                 int y,
                                 int width,
                                 int height,
                                 unsigned char palette_index)
{
    if (!hd_world_artwork_visible || !object || width <= 0 || height <= 0) return;
    const IPadPaletteRect logical = {x, y, width, height};
    for (RegisteredSelectionOverlay& overlay : selection_overlays) {
        if (overlay.object != object) continue;
        if (overlay.logical.x == logical.x && overlay.logical.y == logical.y
            && overlay.logical.width == logical.width && overlay.logical.height == logical.height
            && overlay.palette_index == palette_index) return;
        overlay.logical = logical;
        overlay.palette_index = palette_index;
        ++selection_generation;
        force_present = true;
        return;
    }
    RegisteredSelectionOverlay overlay;
    overlay.object = object;
    overlay.logical = logical;
    overlay.palette_index = palette_index;
    selection_overlays.push_back(overlay);
    ++selection_generation;
    force_present = true;
}

void Video_Remove_Selection_Overlay(const void* object)
{
    const auto previous_size = selection_overlays.size();
    selection_overlays.erase(std::remove_if(selection_overlays.begin(),
                                            selection_overlays.end(),
                                            [object](const RegisteredSelectionOverlay& overlay) {
                                                return overlay.object == object;
                                            }),
                             selection_overlays.end());
    if (selection_overlays.size() == previous_size) return;
    ++selection_generation;
    force_present = true;
}

void Video_Set_HD_Artwork_Clip(int x, int y, int width, int height)
{
    const IPadPaletteRect clip = {x, y, std::max(0, width), std::max(0, height)};
    if (hd_artwork_clip.x == clip.x && hd_artwork_clip.y == clip.y
        && hd_artwork_clip.width == clip.width && hd_artwork_clip.height == clip.height) return;
    hd_artwork_clip = clip;
    ++hd_buggy_generation;
    force_present = true;
}

void Video_Set_HD_World_Artwork_Visible(bool visible)
{
    if (hd_world_artwork_visible == visible) return;
    hd_world_artwork_visible = visible;
    if (!visible) {
        Video_Clear_HD_Artwork();
        if (touch_selection_box.active) {
            touch_selection_box.active = false;
            ++touch_selection_box.generation;
        }
    }
    ++hd_buggy_generation;
    force_present = true;
}

void Video_Offset_HD_World_Artwork(int x, int y)
{
    if ((x == 0 && y == 0)
        || (hd_buggies.empty() && hd_infantry.empty() && hd_buildings.empty()
            && selection_overlays.empty())) return;
    for (RegisteredHDBuggy& buggy : hd_buggies) {
        buggy.body_x += x;
        buggy.body_y += y;
        buggy.turret_x += x;
        buggy.turret_y += y;
        buggy.health_x += x;
        buggy.health_y += y;
    }
    for (RegisteredHDInfantry& soldier : hd_infantry) {
        soldier.center_x += x;
        soldier.center_y += y;
        soldier.health_x += x;
        soldier.health_y += y;
    }
    for (RegisteredHDBuilding& building : hd_buildings) {
        building.center_x += x;
        building.center_y += y;
        building.health_x += x;
        building.health_y += y;
    }
    for (RegisteredSelectionOverlay& selection : selection_overlays) {
        selection.logical.x += x;
        selection.logical.y += y;
    }
    ++hd_buggy_generation;
    ++selection_generation;
    force_present = true;
}

void Video_Set_HD_Buggy_Component(const void* object,
                                  int component,
                                  int frame,
                                  int center_x,
                                  int center_y,
                                  unsigned char palette_index)
{
    Video_Set_HD_Vehicle_Component(object, 0, component, frame, center_x, center_y, palette_index);
}

void Video_Set_HD_Vehicle_Component(const void* object,
                                    int vehicle_kind,
                                    int component,
                                    int frame,
                                    int center_x,
                                    int center_y,
                                    unsigned char palette_index)
{
    const int frame_count = vehicle_kind >= 2 ? 8 : 64;
    if (!object || !hd_world_artwork_visible || vehicle_kind < 0 || vehicle_kind > 3 || component < 0 || component > 1
        || (vehicle_kind >= 2 && component != 0) || frame < 0 || frame >= frame_count) return;
    for (RegisteredHDBuggy& buggy : hd_buggies) {
        if (buggy.object != object) continue;
        if (buggy.atlas_kind != vehicle_kind) {
            buggy.body_frame = -1;
            buggy.turret_frame = -1;
        }
        int& saved_frame = component == 0 ? buggy.body_frame : buggy.turret_frame;
        int& saved_x = component == 0 ? buggy.body_x : buggy.turret_x;
        int& saved_y = component == 0 ? buggy.body_y : buggy.turret_y;
        if (saved_frame == frame && saved_x == center_x && saved_y == center_y
            && buggy.palette_index == palette_index && buggy.atlas_kind == vehicle_kind) return;
        saved_frame = frame;
        saved_x = center_x;
        saved_y = center_y;
        buggy.palette_index = palette_index;
        buggy.atlas_kind = vehicle_kind;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }

    RegisteredHDBuggy buggy;
    buggy.object = object;
    buggy.palette_index = palette_index;
    buggy.atlas_kind = vehicle_kind;
    if (component == 0) {
        buggy.body_frame = frame;
        buggy.body_x = center_x;
        buggy.body_y = center_y;
    } else {
        buggy.turret_frame = frame;
        buggy.turret_x = center_x;
        buggy.turret_y = center_y;
    }
    hd_buggies.push_back(buggy);
    ++hd_buggy_generation;
    force_present = true;
}

void Video_Set_HD_Infantry(const void* object,
                           int frame,
                           int center_x,
                           int center_y,
                           unsigned char palette_index)
{
    if (!object || !hd_world_artwork_visible || frame < 0 || frame >= 80) return;
    for (RegisteredHDInfantry& soldier : hd_infantry) {
        if (soldier.object != object) continue;
        if (soldier.frame == frame && soldier.center_x == center_x && soldier.center_y == center_y
            && soldier.palette_index == palette_index) return;
        soldier.frame = frame;
        soldier.center_x = center_x;
        soldier.center_y = center_y;
        soldier.palette_index = palette_index;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }
    RegisteredHDInfantry soldier;
    soldier.object = object;
    soldier.frame = frame;
    soldier.center_x = center_x;
    soldier.center_y = center_y;
    soldier.palette_index = palette_index;
    hd_infantry.push_back(soldier);
    ++hd_buggy_generation;
    force_present = true;
}

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
                           unsigned char palette_index)
{
    if (!object || faction_kind < 0 || faction_kind > 1 || frame < 0 || frame >= 3
        || activity_frame < -1 || activity_frame >= 30
        || width <= 0 || height <= 0 || !hd_world_artwork_visible) return;
    completion = std::max(0, std::min(completion, 255));
    damage = std::max(0, std::min(damage, 255));
    for (RegisteredHDBuilding& building : hd_buildings) {
        if (building.object != object) continue;
        if (building.faction_kind == faction_kind && building.frame == frame
            && building.activity_frame == activity_frame
            && building.center_x == center_x && building.center_y == center_y
            && building.width == width && building.height == height
            && building.completion == completion && building.damage == damage
            && building.repairing == repairing && building.palette_index == palette_index) return;
        building.faction_kind = faction_kind;
        building.frame = frame;
        building.activity_frame = activity_frame;
        building.center_x = center_x;
        building.center_y = center_y;
        building.width = width;
        building.height = height;
        building.completion = completion;
        building.damage = damage;
        building.repairing = repairing;
        building.palette_index = palette_index;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }
    RegisteredHDBuilding building;
    building.object = object;
    building.faction_kind = faction_kind;
    building.frame = frame;
    building.activity_frame = activity_frame;
    building.center_x = center_x;
    building.center_y = center_y;
    building.width = width;
    building.height = height;
    building.completion = completion;
    building.damage = damage;
    building.repairing = repairing;
    building.palette_index = palette_index;
    hd_buildings.push_back(building);
    ++hd_buggy_generation;
    force_present = true;
}

void Video_Remove_HD_Artwork(const void* object)
{
    const auto previous_size = hd_buggies.size();
    hd_buggies.erase(std::remove_if(hd_buggies.begin(),
                                    hd_buggies.end(),
                                    [object](const RegisteredHDBuggy& buggy) {
                                        return buggy.object == object;
                                    }),
                     hd_buggies.end());
    const auto previous_infantry_size = hd_infantry.size();
    hd_infantry.erase(std::remove_if(hd_infantry.begin(),
                                     hd_infantry.end(),
                                     [object](const RegisteredHDInfantry& soldier) {
                                         return soldier.object == object;
                                     }),
                      hd_infantry.end());
    const auto previous_building_size = hd_buildings.size();
    hd_buildings.erase(std::remove_if(hd_buildings.begin(),
                                     hd_buildings.end(),
                                     [object](const RegisteredHDBuilding& building) {
                                         return building.object == object;
                                     }),
                       hd_buildings.end());
    if (hd_buggies.size() == previous_size && hd_infantry.size() == previous_infantry_size
        && hd_buildings.size() == previous_building_size) return;
    ++hd_buggy_generation;
    force_present = true;
}

void Video_Clear_HD_Artwork()
{
    if (hd_buggies.empty() && hd_infantry.empty() && hd_buildings.empty()
        && selection_overlays.empty()) return;
    hd_buggies.clear();
    hd_infantry.clear();
    hd_buildings.clear();
    selection_overlays.clear();
    ++hd_buggy_generation;
    ++selection_generation;
    force_present = true;
}

void Video_Set_HD_Health(const void* object,
                         bool visible,
                         int x,
                         int y,
                         int width,
                         int fill_width,
                         unsigned char palette_index)
{
    if (!object) return;
    for (RegisteredHDBuggy& buggy : hd_buggies) {
        if (buggy.object != object) continue;
        if (buggy.health_visible == visible && (!visible
                                                || (buggy.health_x == x && buggy.health_y == y
                                                    && buggy.health_width == width
                                                    && buggy.health_fill_width == fill_width
                                                    && buggy.health_palette_index == palette_index))) return;
        buggy.health_visible = visible;
        buggy.health_x = x;
        buggy.health_y = y;
        buggy.health_width = width;
        buggy.health_fill_width = fill_width;
        buggy.health_palette_index = palette_index;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }
    for (RegisteredHDInfantry& soldier : hd_infantry) {
        if (soldier.object != object) continue;
        if (soldier.health_visible == visible && (!visible
                                                  || (soldier.health_x == x && soldier.health_y == y
                                                      && soldier.health_width == width
                                                      && soldier.health_fill_width == fill_width
                                                      && soldier.health_palette_index == palette_index))) return;
        soldier.health_visible = visible;
        soldier.health_x = x;
        soldier.health_y = y;
        soldier.health_width = width;
        soldier.health_fill_width = fill_width;
        soldier.health_palette_index = palette_index;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }
    for (RegisteredHDBuilding& building : hd_buildings) {
        if (building.object != object) continue;
        if (building.health_visible == visible && (!visible
                                                   || (building.health_x == x && building.health_y == y
                                                       && building.health_width == width
                                                       && building.health_fill_width == fill_width
                                                       && building.health_palette_index == palette_index))) return;
        building.health_visible = visible;
        building.health_x = x;
        building.health_y = y;
        building.health_width = width;
        building.health_fill_width = fill_width;
        building.health_palette_index = palette_index;
        ++hd_buggy_generation;
        force_present = true;
        return;
    }
}

bool Video_Uses_HD_Buggy_Artwork()
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0 && hd_buggy_renderer_available;
}

bool Video_Uses_HD_Humvee_Artwork()
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0 && hd_humvee_renderer_available;
}

bool Video_Uses_HD_Minigunner_Artwork()
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0 && hd_minigunner_renderer_available;
}

bool Video_Uses_HD_MCV_Artwork(bool nod)
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0
           && (nod ? hd_nod_mcv_renderer_available : hd_gdi_mcv_renderer_available);
}

bool Video_Uses_HD_Infrastructure_Artwork(bool nod)
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0
           && (nod ? hd_nod_infrastructure_renderer_available : hd_gdi_infrastructure_renderer_available);
}

bool Video_Uses_HD_Infrastructure_Activity_Artwork(bool nod)
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0
           && (nod ? hd_nod_infrastructure_activity_renderer_available
                   : hd_gdi_infrastructure_activity_renderer_available);
}

bool Video_Uses_Modern_Artwork()
{
    return hd_world_artwork_visible && Settings.Video.ArtworkMode != 0;
}

void Set_IPadOS_Text_Input_Rect(int game_x, int game_y, int game_w, int game_h)
{
    if (!window || !renderer || hwcursor.GameW <= 0 || hwcursor.GameH <= 0) {
        return;
    }

    int window_w = 0;
    int window_h = 0;
    int output_w = 0;
    int output_h = 0;
    SDL_GetWindowSize(window, &window_w, &window_h);
    SDL_GetRendererOutputSize(renderer, &output_w, &output_h);
    if (window_w <= 0 || window_h <= 0 || output_w <= 0 || output_h <= 0) {
        return;
    }

    const float game_to_output_x = render_dst.w / static_cast<float>(hwcursor.GameW);
    const float game_to_output_y = render_dst.h / static_cast<float>(hwcursor.GameH);
    const float output_to_window_x = window_w / static_cast<float>(output_w);
    const float output_to_window_y = window_h / static_cast<float>(output_h);
    SDL_Rect rect = {
        static_cast<int>((render_dst.x + game_x * game_to_output_x) * output_to_window_x),
        static_cast<int>((render_dst.y + game_y * game_to_output_y) * output_to_window_y),
        std::max(1, static_cast<int>(game_w * game_to_output_x * output_to_window_x)),
        std::max(1, static_cast<int>(game_h * game_to_output_y * output_to_window_y))};
    SDL_SetTextInputRect(&rect);
}

int Video_Get_Effective_Frame_Limit()
{
    Update_Power_State();
    if (!render_active || !Is_App_In_Foreground()) {
        return 5;
    }

    int limit = Settings.Video.FrameLimit > 0 ? Settings.Video.FrameLimit : 60;
    limit = std::max(15, std::min(limit, 60));
    if (Settings.Video.BatterySaving || low_power_mode || thermal_state >= 2) {
        limit = std::min(limit, 30);
    }
    // Keep foreground input responsive even between simulation updates.
    return limit;
}
#else
void Video_Render_Frame()
{
    if (frontSurface) {
        frontSurface->RenderSurface();
    }
}
#endif

/*
** Video
*/

Video::Video()
{
}

Video::~Video()
{
}

Video& Video::Shared()
{
    static Video video;
    return video;
}

VideoSurface* Video::CreateSurface(int w, int h, GBC_Enum flags)
{
    return new VideoSurfaceSDL2(w, h, flags);
}
