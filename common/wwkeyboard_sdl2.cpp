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

#include "macros.h"
#include "app_lifecycle.h"
#include "ipados_pencil.h"
#include "ipados_touch.h"
#include "wwkeyboard_sdl2.h"
#include "video.h"
#include "sdl_keymap.h"
#include "settings.h"
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
#include "wireproof_orders.h"
#ifdef MACOS_PORT
extern "C" void WP_ShowLiveCheats(void);
#endif
#endif
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <SDL.h>

void Focus_Loss();
void Focus_Restore();
extern "C" void TiberianDawn_ConfigureAudioSession(void);
extern "C" bool TiberianDawn_RebuildAudioEngine(void);
void Process_Network();

namespace
{
bool Is_Text_Producing_Scancode(SDL_Scancode scancode)
{
    return (scancode >= SDL_SCANCODE_A && scancode <= SDL_SCANCODE_0)
           || (scancode >= SDL_SCANCODE_MINUS && scancode <= SDL_SCANCODE_SLASH)
           || (scancode >= SDL_SCANCODE_KP_DIVIDE && scancode <= SDL_SCANCODE_KP_PERIOD)
           || scancode == SDL_SCANCODE_SPACE || scancode == SDL_SCANCODE_NONUSBACKSLASH
           || scancode == SDL_SCANCODE_KP_EQUALS;
}
}

// Text entry is shared by desktop and touch builds.
uint32_t Decode_UTF8_Character(const char*& text)
{
    const unsigned char first = static_cast<unsigned char>(*text++);
    if (first < 0x80) {
        return first;
    }

    int continuation_count = 0;
    uint32_t codepoint = 0;
    if ((first & 0xE0) == 0xC0) {
        continuation_count = 1;
        codepoint = first & 0x1F;
    } else if ((first & 0xF0) == 0xE0) {
        continuation_count = 2;
        codepoint = first & 0x0F;
    } else if ((first & 0xF8) == 0xF0) {
        continuation_count = 3;
        codepoint = first & 0x07;
    } else {
        return 0;
    }

    for (int i = 0; i < continuation_count; ++i) {
        const unsigned char next = static_cast<unsigned char>(*text);
        if ((next & 0xC0) != 0x80) {
            return 0;
        }
        ++text;
        codepoint = (codepoint << 6) | (next & 0x3F);
    }
    return codepoint;
}

unsigned char Legacy_Character_From_Unicode(uint32_t codepoint)
{
    // The original Gold assets use an 8-bit character set. Latin-1 retains
    // German umlauts and ß; a few common smart punctuation marks are folded.
    if (codepoint >= 0x20 && codepoint <= 0xFF) {
        return static_cast<unsigned char>(codepoint);
    }
    switch (codepoint) {
    case 0x2018:
    case 0x2019:
        return '\'';
    case 0x201C:
    case 0x201D:
        return '"';
    case 0x2013:
    case 0x2014:
        return '-';
    case 0x2026:
        return '.';
    default:
        return 0;
    }
}

void Queue_Text_Input(WWKeyboardClassSDL2& keyboard, const char* text)
{
    while (text && *text) {
        const uint32_t codepoint = Decode_UTF8_Character(text);
        const unsigned char character = Legacy_Character_From_Unicode(codepoint);
        if (character != 0) {
            keyboard.Put_Text_Character(character);
        }
    }
}

#ifdef IPADOS_PORT
namespace
{
const int TouchSlotCount = 2;
const float FingerDragThresholdPoints = 8.0f;
const float PencilDragThresholdPoints = 4.0f;
const Uint32 LongPressMilliseconds = 500;
const Uint32 TwoFingerTapMilliseconds = 300;

struct TouchFingerState
{
    SDL_FingerID id = -1;
    float normalized_x = 0.0f;
    float normalized_y = 0.0f;
    bool active = false;
    bool pencil = false;
};

struct TouchGestureState
{
    TouchFingerState fingers[TouchSlotCount];
    SDL_FingerID primary_id = -1;
    int start_x = 0;
    int start_y = 0;
    int current_x = 0;
    int current_y = 0;
    float pan_centroid_x = 0.0f;
    float pan_centroid_y = 0.0f;
    float pan_travel = 0.0f;
    Uint32 started_at = 0;
    Uint32 two_finger_started_at = 0;
    bool left_button_down = false;
    bool long_press_sent = false;
    bool panning = false;
    bool suppress_until_all_released = false;
    bool two_finger_tap_sent = false;
    bool primary_pencil = false;
    bool modifier_pan = false;
};

TouchGestureState TouchGesture;
IPadOSPencilSqueezeState PencilSqueeze;
float PendingPanX = 0.0f;
float PendingPanY = 0.0f;
Uint32 PendingPanAt = 0;
#ifdef VISIONOS_PORT
float PendingVisionLookX = 0.0f;
float PendingVisionLookY = 0.0f;
Uint32 PendingVisionLookAt = 0;
#endif

int Active_Finger_Count(void)
{
    int count = 0;
    for (int i = 0; i < TouchSlotCount; ++i) {
        if (TouchGesture.fingers[i].active) {
            ++count;
        }
    }
    return count;
}

TouchFingerState* Find_Finger(SDL_FingerID id)
{
    for (int i = 0; i < TouchSlotCount; ++i) {
        if (TouchGesture.fingers[i].active && TouchGesture.fingers[i].id == id) {
            return &TouchGesture.fingers[i];
        }
    }
    return nullptr;
}

TouchFingerState* Add_Finger(const SDL_TouchFingerEvent& event)
{
    for (int i = 0; i < TouchSlotCount; ++i) {
        if (!TouchGesture.fingers[i].active) {
            TouchGesture.fingers[i].id = event.fingerId;
            TouchGesture.fingers[i].normalized_x = event.x;
            TouchGesture.fingers[i].normalized_y = event.y;
            TouchGesture.fingers[i].active = true;
            TouchGesture.fingers[i].pencil = event.pressure >= 10.0f;
            return &TouchGesture.fingers[i];
        }
    }
    return nullptr;
}

bool Gesture_Moved_Beyond_Threshold(void)
{
    const int delta_x = TouchGesture.current_x - TouchGesture.start_x;
    const int delta_y = TouchGesture.current_y - TouchGesture.start_y;
    TouchFingerState* primary = Find_Finger(TouchGesture.primary_id);
    const float threshold_points = primary && primary->pencil
                                       ? PencilDragThresholdPoints
                                       : FingerDragThresholdPoints;
    const int threshold = Video_Game_Pixels_For_Window_Points(threshold_points);
    const int threshold_squared = threshold * threshold;
    return delta_x * delta_x + delta_y * delta_y >= threshold_squared;
}

#if !defined(VISIONOS_PORT)
bool Current_IPad_Touch_Edge_Scroll(ScrollDirType& direction, float& intensity)
{
    direction = SDIR_NONE;
    intensity = 0.0f;
    if (!Settings.Touch.EdgeScroll || !TouchGesture.left_button_down || TouchGesture.panning
        || TouchGesture.suppress_until_all_released || Active_Finger_Count() != 1) {
        return false;
    }

    TouchFingerState* primary = Find_Finger(TouchGesture.primary_id);
    if (!primary) return false;

    const float band = 0.075f;
    const bool west = primary->normalized_x <= band;
    const bool east = primary->normalized_x >= 1.0f - band;
    const bool north = primary->normalized_y <= band;
    const bool south = primary->normalized_y >= 1.0f - band;
    if (east && north) direction = SDIR_NE;
    else if (east && south) direction = SDIR_SE;
    else if (west && north) direction = SDIR_NW;
    else if (west && south) direction = SDIR_SW;
    else if (east) direction = SDIR_E;
    else if (west) direction = SDIR_W;
    else if (north) direction = SDIR_N;
    else if (south) direction = SDIR_S;
    if (direction == SDIR_NONE) return false;

    float proximity = 0.0f;
    if (west) proximity = std::max(proximity, (band - primary->normalized_x) / band);
    if (east) proximity = std::max(proximity, (primary->normalized_x - (1.0f - band)) / band);
    if (north) proximity = std::max(proximity, (band - primary->normalized_y) / band);
    if (south) proximity = std::max(proximity, (primary->normalized_y - (1.0f - band)) / band);
    proximity = std::max(0.0f, std::min(1.0f, proximity));
    const float speed = Settings.Touch.ScrollSpeed == 0
                            ? 0.70f
                            : (Settings.Touch.ScrollSpeed == 2 ? 1.40f : 1.0f);
    intensity = (0.30f + 0.70f * std::pow(proximity, 1.35f)) * speed;
    return true;
}
#endif

void Reset_Touch_Gesture(void)
{
    TouchGesture = TouchGestureState();
}

bool Put_Primary_Mouse_Message(WWKeyboardClassSDL2& keyboard,
                               unsigned short key,
                               int x,
                               int y,
                               bool release)
{
    return TouchGesture.primary_pencil
               ? keyboard.Put_Pencil_Mouse_Message(key, x, y, release)
               : keyboard.Put_Touch_Mouse_Message(key, x, y, release);
}

void Release_Touch_Left_Button(WWKeyboardClassSDL2& keyboard)
{
    if (TouchGesture.left_button_down) {
        Put_Primary_Mouse_Message(
            keyboard, VK_LBUTTON, TouchGesture.current_x, TouchGesture.current_y, true);
        TouchGesture.left_button_down = false;
    }
}

void Cancel_Touch_Gesture(WWKeyboardClassSDL2& keyboard)
{
    Release_Touch_Left_Button(keyboard);
    IPadOS_Reset_Pencil_Squeeze(PencilSqueeze);
    Video_Clear_Touch_Feedback();
    TouchGesture.long_press_sent = true;
    TouchGesture.panning = false;
    TouchGesture.suppress_until_all_released = true;
    PendingPanX = 0.0f;
    PendingPanY = 0.0f;
}

void Begin_Primary_Touch(const SDL_TouchFingerEvent& event)
{
    TouchGesture.primary_id = event.fingerId;
    TouchGesture.started_at = SDL_GetTicks();
    TouchGesture.modifier_pan = WPOrders::Shared().panHeld();
    TouchGesture.long_press_sent = TouchGesture.modifier_pan;
    TouchGesture.panning = false;
    TouchGesture.suppress_until_all_released = false;
    TouchFingerState* primary = Find_Finger(event.fingerId);
    TouchGesture.primary_pencil = primary && primary->pencil;
    Set_Video_Mouse_Normalized(event.x, event.y, TouchGesture.start_x, TouchGesture.start_y);
    TouchGesture.current_x = TouchGesture.start_x;
    TouchGesture.current_y = TouchGesture.start_y;
}

void Begin_Two_Finger_Pan(WWKeyboardClassSDL2& keyboard)
{
    Release_Touch_Left_Button(keyboard);
    TouchGesture.long_press_sent = true;
    TouchGesture.panning = true;
    TouchGesture.pan_travel = 0.0f;
    TouchGesture.two_finger_started_at = SDL_GetTicks();
    TouchGesture.two_finger_tap_sent = false;
    TouchGesture.pan_centroid_x =
        (TouchGesture.fingers[0].normalized_x + TouchGesture.fingers[1].normalized_x) * 0.5f;
    TouchGesture.pan_centroid_y =
        (TouchGesture.fingers[0].normalized_y + TouchGesture.fingers[1].normalized_y) * 0.5f;
}

void Handle_Touch_Down(WWKeyboardClassSDL2& keyboard, const SDL_TouchFingerEvent& event)
{
    if (Find_Finger(event.fingerId) != nullptr) {
        return;
    }

    TouchFingerState* finger = Add_Finger(event);
    if (finger == nullptr) {
        Cancel_Touch_Gesture(keyboard);
        return;
    }

    const int finger_count = Active_Finger_Count();
    if (TouchGesture.suppress_until_all_released) {
        return;
    }
    if (finger_count == 1) {
        // A Magic Keyboard/trackpad can disappear without SDL delivering its
        // final button-up event. A new direct touch is an unambiguous modality
        // switch, so discard only stale mouse-button state before beginning it.
        keyboard.Reset_Mouse_Button_State();
        Begin_Primary_Touch(event);
        Video_Set_Touch_Feedback(TouchGesture.current_x, TouchGesture.current_y, finger->pencil, false);
    } else if (finger_count == 2) {
        Begin_Two_Finger_Pan(keyboard);
    }
}

void Handle_Touch_Motion(WWKeyboardClassSDL2& keyboard, const SDL_TouchFingerEvent& event)
{
    TouchFingerState* finger = Find_Finger(event.fingerId);
    if (finger == nullptr) {
        return;
    }

    const float previous_x=finger->normalized_x, previous_y=finger->normalized_y;
    finger->normalized_x = event.x;
    finger->normalized_y = event.y;

    if (TouchGesture.suppress_until_all_released) {
        return;
    }

    // The modifier finger belongs to UIKit's floating button; SDL sees only
    // the map finger. Never turn its release into a selection or right-click.
    // Persistent map-drag mode changes drags only; ordinary taps still click.
    if (WPOrders::Shared().mapDrag() && Active_Finger_Count()==1 && event.fingerId==TouchGesture.primary_id) {
        Set_Video_Mouse_Normalized(event.x,event.y,TouchGesture.current_x,TouchGesture.current_y);
        if (Gesture_Moved_Beyond_Threshold()) TouchGesture.modifier_pan=true;
    }
    if (TouchGesture.modifier_pan || WPOrders::Shared().panHeld()) {
        Release_Touch_Left_Button(keyboard);
        TouchGesture.modifier_pan=true;
        TouchGesture.long_press_sent=true;
        if (WPOrders::Shared().panHeld() || WPOrders::Shared().mapDrag()) {
            PendingPanX += event.x-previous_x;
            PendingPanY += event.y-previous_y;
            PendingPanAt=SDL_GetTicks();
        } else {
            PendingPanX=PendingPanY=0;
            TouchGesture.suppress_until_all_released=true;
        }
        return;
    }

    if (TouchGesture.panning && Active_Finger_Count() == 2) {
        const float centroid_x =
            (TouchGesture.fingers[0].normalized_x + TouchGesture.fingers[1].normalized_x) * 0.5f;
        const float centroid_y =
            (TouchGesture.fingers[0].normalized_y + TouchGesture.fingers[1].normalized_y) * 0.5f;
        const float delta_x = centroid_x - TouchGesture.pan_centroid_x;
        const float delta_y = centroid_y - TouchGesture.pan_centroid_y;
        TouchGesture.pan_centroid_x = centroid_x;
        TouchGesture.pan_centroid_y = centroid_y;
        TouchGesture.pan_travel += std::sqrt(delta_x * delta_x + delta_y * delta_y);
        PendingPanX += delta_x;
        PendingPanY += delta_y;
        PendingPanAt = SDL_GetTicks();
        return;
    }

    if (event.fingerId != TouchGesture.primary_id) {
        return;
    }

    Set_Video_Mouse_Normalized(event.x, event.y, TouchGesture.current_x, TouchGesture.current_y);
    Video_Set_Touch_Feedback(TouchGesture.current_x, TouchGesture.current_y, finger->pencil, false);
    if (!TouchGesture.left_button_down && !TouchGesture.long_press_sent && Gesture_Moved_Beyond_Threshold()) {
        Put_Primary_Mouse_Message(
            keyboard, VK_LBUTTON, TouchGesture.start_x, TouchGesture.start_y, false);
        TouchGesture.left_button_down = true;
        Set_Video_Mouse_Normalized(event.x, event.y, TouchGesture.current_x, TouchGesture.current_y);
    }
}

void Handle_Touch_Up(WWKeyboardClassSDL2& keyboard, const SDL_TouchFingerEvent& event)
{
    TouchFingerState* finger = Find_Finger(event.fingerId);
    if (finger == nullptr) {
        return;
    }

    const bool cancelled = event.pressure < 0.0f;
    if (cancelled) {
        Cancel_Touch_Gesture(keyboard);
    }

    if (!cancelled && !TouchGesture.modifier_pan && TouchGesture.panning && !TouchGesture.two_finger_tap_sent
        && TouchGesture.pan_travel < 0.012f
        && SDL_GetTicks() - TouchGesture.two_finger_started_at <= TwoFingerTapMilliseconds) {
        int x = 0;
        int y = 0;
        Set_Video_Mouse_Normalized(TouchGesture.pan_centroid_x, TouchGesture.pan_centroid_y, x, y);
        keyboard.Put_Touch_Mouse_Message(VK_RBUTTON, x, y, false);
        keyboard.Put_Touch_Mouse_Message(VK_RBUTTON, x, y, true);
        TouchGesture.two_finger_tap_sent = true;
    } else if (!cancelled && !TouchGesture.modifier_pan && !TouchGesture.panning && !TouchGesture.suppress_until_all_released
               && event.fingerId == TouchGesture.primary_id) {
        Set_Video_Mouse_Normalized(event.x, event.y, TouchGesture.current_x, TouchGesture.current_y);
        if (TouchGesture.left_button_down) {
            Release_Touch_Left_Button(keyboard);
        } else if (!TouchGesture.long_press_sent) {
            Put_Primary_Mouse_Message(
                keyboard, VK_LBUTTON, TouchGesture.current_x, TouchGesture.current_y, false);
            Put_Primary_Mouse_Message(
                keyboard, VK_LBUTTON, TouchGesture.current_x, TouchGesture.current_y, true);
        }
    }

    int feedback_x = TouchGesture.current_x;
    int feedback_y = TouchGesture.current_y;
    Set_Video_Mouse_Normalized(event.x, event.y, feedback_x, feedback_y);
    Video_Set_Touch_Feedback(feedback_x, feedback_y, finger->pencil, true);

    finger->active = false;
    if (TouchGesture.panning) {
        TouchGesture.panning = false;
        TouchGesture.suppress_until_all_released = true;
    }
    if (Active_Finger_Count() == 0) {
        Reset_Touch_Gesture();
    }
}

void Update_Long_Press(WWKeyboardClassSDL2& keyboard)
{
    if (TouchGesture.primary_pencil || Active_Finger_Count() != 1 || TouchGesture.panning
        || TouchGesture.suppress_until_all_released
        || TouchGesture.left_button_down || TouchGesture.long_press_sent || Gesture_Moved_Beyond_Threshold()
        || SDL_GetTicks() - TouchGesture.started_at < LongPressMilliseconds) {
        return;
    }

    keyboard.Put_Touch_Mouse_Message(VK_RBUTTON, TouchGesture.current_x, TouchGesture.current_y, false);
    keyboard.Put_Touch_Mouse_Message(VK_RBUTTON, TouchGesture.current_x, TouchGesture.current_y, true);
    TouchGesture.long_press_sent = true;
}

int SDLCALL Capture_Lifecycle_Event(void*, SDL_Event* event)
{
    switch (event->type) {
    case SDL_APP_TERMINATING:
        Queue_App_Lifecycle_Event(APP_LIFECYCLE_TERMINATING);
        break;
    case SDL_APP_LOWMEMORY:
        Queue_App_Lifecycle_Event(APP_LIFECYCLE_LOW_MEMORY);
        break;
    case SDL_APP_WILLENTERBACKGROUND:
    case SDL_APP_DIDENTERBACKGROUND:
        Queue_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_BACKGROUND);
        break;
    case SDL_APP_DIDENTERFOREGROUND:
        Queue_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_FOREGROUND);
        break;
    case SDL_APP_WILLENTERFOREGROUND:
        break;
    default:
        break;
    }
    return 1;
}
}

bool Consume_IPadOS_Touch_Pan(float& delta_x, float& delta_y)
{
    if ((TouchGesture.modifier_pan && !WPOrders::Shared().panHeld() && !WPOrders::Shared().mapDrag()) || PendingPanAt == 0 || SDL_GetTicks() - PendingPanAt > 100) {
        Discard_IPadOS_Touch_Pan();
        return false;
    }

    delta_x = PendingPanX;
    delta_y = PendingPanY;
    PendingPanX = 0.0f;
    PendingPanY = 0.0f;
    return delta_x != 0.0f || delta_y != 0.0f;
}

void Discard_IPadOS_Touch_Pan(void)
{
    PendingPanX = 0.0f;
    PendingPanY = 0.0f;
    PendingPanAt = 0;
}

bool Consume_VisionOS_Look_Scroll(float& delta_x, float& delta_y)
{
#ifdef VISIONOS_PORT
    if (PendingVisionLookAt == 0 || SDL_GetTicks() - PendingVisionLookAt > 160) {
        Discard_VisionOS_Look_Scroll();
        return false;
    }

    delta_x = PendingVisionLookX;
    delta_y = PendingVisionLookY;
    PendingVisionLookX = 0.0f;
    PendingVisionLookY = 0.0f;
    return delta_x != 0.0f || delta_y != 0.0f;
#else
    delta_x = 0.0f;
    delta_y = 0.0f;
    return false;
#endif
}

void Discard_VisionOS_Look_Scroll(void)
{
#ifdef VISIONOS_PORT
    PendingVisionLookX = 0.0f;
    PendingVisionLookY = 0.0f;
    PendingVisionLookAt = 0;
#endif
}


#ifdef VISIONOS_PORT
float Vision_Event_Coordinate(void* encoded)
{
    return static_cast<float>(reinterpret_cast<uintptr_t>(encoded)) / 1000000.0f;
}

float Vision_Event_Delta(void* encoded)
{
    return static_cast<float>(reinterpret_cast<intptr_t>(encoded)) / 1000000.0f;
}

#endif
#endif

WWKeyboardClassSDL2::WWKeyboardClassSDL2()
{
}

WWKeyboardClassSDL2::~WWKeyboardClassSDL2()
{
#ifdef IPADOS_PORT
    if (LifecycleWatchInstalled) {
        SDL_DelEventWatch(Capture_Lifecycle_Event, nullptr);
    }
#endif
}

void WWKeyboardClassSDL2::Clear(void)
{
    WWKeyboardClass::Clear();
#ifdef IPADOS_PORT
    /* Scenario changes and modal dialogs intentionally discard queued input.
    ** Keep the native Apple gesture state in lockstep with that queue so a
    ** discarded pinch-down cannot suppress the first selection in the next
    ** campaign mission, skirmish, or multiplayer game. */
    Reset_Touch_Gesture();
    IPadOS_Reset_Pencil_Squeeze(PencilSqueeze);
    Discard_IPadOS_Touch_Pan();
    Video_Clear_Touch_Feedback();
    Reset_Mouse_Button_State();
#ifdef VISIONOS_PORT
    VisionOS_Reset_Input(VisionInputState);
    Discard_VisionOS_Look_Scroll();
#endif
#endif
}

void WWKeyboardClassSDL2::Fill_Buffer_From_System(void)
{
#ifdef IPADOS_PORT
    if (!LifecycleWatchInstalled) {
        SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
        SDL_AddEventWatch(Capture_Lifecycle_Event, nullptr);
        LifecycleWatchInstalled = true;
    }
#endif
#ifdef NETWORKING
    Process_Network();
#endif
    SDL_Event event;
    while (!Is_Buffer_Full() && SDL_PollEvent(&event)) {
        unsigned short key;
        switch (event.type) {
        case SDL_QUIT:
            exit(0);
            break;
        case SDL_KEYDOWN:
#ifdef MACOS_PORT
            if (!SDL_IsTextInputActive() && (event.key.keysym.mod & KMOD_ALT)
                && event.key.keysym.scancode==SDL_SCANCODE_C && WPOrders::Shared().snapshot().active) {
                WP_ShowLiveCheats(); break;
            }
#endif
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
            // Keyboard equivalent of the UIKit zoom control on desktop.
            if (!SDL_IsTextInputActive() && (event.key.keysym.mod & KMOD_ALT)
                && WPOrders::Shared().snapshot().active
                && (event.key.keysym.scancode==SDL_SCANCODE_EQUALS || event.key.keysym.scancode==SDL_SCANCODE_MINUS)) {
                WPOrders::Shared().stepZoom(event.key.keysym.scancode==SDL_SCANCODE_MINUS?-1:1);
                break;
            }
#endif
            if (!SDL_IsTextInputActive() || !Is_Text_Producing_Scancode(event.key.keysym.scancode)) {
                Put_Key_Message(event.key.keysym.scancode, false);
            }
            break;
        case SDL_KEYUP:
            if (SDL_IsTextInputActive() && Is_Text_Producing_Scancode(event.key.keysym.scancode)) {
                break;
            } else if (event.key.keysym.scancode == SDL_SCANCODE_RETURN && Down(VK_MENU)) {
                Toggle_Video_Fullscreen();
            } else {
                Put_Key_Message(event.key.keysym.scancode, true);
            }
            break;
#ifdef IPADOS_PORT
        case SDL_USEREVENT:
            if (event.user.code == IPADOS_EVENT_PENCIL_HOVER) {
                const float normalized_x = static_cast<float>(reinterpret_cast<uintptr_t>(event.user.data1)) / 1000000.0f;
                const float normalized_y = static_cast<float>(reinterpret_cast<uintptr_t>(event.user.data2)) / 1000000.0f;
                int x = 0;
                int y = 0;
                Set_Video_Mouse_Normalized(normalized_x, normalized_y, x, y);
                Video_Set_Touch_Feedback(x, y, true, false);
                Video_Record_Input_Timestamp(event.user.timestamp);
            } else if (event.user.code == IPADOS_EVENT_PENCIL_HOVER_END) {
                Video_Clear_Touch_Feedback();
                Video_Record_Input_Timestamp(event.user.timestamp);
            } else if (event.user.code == IPADOS_EVENT_PENCIL_DOUBLE_TAP) {
                int x = 0;
                int y = 0;
                Get_Video_Mouse(x, y);
                Put_Pencil_Mouse_Message(VK_RBUTTON, x, y, false);
                Put_Pencil_Mouse_Message(VK_RBUTTON, x, y, true);
                Video_Set_Touch_Feedback(x, y, true, true);
            } else if (event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_BEGIN
                       || event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_MOVE
                       || event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_END
                       || event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_CANCEL) {
                const float normalized_x =
                    static_cast<float>(reinterpret_cast<uintptr_t>(event.user.data1)) / 1000000.0f;
                const float normalized_y =
                    static_cast<float>(reinterpret_cast<uintptr_t>(event.user.data2)) / 1000000.0f;
                const IPadOSPencilSqueezeTransition transition = IPadOS_Advance_Pencil_Squeeze(
                    PencilSqueeze, event.user.code, normalized_x, normalized_y);
                int x = 0;
                int y = 0;
                Set_Video_Mouse_Normalized(normalized_x, normalized_y, x, y);
                Video_Record_Input_Timestamp(event.user.timestamp);
                if (transition.actions & IPADOS_PENCIL_SQUEEZE_PAN) {
                    PendingPanX += transition.delta_x;
                    PendingPanY += transition.delta_y;
                    PendingPanAt = event.user.timestamp;
                }
                if (transition.actions & IPADOS_PENCIL_SQUEEZE_BACK) {
                    Put_Key_Message(SDL_SCANCODE_ESCAPE, false);
                    Put_Key_Message(SDL_SCANCODE_ESCAPE, true);
                }
                if (event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_BEGIN
                    || event.user.code == IPADOS_EVENT_PENCIL_SQUEEZE_MOVE) {
                    Video_Set_Touch_Feedback(x, y, true, false);
                } else {
                    Video_Set_Touch_Feedback(x, y, true, true);
                }
            } else if (event.user.code == IPADOS_EVENT_AUDIO_PAUSE) {
                Focus_Loss();
            } else if (event.user.code == IPADOS_EVENT_AUDIO_RESET) {
                TiberianDawn_ConfigureAudioSession();
                TiberianDawn_RebuildAudioEngine();
                Focus_Restore();
            } else if (event.user.code == IPADOS_EVENT_AUDIO_RESUME
                       || event.user.code == IPADOS_EVENT_AUDIO_ROUTE_CHANGED) {
                TiberianDawn_ConfigureAudioSession();
                Focus_Restore();
#ifdef VISIONOS_PORT
            } else if (event.user.code == VISIONOS_EVENT_LOOK_SCROLL) {
                if (Settings.Vision.LookToScroll && !VisionInputState.drag_button_down) {
                    PendingVisionLookX += Vision_Event_Delta(event.user.data1);
                    PendingVisionLookY += Vision_Event_Delta(event.user.data2);
                    PendingVisionLookAt = event.user.timestamp;
                } else {
                    Discard_VisionOS_Look_Scroll();
                }
            } else if (event.user.code == VISIONOS_EVENT_PRIMARY_TAP
                       || event.user.code == VISIONOS_EVENT_DRAG_BEGIN
                       || event.user.code == VISIONOS_EVENT_DRAG_MOVE
                       || event.user.code == VISIONOS_EVENT_DRAG_END
                       || event.user.code == VISIONOS_EVENT_DRAG_CANCEL
                       || event.user.code == VISIONOS_EVENT_LONG_PRESS_BEGIN
                       || event.user.code == VISIONOS_EVENT_LONG_PRESS_MOVE
                       || event.user.code == VISIONOS_EVENT_LONG_PRESS_END) {
                const float normalized_x = Vision_Event_Coordinate(event.user.data1);
                const float normalized_y = Vision_Event_Coordinate(event.user.data2);
                int x = 0;
                int y = 0;
                Set_Video_Mouse_Normalized(normalized_x, normalized_y, x, y);
                Video_Record_Input_Timestamp(event.user.timestamp);
                if (event.user.code == VISIONOS_EVENT_PRIMARY_TAP
                    || event.user.code == VISIONOS_EVENT_DRAG_BEGIN
                    || event.user.code == VISIONOS_EVENT_LONG_PRESS_BEGIN) {
                    /* UIKit can finish a gesture while a cutscene, score
                    ** screen, lobby, or scenario loader is flushing events.
                    ** Every new top-level gaze/pinch gesture is authoritative:
                    ** discard any unmatched previous state before translating
                    ** it. This keeps all game modes on the same input path. */
                    VisionOS_Reset_Input(VisionInputState);
                    Reset_Mouse_Button_State();
                }
                const VisionOSInputConfiguration configuration = VisionOS_Input_Configuration(
                    Settings.Vision.EdgeSensitivity, Settings.Vision.ScrollSpeed);
                const VisionOSInputTransition transition =
                    VisionOS_Advance_Input(
                        VisionInputState, event.user.code, normalized_x, normalized_y, configuration);

                if (event.user.code == VISIONOS_EVENT_DRAG_BEGIN) {
                    Discard_VisionOS_Look_Scroll();
                }

                if (transition.actions & VISIONOS_ACTION_LEFT_PRESS) {
                    Put_Touch_Mouse_Message(VK_LBUTTON, x, y, false);
                }
                if (transition.actions & VISIONOS_ACTION_LEFT_RELEASE) {
                    Put_Touch_Mouse_Message(VK_LBUTTON, x, y, true);
                }
                if (transition.actions & VISIONOS_ACTION_RIGHT_PRESS) {
                    Put_Touch_Mouse_Message(VK_RBUTTON, x, y, false);
                }
                if (transition.actions & VISIONOS_ACTION_RIGHT_RELEASE) {
                    Put_Touch_Mouse_Message(VK_RBUTTON, x, y, true);
                }

                if (event.user.code == VISIONOS_EVENT_PRIMARY_TAP) {
                    Video_Set_Touch_Feedback(x, y, false, true);
                } else if (event.user.code == VISIONOS_EVENT_DRAG_BEGIN) {
                    Video_Set_Touch_Feedback(x, y, false, false);
                } else if (event.user.code == VISIONOS_EVENT_DRAG_MOVE) {
                    Video_Set_Touch_Feedback(x, y, false, false);
                } else if (event.user.code == VISIONOS_EVENT_DRAG_END
                           || event.user.code == VISIONOS_EVENT_DRAG_CANCEL) {
                    Video_Set_Touch_Feedback(x, y, false, true);
                } else if (event.user.code == VISIONOS_EVENT_LONG_PRESS_BEGIN) {
                    if (!VisionInputState.edge_scroll_active) {
                        Video_Set_Touch_Feedback(x, y, false, true);
                    }
                }
#endif
            }
            break;
#endif
        case SDL_TEXTINPUT:
            Queue_Text_Input(*this, event.text.text);
            break;
        case SDL_MOUSEMOTION: {
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
#ifdef IPADOS_PORT
            Video_Record_Input_Timestamp(event.motion.timestamp);
            if (event.motion.which != SDL_TOUCH_MOUSEID) Video_Set_Touch_Input(false);
            if (!Is_Gamepad_Active()) {
#endif
                int x = 0;
                int y = 0;
                Set_Video_Mouse_Window(event.motion.x, event.motion.y, x, y);
#ifdef IPADOS_PORT
            }
#endif
#else
            Move_Video_Mouse(static_cast<float>(event.motion.xrel), static_cast<float>(event.motion.yrel));
#endif
        } break;
        case SDL_MOUSEBUTTONDOWN:
        case SDL_MOUSEBUTTONUP: {
            int x, y;

            switch (event.button.button) {
            case SDL_BUTTON_LEFT:
            default:
                key = VK_LBUTTON;
                break;
            case SDL_BUTTON_RIGHT:
                key = VK_RBUTTON;
                break;
            case SDL_BUTTON_MIDDLE:
                key = VK_MBUTTON;
                break;
            }

#if defined(IPADOS_PORT) || defined(MACOS_PORT)
#ifdef IPADOS_PORT
            Video_Record_Input_Timestamp(event.button.timestamp);
            if (event.button.which != SDL_TOUCH_MOUSEID) Video_Set_Touch_Input(false);
#endif
            Set_Video_Mouse_Window(event.button.x, event.button.y, x, y);
#else
            if (Settings.Mouse.RawInput || Is_Gamepad_Active()) {
                Get_Video_Mouse(x, y);
            } else {
                float scale_x = 1.0f, scale_y = 1.0f;
                Get_Video_Scale(scale_x, scale_y);
                x = event.button.x / scale_x;
                y = event.button.y / scale_y;
            }
#endif

            Put_Mouse_Message(key, x, y, event.type == SDL_MOUSEBUTTONDOWN ? false : true);
        } break;
#ifdef IPADOS_PORT
        case SDL_FINGERDOWN:
            Video_Record_Input_Timestamp(event.tfinger.timestamp);
            Handle_Touch_Down(*this, event.tfinger);
            break;
        case SDL_FINGERMOTION:
            Video_Record_Input_Timestamp(event.tfinger.timestamp);
            Handle_Touch_Motion(*this, event.tfinger);
            break;
        case SDL_FINGERUP:
            Video_Record_Input_Timestamp(event.tfinger.timestamp);
            Handle_Touch_Up(*this, event.tfinger);
            break;
        case SDL_APP_TERMINATING:
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_TERMINATING);
            break;
        case SDL_APP_LOWMEMORY:
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_LOW_MEMORY);
            break;
        case SDL_APP_WILLENTERBACKGROUND:
        case SDL_APP_DIDENTERBACKGROUND:
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_BACKGROUND);
            break;
        case SDL_APP_DIDENTERFOREGROUND:
            Queue_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_FOREGROUND);
            break;
        case SDL_APP_WILLENTERFOREGROUND:
            break;
#endif
        case SDL_WINDOWEVENT:
            switch (event.window.event) {
            case SDL_WINDOWEVENT_RESIZED:
            case SDL_WINDOWEVENT_SIZE_CHANGED:
            case SDL_WINDOWEVENT_DISPLAY_CHANGED:
                Refresh_Video_Layout();
                break;
            case SDL_WINDOWEVENT_EXPOSED:
            case SDL_WINDOWEVENT_RESTORED:
            case SDL_WINDOWEVENT_FOCUS_GAINED:
#ifdef IPADOS_PORT
                Cancel_Touch_Gesture(*this);
                Reset_Touch_Gesture();
                Reset_Mouse_Button_State();
#endif
                Focus_Restore();
                break;
            case SDL_WINDOWEVENT_HIDDEN:
            case SDL_WINDOWEVENT_MINIMIZED:
            case SDL_WINDOWEVENT_FOCUS_LOST:
#ifdef IPADOS_PORT
                Cancel_Touch_Gesture(*this);
                Reset_Touch_Gesture();
                Reset_Mouse_Button_State();
#endif
                Focus_Loss();
                break;
            }
            break;
        case SDL_MOUSEWHEEL:
#ifdef IPADOS_PORT
            Video_Record_Input_Timestamp(event.wheel.timestamp);
#endif
            if (event.wheel.y > 0) { // scroll up
                Put_Key_Message(VK_MOUSEWHEEL_UP, false);
            } else if (event.wheel.y < 0) { // scroll down
                Put_Key_Message(VK_MOUSEWHEEL_DOWN, false);
            }
            break;
        case SDL_CONTROLLERDEVICEREMOVED:
            if (GameController != nullptr) {
                const SDL_GameController* removedController = SDL_GameControllerFromInstanceID(event.jdevice.which);
                if (removedController == GameController) {
                    SDL_GameControllerClose(GameController);
                    GameController = nullptr;
                    Open_Controller();
                }
            }
            break;
        case SDL_CONTROLLERDEVICEADDED:
            if (GameController == nullptr) {
                GameController = SDL_GameControllerOpen(event.jdevice.which);
                LastControllerTime = SDL_GetTicks();
            }
            break;
        case SDL_CONTROLLERAXISMOTION:
            Handle_Controller_Axis_Event(event.caxis);
            break;
        case SDL_CONTROLLERBUTTONDOWN:
        case SDL_CONTROLLERBUTTONUP:
            Handle_Controller_Button_Event(event.cbutton);
            break;
        }
    }
    if (Is_Gamepad_Active()) {
        Process_Controller_Axis_Motion();
    }

#ifdef IPADOS_PORT
    Update_Long_Press(*this);

    const uint32_t lifecycle_events = Consume_App_Lifecycle_Events();

    if (lifecycle_events & APP_LIFECYCLE_LOW_MEMORY) {
        Dispatch_App_Lifecycle_Event(APP_LIFECYCLE_LOW_MEMORY);
    }

    if (lifecycle_events & APP_LIFECYCLE_TERMINATING) {
        Cancel_Touch_Gesture(*this);
        Reset_Touch_Gesture();
        Focus_Loss();
        Dispatch_App_Lifecycle_Event(APP_LIFECYCLE_TERMINATING);
    } else {
        if (lifecycle_events & APP_LIFECYCLE_ENTERED_BACKGROUND) {
            Cancel_Touch_Gesture(*this);
            Reset_Touch_Gesture();
            Focus_Loss();
            Dispatch_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_BACKGROUND);
        }
        if (lifecycle_events & APP_LIFECYCLE_ENTERED_FOREGROUND) {
            Dispatch_App_Lifecycle_Event(APP_LIFECYCLE_ENTERED_FOREGROUND);
            Focus_Restore();
        }
    }
#endif
}

bool WWKeyboardClassSDL2::Is_Gamepad_Active()
{
    return GameController != nullptr;
}

void WWKeyboardClassSDL2::Open_Controller()
{
    if (GameController != nullptr && SDL_GameControllerGetAttached(GameController)) {
        return;
    }
    GameController = nullptr;
    for (int i = 0; i < SDL_NumJoysticks(); ++i) {
        if (SDL_IsGameController(i)) {
            GameController = SDL_GameControllerOpen(i);
            if (GameController != nullptr) {
                LastControllerTime = SDL_GetTicks();
                break;
            }
        }
    }
}

void WWKeyboardClassSDL2::Close_Controller()
{
    if (GameController != nullptr) {
        SDL_GameControllerClose(GameController);
        GameController = nullptr;
    }
}

void WWKeyboardClassSDL2::Process_Controller_Axis_Motion()
{
    const uint32_t currentTime = SDL_GetTicks();
    const float deltaTime = currentTime - LastControllerTime;
    LastControllerTime = currentTime;

    if (ControllerLeftXAxis != 0 || ControllerLeftYAxis != 0) {
        const int16_t xSign = (ControllerLeftXAxis > 0) - (ControllerLeftXAxis < 0);
        const int16_t ySign = (ControllerLeftYAxis > 0) - (ControllerLeftYAxis < 0);

        float movX = std::pow(std::abs(ControllerLeftXAxis), CONTROLLER_AXIS_SPEEDUP) * xSign * deltaTime
                     * Settings.Mouse.ControllerPointerSpeed / CONTROLLER_SPEED_MOD * ControllerSpeedBoost;
        float movY = std::pow(std::abs(ControllerLeftYAxis), CONTROLLER_AXIS_SPEEDUP) * ySign * deltaTime
                     * Settings.Mouse.ControllerPointerSpeed / CONTROLLER_SPEED_MOD * ControllerSpeedBoost;

        Move_Video_Mouse(movX, movY);
    }
}

void WWKeyboardClassSDL2::Handle_Controller_Axis_Event(const SDL_ControllerAxisEvent& motion)
{
#ifdef IPADOS_PORT
    Video_Record_Input_Timestamp(motion.timestamp);
#endif
    AnalogScrollActive = false;
    ScrollDirType directionX = SDIR_NONE;
    ScrollDirType directionY = SDIR_NONE;

    if (motion.axis == SDL_CONTROLLER_AXIS_LEFTX) {
        if (std::abs(motion.value) > CONTROLLER_L_DEADZONE)
            ControllerLeftXAxis = motion.value;
        else
            ControllerLeftXAxis = 0;
    } else if (motion.axis == SDL_CONTROLLER_AXIS_LEFTY) {
        if (std::abs(motion.value) > CONTROLLER_L_DEADZONE)
            ControllerLeftYAxis = motion.value;
        else
            ControllerLeftYAxis = 0;
    } else if (motion.axis == SDL_CONTROLLER_AXIS_RIGHTX) {
        if (std::abs(motion.value) > CONTROLLER_R_DEADZONE)
            ControllerRightXAxis = motion.value;
        else
            ControllerRightXAxis = 0;
    } else if (motion.axis == SDL_CONTROLLER_AXIS_RIGHTY) {
        if (std::abs(motion.value) > CONTROLLER_R_DEADZONE)
            ControllerRightYAxis = motion.value;
        else
            ControllerRightYAxis = 0;
    } else if (motion.axis == SDL_CONTROLLER_AXIS_TRIGGERRIGHT) {
        if (std::abs(motion.value) > CONTROLLER_TRIGGER_R_DEADZONE)
            ControllerSpeedBoost = 1 + (static_cast<float>(motion.value) / 32767) * CONTROLLER_TRIGGER_SPEEDUP;
        else
            ControllerSpeedBoost = 1;
    }

    if (ControllerRightXAxis != 0) {
        AnalogScrollActive = true;
        directionX = ControllerRightXAxis > 0 ? SDIR_E : SDIR_W;
    }
    if (ControllerRightYAxis != 0) {
        AnalogScrollActive = true;
        directionY = ControllerRightYAxis > 0 ? SDIR_S : SDIR_N;
    }

    if (directionX == SDIR_E && directionY == SDIR_N) {
        ScrollDirection = SDIR_NE;
    } else if (directionX == SDIR_E && directionY == SDIR_S) {
        ScrollDirection = SDIR_SE;
    } else if (directionX == SDIR_W && directionY == SDIR_N) {
        ScrollDirection = SDIR_NW;
    } else if (directionX == SDIR_W && directionY == SDIR_S) {
        ScrollDirection = SDIR_SW;
    } else if (directionX == SDIR_E) {
        ScrollDirection = SDIR_E;
    } else if (directionX == SDIR_W) {
        ScrollDirection = SDIR_W;
    } else if (directionY == SDIR_S) {
        ScrollDirection = SDIR_S;
    } else if (directionY == SDIR_N) {
        ScrollDirection = SDIR_N;
    }
}

void WWKeyboardClassSDL2::Handle_Controller_Button_Event(const SDL_ControllerButtonEvent& button)
{
#ifdef IPADOS_PORT
    Video_Record_Input_Timestamp(button.timestamp);
#endif
    bool keyboardPress = false;
    bool mousePress = false;
    unsigned short key;
    SDL_Scancode scancode;

    switch (button.button) {
    case SDL_CONTROLLER_BUTTON_A:
        mousePress = true;
        key = VK_LBUTTON;
        break;
    case SDL_CONTROLLER_BUTTON_B:
        mousePress = true;
        key = VK_RBUTTON;
        break;
    case SDL_CONTROLLER_BUTTON_X:
        keyboardPress = true;
        scancode = SDL_SCANCODE_G;
        break;
    case SDL_CONTROLLER_BUTTON_Y:
        keyboardPress = true;
        scancode = SDL_SCANCODE_F;
        break;
    case SDL_CONTROLLER_BUTTON_BACK:
        keyboardPress = true;
        scancode = SDL_SCANCODE_ESCAPE;
        break;
    case SDL_CONTROLLER_BUTTON_START:
        keyboardPress = true;
        scancode = SDL_SCANCODE_RETURN;
        break;
    case SDL_CONTROLLER_BUTTON_LEFTSHOULDER:
        keyboardPress = true;
        scancode = SDL_SCANCODE_LCTRL;
        break;
    case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER:
        keyboardPress = true;
        scancode = SDL_SCANCODE_LALT;
        break;
    case SDL_CONTROLLER_BUTTON_DPAD_UP:
        keyboardPress = true;
        scancode = SDL_SCANCODE_1;
        break;
    case SDL_CONTROLLER_BUTTON_DPAD_RIGHT:
        keyboardPress = true;
        scancode = SDL_SCANCODE_2;
        break;
    case SDL_CONTROLLER_BUTTON_DPAD_DOWN:
        keyboardPress = true;
        scancode = SDL_SCANCODE_3;
        break;
    case SDL_CONTROLLER_BUTTON_DPAD_LEFT:
        keyboardPress = true;
        scancode = SDL_SCANCODE_4;
        break;
    default:
        break;
    }

    if (keyboardPress) {
        Put_Key_Message(scancode, button.state == SDL_RELEASED);
    } else if (mousePress) {
        int x, y;
        Get_Video_Mouse(x, y);
        Put_Mouse_Message(key, x, y, button.state == SDL_RELEASED);
    }
}

#ifdef IPADOS_PORT
static bool WP_JoystickScroll(ScrollDirType& direction,float& intensity) {
    const auto stick=WPOrders::Shared().stick();
    if(stick.intensity<=0)return false;
    // The engine uses eight compass directions; preserve radial stick speed.
    const int octant=(static_cast<int>(std::lround(std::atan2(stick.y,stick.x)*4.0/3.141592653589793))+8)%8;
    static const ScrollDirType directions[]={SDIR_E,SDIR_SE,SDIR_S,SDIR_SW,SDIR_W,SDIR_NW,SDIR_N,SDIR_NE};
    direction=directions[octant];intensity=0.15f+0.60f*stick.intensity;
    return true;
}
#endif

bool WWKeyboardClassSDL2::Is_Analog_Scroll_Active()
{
#ifdef VISIONOS_PORT
    return AnalogScrollActive || VisionInputState.edge_scroll_active;
#elif defined(IPADOS_PORT)
    ScrollDirType touch_direction = SDIR_NONE;
    float touch_intensity = 0.0f;
    if (WP_JoystickScroll(touch_direction,touch_intensity)) return true;
    if (Current_IPad_Touch_Edge_Scroll(touch_direction, touch_intensity)) return true;
#endif
    return AnalogScrollActive;
}

unsigned char WWKeyboardClassSDL2::Get_Scroll_Direction()
{
#ifdef VISIONOS_PORT
    if (VisionInputState.edge_scroll_active) return VisionInputState.edge_scroll_direction;
#elif defined(IPADOS_PORT)
    ScrollDirType touch_direction = SDIR_NONE;
    float touch_intensity = 0.0f;
    if (WP_JoystickScroll(touch_direction,touch_intensity)) return touch_direction;
    if (Current_IPad_Touch_Edge_Scroll(touch_direction, touch_intensity)) return touch_direction;
#endif
    return ScrollDirection;
}

float WWKeyboardClassSDL2::Get_Scroll_Intensity()
{
#ifdef VISIONOS_PORT
    if (VisionInputState.edge_scroll_active) return VisionInputState.edge_scroll_intensity;
#elif defined(IPADOS_PORT)
    ScrollDirType touch_direction = SDIR_NONE;
    float touch_intensity = 0.0f;
    if (WP_JoystickScroll(touch_direction,touch_intensity)) return touch_intensity;
    if (Current_IPad_Touch_Edge_Scroll(touch_direction, touch_intensity)) return touch_intensity;
#endif
    return 1.0f;
}

KeyASCIIType WWKeyboardClassSDL2::To_ASCII(unsigned short key)
{
    if (key & WWKEY_TEXT_BIT) {
        return static_cast<KeyASCIIType>(key & 0xFF);
    }
    if (key & WWKEY_RLS_BIT) {
        return KA_NONE;
    }

    key &= 0xFF; // drop all mods

    if (key > ARRAY_SIZE(sdl_keymap) / 2 - 1) {
        return KA_NONE;
    }

    if (SDL_GetModState() & KMOD_SHIFT) {
        return sdl_keymap[key + ARRAY_SIZE(sdl_keymap) / 2];
    } else {
        return sdl_keymap[key];
    }
}

WWKeyboardClass* CreateWWKeyboardClass(void)
{
    return new WWKeyboardClassSDL2;
}
