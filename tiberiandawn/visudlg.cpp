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

/* $Header:   F:\projects\c&c\vcs\code\visudlg.cpv   2.17   16 Oct 1995 16:51:40   JOE_BOSTIC  $ */
/***********************************************************************************************
 ***             C O N F I D E N T I A L  ---  W E S T W O O D   S T U D I O S               ***
 ***********************************************************************************************
 *                                                                                             *
 *                 Project Name : Command & Conquer                                            *
 *                                                                                             *
 *                    File Name : VISUDLG.CPP                                                  *
 *                                                                                             *
 *                   Programmer : Maria del Mar McCready Legg                                  *
 *                                  Joe L. Bostic                                              *
 *                                                                                             *
 *                   Start Date : Jan 8, 1995                                                  *
 *                                                                                             *
 *                  Last Update : June 18, 1995 [JLB]                                          *
 *                                                                                             *
 *---------------------------------------------------------------------------------------------*
 * Functions:                                                                                  *
 *   VisualControlsClass::Process -- Process the visual control dialog box.                    *
 * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

#include "function.h"
#include "visudlg.h"
#include "common/framelimit.h"
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
#include "common/settings.h"
#include "common/video.h"
#ifdef VISIONOS_PORT
#include "common/ipados_touch.h"
#endif
#ifdef IPADOS_PORT
#include "platform/apple/ipados_platform.h"
#else
#include "platform/apple/macos_platform.h"
#endif
#include <cstdio>
#endif

#if defined(IPADOS_PORT) || defined(MACOS_PORT)
namespace
{
const char* Presentation_Mode_Text(int mode)
{
    if (mode == 3) return "Fill display";
    switch (mode) {
    case 1:
        return TiberianDawn_LocalizedText("visual_mode_pixel");
    case 2:
        return TiberianDawn_LocalizedText("visual_mode_classic");
    default:
        return TiberianDawn_LocalizedText("visual_mode_sharp");
    }
}

const char* Artwork_Mode_Text(int mode)
{
    return TiberianDawn_LocalizedText(mode == 1 ? "visual_artwork_modern" : "visual_artwork_original");
}

const char* Three_Level_Text(int level, const char* low, const char* high)
{
    if (level == 0) return TiberianDawn_LocalizedText(low);
    if (level == 2) return TiberianDawn_LocalizedText(high);
    return TiberianDawn_LocalizedText("vision_level_balanced");
}
}
#endif

int VisualControlsClass::Init(void)
{
    int factor = (SeenBuff.Get_Width() == 320) ? 1 : 2;
    Option_Width = 216 * factor;
    Option_Height =
#ifdef IPADOS_PORT
        196 * factor;
#elif defined(IPADOS_PORT) || defined(MACOS_PORT)
        160 * factor;
#else
        122 * factor;
#endif
    Option_X = (((SeenBuff.Get_Width() - Option_Width) / 2));
    Option_Y = ((SeenBuff.Get_Height() - Option_Height) / 2);
    Text_X = Option_X + (28 * factor);
    Text_Y = Option_Y + (30 * factor);
    Slider_X = Option_X + (105 * factor);
    Slider_Y = Option_Y + (30 * factor);
    Slider_Width = 70 * factor;
    Slider_Height = 5 * factor;
    Slider_Y_Spacing = 11 * factor;
    Button_X = Option_X + (63 * factor);
    Button_Y = Option_Y + (
#ifdef IPADOS_PORT
        176
#elif defined(IPADOS_PORT) || defined(MACOS_PORT)
        140
#else
        102
#endif
        * factor);
    return (factor);
}
/***********************************************************************************************
 * VisualControlsClass::Process -- Process the visual control dialog box.                      *
 *                                                                                             *
 *    This routine displays and processes the visual controls dialog box.                      *
 *                                                                                             *
 * INPUT:   none                                                                               *
 *                                                                                             *
 * OUTPUT:  none                                                                               *
 *                                                                                             *
 * WARNINGS:   none                                                                            *
 *                                                                                             *
 * HISTORY:                                                                                    *
 *   06/18/1995 JLB : Created.                                                                 *
 *=============================================================================================*/
void VisualControlsClass::Process(void)
{
    static int _titles[4] = {TXT_BRIGHTNESS, TXT_COLOR, TXT_CONTRAST, TXT_TINT};

    enum
    {
        NUM_OF_BUTTONS = 6,
    };

    /*
    **	Variables.
    */
    int selection;
    int factor;
    bool pressed;
    int curbutton;
    TextButtonClass* buttons[NUM_OF_BUTTONS];
    SliderClass* buttonsliders[NUM_OF_BUTTONS];

    factor = Init();
    Set_Logic_Page(SeenBuff);

    /*
    **	Create Buttons.  Button coords are in pixels, but are window-relative.
    */
    TextButtonClass optionsbtn(BUTTON_OPTIONS, TXT_GAME_CONTROLS, TPF_6PT_GRAD | TPF_NOSHADOW, 0, Button_Y);

    TextButtonClass resetbtn(BUTTON_RESET, TXT_RESET_MENU, TPF_6PT_GRAD | TPF_NOSHADOW, 0, Button_Y);

#if defined(IPADOS_PORT) || defined(MACOS_PORT)
    char presentation_text[48];
    char artwork_text[48];
    char scale_text[48];
    char accessibility_text[48];
    std::snprintf(presentation_text,
                  sizeof(presentation_text),
                  TiberianDawn_LocalizedText("visual_image_format"),
                  Presentation_Mode_Text(Settings.Video.PresentationMode));
    std::snprintf(artwork_text,
                  sizeof(artwork_text),
                  TiberianDawn_LocalizedText("visual_artwork_format"),
                  Artwork_Mode_Text(Settings.Video.ArtworkMode));
    std::snprintf(scale_text,
                  sizeof(scale_text),
                  TiberianDawn_LocalizedText("visual_ui_format"),
                  Settings.Video.TouchUIScale);
    std::snprintf(accessibility_text,
                  sizeof(accessibility_text),
                  TiberianDawn_LocalizedText("visual_readability_format"),
                  TiberianDawn_LocalizedText(Settings.Video.HighContrast ? "visual_readability_high"
                                                                      : "visual_readability_normal"));
    TextButtonClass presentationbtn(BUTTON_IPAD_PRESENTATION,
                                    presentation_text,
                                    TPF_6PT_GRAD | TPF_NOSHADOW,
                                    Option_X + 15 * factor,
                                    Option_Y + 78 * factor,
                                    88 * factor,
                                    11 * factor);
    TextButtonClass scalebtn(BUTTON_IPAD_UI_SCALE,
                             scale_text,
                             TPF_6PT_GRAD | TPF_NOSHADOW,
                             Option_X + 113 * factor,
                             Option_Y + 78 * factor,
                             88 * factor,
                             11 * factor);
    TextButtonClass artworkbtn(BUTTON_IPAD_ARTWORK,
                               artwork_text,
                               TPF_6PT_GRAD | TPF_NOSHADOW,
                               Option_X + 15 * factor,
                               Option_Y + 94 * factor,
                               88 * factor,
                               11 * factor);
    TextButtonClass accessibilitybtn(BUTTON_IPAD_ACCESSIBILITY,
                                     accessibility_text,
                                     TPF_6PT_GRAD | TPF_NOSHADOW,
                                     Option_X + 113 * factor,
                                     Option_Y + 94 * factor,
                                     88 * factor,
                                     11 * factor);
#if defined(IPADOS_PORT) && !defined(VISIONOS_PORT)
    char touch_edge_text[48];
    char touch_scroll_text[48];
    char touch_selection_text[48];
    std::snprintf(touch_edge_text,
                  sizeof(touch_edge_text),
                  TiberianDawn_LocalizedText("touch_edge_scroll_format"),
                  TiberianDawn_LocalizedText(Settings.Touch.EdgeScroll ? "state_on" : "state_off"));
    std::snprintf(touch_scroll_text,
                  sizeof(touch_scroll_text),
                  TiberianDawn_LocalizedText("touch_scroll_speed_format"),
                  Three_Level_Text(Settings.Touch.ScrollSpeed, "vision_level_slow", "vision_level_fast"));
    std::snprintf(touch_selection_text,
                  sizeof(touch_selection_text),
                  TiberianDawn_LocalizedText("touch_selection_format"),
                  Three_Level_Text(Settings.Touch.SelectionTolerance,
                                   "vision_level_precise",
                                   "vision_level_forgiving"));
    TextButtonClass touchedgebtn(BUTTON_IPAD_TOUCH_EDGE_SCROLL,
                                 touch_edge_text,
                                 TPF_6PT_GRAD | TPF_NOSHADOW,
                                 Option_X + 15 * factor,
                                 Option_Y + 110 * factor,
                                 88 * factor,
                                 11 * factor);
    TextButtonClass touchscrollbtn(BUTTON_IPAD_TOUCH_SCROLL_SPEED,
                                   touch_scroll_text,
                                   TPF_6PT_GRAD | TPF_NOSHADOW,
                                   Option_X + 113 * factor,
                                   Option_Y + 110 * factor,
                                   88 * factor,
                                   11 * factor);
    TextButtonClass touchselectionbtn(BUTTON_IPAD_TOUCH_SELECTION_TOLERANCE,
                                      touch_selection_text,
                                      TPF_6PT_GRAD | TPF_NOSHADOW,
                                      Option_X + 15 * factor,
                                      Option_Y + 126 * factor,
                                      88 * factor,
                                      11 * factor);
    TextButtonClass touchhelpbtn(BUTTON_IPAD_TOUCH_HELP,
                                 TiberianDawn_LocalizedText("touch_help_button"),
                                 TPF_6PT_GRAD | TPF_NOSHADOW,
                                 Option_X + 113 * factor,
                                 Option_Y + 126 * factor,
                                 88 * factor,
                                 11 * factor);
#endif
#ifdef VISIONOS_PORT
    char look_scroll_text[48];
    char scroll_speed_text[48];
    char edge_sensitivity_text[48];
    char selection_tolerance_text[48];
    std::snprintf(look_scroll_text,
                  sizeof(look_scroll_text),
                  TiberianDawn_LocalizedText("vision_look_scroll_format"),
                  TiberianDawn_LocalizedText(Settings.Vision.LookToScroll ? "state_on" : "state_off"));
    std::snprintf(scroll_speed_text,
                  sizeof(scroll_speed_text),
                  TiberianDawn_LocalizedText("vision_scroll_speed_format"),
                  Three_Level_Text(
                      Settings.Vision.ScrollSpeed, "vision_level_slow", "vision_level_fast"));
    std::snprintf(edge_sensitivity_text,
                  sizeof(edge_sensitivity_text),
                  TiberianDawn_LocalizedText("vision_edge_format"),
                  Three_Level_Text(
                      Settings.Vision.EdgeSensitivity, "vision_level_narrow", "vision_level_wide"));
    std::snprintf(selection_tolerance_text,
                  sizeof(selection_tolerance_text),
                  TiberianDawn_LocalizedText("vision_selection_format"),
                  Three_Level_Text(Settings.Vision.SelectionTolerance,
                                          "vision_level_precise",
                                          "vision_level_forgiving"));
    TextButtonClass lookscrollbtn(BUTTON_VISION_LOOK_SCROLL,
                                  look_scroll_text,
                                  TPF_6PT_GRAD | TPF_NOSHADOW,
                                  Option_X + 15 * factor,
                                  Option_Y + 110 * factor,
                                  88 * factor,
                                  11 * factor);
    TextButtonClass scrollspeedbtn(BUTTON_VISION_SCROLL_SPEED,
                                   scroll_speed_text,
                                   TPF_6PT_GRAD | TPF_NOSHADOW,
                                   Option_X + 113 * factor,
                                   Option_Y + 110 * factor,
                                   88 * factor,
                                   11 * factor);
    TextButtonClass edgebtn(BUTTON_VISION_EDGE_SENSITIVITY,
                            edge_sensitivity_text,
                            TPF_6PT_GRAD | TPF_NOSHADOW,
                            Option_X + 15 * factor,
                            Option_Y + 126 * factor,
                            88 * factor,
                            11 * factor);
    TextButtonClass selectionbtn(BUTTON_VISION_SELECTION_TOLERANCE,
                                 selection_tolerance_text,
                                 TPF_6PT_GRAD | TPF_NOSHADOW,
                                 Option_X + 113 * factor,
                                 Option_Y + 126 * factor,
                                 88 * factor,
                                 11 * factor);
#endif
#endif

    /*
    **	Centers options button.
    */
    optionsbtn.X = Option_X + (Option_Width - optionsbtn.Width - (15 * factor));
    resetbtn.X = Option_X + (15 * factor);

    resetbtn.Add_Tail(optionsbtn);
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
    presentationbtn.Add_Tail(optionsbtn);
    scalebtn.Add_Tail(optionsbtn);
    artworkbtn.Add_Tail(optionsbtn);
    accessibilitybtn.Add_Tail(optionsbtn);
#if defined(IPADOS_PORT) && !defined(VISIONOS_PORT)
    touchedgebtn.Add_Tail(optionsbtn);
    touchscrollbtn.Add_Tail(optionsbtn);
    touchselectionbtn.Add_Tail(optionsbtn);
    touchhelpbtn.Add_Tail(optionsbtn);
#endif
#ifdef VISIONOS_PORT
    lookscrollbtn.Add_Tail(optionsbtn);
    scrollspeedbtn.Add_Tail(optionsbtn);
    edgebtn.Add_Tail(optionsbtn);
    selectionbtn.Add_Tail(optionsbtn);
#endif
#endif

    /*
    **	Brightness (value) control.
    */
    SliderClass brightness(BUTTON_BRIGHTNESS, Slider_X, Slider_Y + (Slider_Y_Spacing * 0), Slider_Width, Slider_Height);
    brightness.Set_Thumb_Size(20);
    brightness.Set_Value(Options.Get_Brightness());
    brightness.Add_Tail(optionsbtn);

    /*
    **	Color (saturation) control.
    */
    SliderClass color(BUTTON_COLOR, Slider_X, Slider_Y + (Slider_Y_Spacing * 1), Slider_Width, Slider_Height);
    color.Set_Thumb_Size(20);
    color.Set_Value(Options.Get_Color());
    color.Add_Tail(optionsbtn);

    /*
    **	Contrast control.
    */
    SliderClass contrast(BUTTON_CONTRAST, Slider_X, Slider_Y + (Slider_Y_Spacing * 2), Slider_Width, Slider_Height);
    contrast.Set_Thumb_Size(20);
    contrast.Set_Value(Options.Get_Contrast());
    contrast.Add_Tail(optionsbtn);

    /*
    **	Tint (hue) control.
    */
    SliderClass tint(BUTTON_TINT, Slider_X, Slider_Y + (Slider_Y_Spacing * 3), Slider_Width, Slider_Height);
    tint.Set_Thumb_Size(20);
    tint.Set_Value(Options.Get_Tint());
    tint.Add_Tail(optionsbtn);

    /*
    **	This causes left mouse button clicking within the confines of the dialog to
    **	be ignored if it wasn't recognized by any other button or slider.
    */
    GadgetClass dialog(Option_X, Option_Y, Option_Width, Option_Height, GadgetClass::LEFTPRESS);
    dialog.Add_Tail(optionsbtn);

    /*
    **	This causes a right click anywhere or a left click outside the dialog region
    **	to be equivalent to clicking on the return to options dialog.
    */
    ControlClass background(BUTTON_OPTIONS,
                            0,
                            0,
                            SeenBuff.Get_Width(),
                            SeenBuff.Get_Height(),
                            GadgetClass::LEFTPRESS | GadgetClass::RIGHTPRESS);
    background.Add_Tail(optionsbtn);

    curbutton = 0;
    buttons[0] = NULL;
    buttons[1] = NULL;
    buttons[2] = NULL;
    buttons[3] = NULL;
    buttons[4] = &resetbtn;
    buttons[5] = &optionsbtn;

    buttonsliders[0] = &brightness;
    buttonsliders[1] = &color;
    buttonsliders[2] = &contrast;
    buttonsliders[3] = &tint;
    buttonsliders[4] = NULL;
    buttonsliders[5] = NULL;

    /*
    **	Main Processing Loop.
    */
    bool display = true;
    bool process = true;
    bool partial = true;
    pressed = false;
    while (process) {

        /*
        **	Invoke game callback.
        */
        if (GameToPlay == GAME_NORMAL || GameToPlay == GAME_SKIRMISH) {
            Call_Back();
        } else {
            if (Main_Loop()) {
                process = false;
            }
        }

        /*
        ** If we have just received input focus again after running in the background then
        ** we need to redraw.
        */
        if (AllSurfaces.SurfacesRestored) {
            AllSurfaces.SurfacesRestored = false;
            display = true;
        }

        /*
        **	Refresh display if needed.
        */
        if (display) {
            Hide_Mouse();
            Dialog_Box(Option_X, Option_Y, Option_Width, Option_Height);
            Draw_Caption(TXT_VISUAL_CONTROLS, Option_X, Option_Y, Option_Width);
            Show_Mouse();
            display = false;
            partial = true;
        }

        /*
        **	If just the buttons and captions need to be redrawn, then do so now.
        */
        if (partial) {
            Hide_Mouse();

            /*
            **	Draw the titles.
            */
            for (int i = 0; i < (sizeof(_titles) / sizeof(_titles[0])); i++) {
                Fancy_Text_Print(_titles[i],
                                 Slider_X - 8,
                                 Text_Y + (i * Slider_Y_Spacing),
                                 CC_GREEN,
                                 TBLACK,
                                 TPF_6PT_GRAD | TPF_RIGHT | TPF_NOSHADOW
                                     | ((curbutton == i) ? TPF_BRIGHT_COLOR : TPF_USE_GRAD_PAL));
            }
            optionsbtn.Draw_All();
            Show_Mouse();
            partial = false;
        }

        /*
        **	Get and process player input.
        */
        KeyNumType input = optionsbtn.Input();
        switch (input) {
        case (BUTTON_BRIGHTNESS | KN_BUTTON):
            Options.Set_Brightness(brightness.Get_Value());
            break;

        case (BUTTON_COLOR | KN_BUTTON):
            Options.Set_Color(color.Get_Value());
            break;

        case (BUTTON_CONTRAST | KN_BUTTON):
            Options.Set_Contrast(contrast.Get_Value());
            break;

        case (BUTTON_TINT | KN_BUTTON):
            Options.Set_Tint(tint.Get_Value());
            break;

#if defined(IPADOS_PORT) || defined(MACOS_PORT)
        case (BUTTON_IPAD_PRESENTATION | KN_BUTTON):
            Settings.Video.PresentationMode = (Settings.Video.PresentationMode + 1) % 4;
            std::snprintf(presentation_text,
                          sizeof(presentation_text),
                          TiberianDawn_LocalizedText("visual_image_format"),
                          Presentation_Mode_Text(Settings.Video.PresentationMode));
            presentationbtn.Set_Text(presentation_text, false);
            presentationbtn.Flag_To_Redraw();
            Refresh_Video_Layout();
            break;

        case (BUTTON_IPAD_UI_SCALE | KN_BUTTON):
            Settings.Video.TouchUIScale = Settings.Video.TouchUIScale < 125 ? 125
                                              : (Settings.Video.TouchUIScale < 150 ? 150 : 100);
            std::snprintf(scale_text,
                          sizeof(scale_text),
                          TiberianDawn_LocalizedText("visual_ui_format"),
                          Settings.Video.TouchUIScale);
            scalebtn.Set_Text(scale_text, false);
            scalebtn.Flag_To_Redraw();
            break;

        case (BUTTON_IPAD_ARTWORK | KN_BUTTON):
            Settings.Video.ArtworkMode = Settings.Video.ArtworkMode == 0 ? 1 : 0;
            std::snprintf(artwork_text,
                          sizeof(artwork_text),
                          TiberianDawn_LocalizedText("visual_artwork_format"),
                          Artwork_Mode_Text(Settings.Video.ArtworkMode));
            artworkbtn.Set_Text(artwork_text, false);
            artworkbtn.Flag_To_Redraw();
            Refresh_Video_Layout();
            break;

        case (BUTTON_IPAD_ACCESSIBILITY | KN_BUTTON):
            Settings.Video.HighContrast = !Settings.Video.HighContrast;
            Settings.Video.LargeCursor = Settings.Video.HighContrast;
            std::snprintf(accessibility_text,
                          sizeof(accessibility_text),
                          TiberianDawn_LocalizedText("visual_readability_format"),
                          TiberianDawn_LocalizedText(Settings.Video.HighContrast ? "visual_readability_high"
                                                                              : "visual_readability_normal"));
            accessibilitybtn.Set_Text(accessibility_text, false);
            accessibilitybtn.Flag_To_Redraw();
            Refresh_Video_Layout();
            break;
#if defined(IPADOS_PORT) && !defined(VISIONOS_PORT)
        case (BUTTON_IPAD_TOUCH_EDGE_SCROLL | KN_BUTTON):
            Settings.Touch.EdgeScroll = !Settings.Touch.EdgeScroll;
            std::snprintf(touch_edge_text,
                          sizeof(touch_edge_text),
                          TiberianDawn_LocalizedText("touch_edge_scroll_format"),
                          TiberianDawn_LocalizedText(Settings.Touch.EdgeScroll ? "state_on" : "state_off"));
            touchedgebtn.Set_Text(touch_edge_text, false);
            touchedgebtn.Flag_To_Redraw();
            break;

        case (BUTTON_IPAD_TOUCH_SCROLL_SPEED | KN_BUTTON):
            Settings.Touch.ScrollSpeed = (Settings.Touch.ScrollSpeed + 1) % 3;
            std::snprintf(touch_scroll_text,
                          sizeof(touch_scroll_text),
                          TiberianDawn_LocalizedText("touch_scroll_speed_format"),
                          Three_Level_Text(Settings.Touch.ScrollSpeed,
                                           "vision_level_slow",
                                           "vision_level_fast"));
            touchscrollbtn.Set_Text(touch_scroll_text, false);
            touchscrollbtn.Flag_To_Redraw();
            break;

        case (BUTTON_IPAD_TOUCH_SELECTION_TOLERANCE | KN_BUTTON):
            Settings.Touch.SelectionTolerance = (Settings.Touch.SelectionTolerance + 1) % 3;
            std::snprintf(touch_selection_text,
                          sizeof(touch_selection_text),
                          TiberianDawn_LocalizedText("touch_selection_format"),
                          Three_Level_Text(Settings.Touch.SelectionTolerance,
                                           "vision_level_precise",
                                           "vision_level_forgiving"));
            touchselectionbtn.Set_Text(touch_selection_text, false);
            touchselectionbtn.Flag_To_Redraw();
            break;

        case (BUTTON_IPAD_TOUCH_HELP | KN_BUTTON):
            TiberianDawn_ShowTouchControls(true);
            Keyboard->Clear();
            display = true;
            partial = true;
            break;
#endif
#ifdef VISIONOS_PORT
        case (BUTTON_VISION_LOOK_SCROLL | KN_BUTTON):
            Settings.Vision.LookToScroll = !Settings.Vision.LookToScroll;
            if (!Settings.Vision.LookToScroll) Discard_VisionOS_Look_Scroll();
            std::snprintf(look_scroll_text,
                          sizeof(look_scroll_text),
                          TiberianDawn_LocalizedText("vision_look_scroll_format"),
                          TiberianDawn_LocalizedText(Settings.Vision.LookToScroll ? "state_on" : "state_off"));
            lookscrollbtn.Set_Text(look_scroll_text, false);
            lookscrollbtn.Flag_To_Redraw();
            break;

        case (BUTTON_VISION_SCROLL_SPEED | KN_BUTTON):
            Settings.Vision.ScrollSpeed = (Settings.Vision.ScrollSpeed + 1) % 3;
            std::snprintf(scroll_speed_text,
                          sizeof(scroll_speed_text),
                          TiberianDawn_LocalizedText("vision_scroll_speed_format"),
                          Three_Level_Text(
                              Settings.Vision.ScrollSpeed, "vision_level_slow", "vision_level_fast"));
            scrollspeedbtn.Set_Text(scroll_speed_text, false);
            scrollspeedbtn.Flag_To_Redraw();
            break;

        case (BUTTON_VISION_EDGE_SENSITIVITY | KN_BUTTON):
            Settings.Vision.EdgeSensitivity = (Settings.Vision.EdgeSensitivity + 1) % 3;
            std::snprintf(edge_sensitivity_text,
                          sizeof(edge_sensitivity_text),
                          TiberianDawn_LocalizedText("vision_edge_format"),
                          Three_Level_Text(Settings.Vision.EdgeSensitivity,
                                                  "vision_level_narrow",
                                                  "vision_level_wide"));
            edgebtn.Set_Text(edge_sensitivity_text, false);
            edgebtn.Flag_To_Redraw();
            break;

        case (BUTTON_VISION_SELECTION_TOLERANCE | KN_BUTTON):
            Settings.Vision.SelectionTolerance = (Settings.Vision.SelectionTolerance + 1) % 3;
            std::snprintf(selection_tolerance_text,
                          sizeof(selection_tolerance_text),
                          TiberianDawn_LocalizedText("vision_selection_format"),
                          Three_Level_Text(Settings.Vision.SelectionTolerance,
                                                  "vision_level_precise",
                                                  "vision_level_forgiving"));
            selectionbtn.Set_Text(selection_tolerance_text, false);
            selectionbtn.Flag_To_Redraw();
            break;
#endif
#endif

        case (BUTTON_RESET | KN_BUTTON):
            selection = BUTTON_RESET;
            pressed = true;
            break;

        case KN_ESC:
        case BUTTON_OPTIONS | KN_BUTTON:
            selection = BUTTON_OPTIONS;
            pressed = true;
            break;

        case (KN_LEFT):
            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                buttonsliders[curbutton]->Bump(1);
                switch (curbutton) {
                case (BUTTON_BRIGHTNESS - BUTTON_BRIGHTNESS):
                    Options.Set_Brightness(brightness.Get_Value());
                    break;

                case (BUTTON_COLOR - BUTTON_BRIGHTNESS):
                    Options.Set_Color(color.Get_Value());
                    break;

                case (BUTTON_CONTRAST - BUTTON_BRIGHTNESS):
                    Options.Set_Contrast(contrast.Get_Value());
                    break;

                case (BUTTON_TINT - BUTTON_BRIGHTNESS):
                    Options.Set_Tint(tint.Get_Value());
                    break;
                }
            } else {
                buttons[curbutton]->Turn_Off();
                buttons[curbutton]->Flag_To_Redraw();

                curbutton--;
                if (curbutton < (BUTTON_RESET - BUTTON_BRIGHTNESS)) {
                    curbutton = (BUTTON_OPTIONS - BUTTON_BRIGHTNESS);
                }

                buttons[curbutton]->Turn_On();
                buttons[curbutton]->Flag_To_Redraw();
            }
            break;

        case (KN_RIGHT):
            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                buttonsliders[curbutton]->Bump(0);
                switch (curbutton) {
                case (BUTTON_BRIGHTNESS - BUTTON_BRIGHTNESS):
                    Options.Set_Brightness(brightness.Get_Value());
                    break;

                case (BUTTON_COLOR - BUTTON_BRIGHTNESS):
                    Options.Set_Color(color.Get_Value());
                    break;

                case (BUTTON_CONTRAST - BUTTON_BRIGHTNESS):
                    Options.Set_Contrast(contrast.Get_Value());
                    break;

                case (BUTTON_TINT - BUTTON_BRIGHTNESS):
                    Options.Set_Tint(tint.Get_Value());
                    break;
                }
            } else {
                buttons[curbutton]->Turn_Off();
                buttons[curbutton]->Flag_To_Redraw();

                curbutton++;
                if (curbutton > (BUTTON_OPTIONS - BUTTON_BRIGHTNESS)) {
                    curbutton = (BUTTON_RESET - BUTTON_BRIGHTNESS);
                }

                buttons[curbutton]->Turn_On();
                buttons[curbutton]->Flag_To_Redraw();
            }
            break;

        case (KN_UP):
            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                partial = true;
            } else {
                buttons[curbutton]->Turn_Off();
                buttons[curbutton]->Flag_To_Redraw();
            }

            curbutton--;
            if (curbutton == (BUTTON_RESET - BUTTON_BRIGHTNESS)) {
                curbutton--;
            }

            if (curbutton < 0) {
                curbutton = (BUTTON_RESET - BUTTON_BRIGHTNESS);
            }

            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                partial = true;
            } else {
                buttons[curbutton]->Turn_On();
                buttons[curbutton]->Flag_To_Redraw();
            }
            break;

        case (KN_DOWN):
            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                partial = true;
            } else {
                buttons[curbutton]->Turn_Off();
                buttons[curbutton]->Flag_To_Redraw();
            }

            curbutton++;
            if (curbutton > (BUTTON_RESET - BUTTON_BRIGHTNESS)) {
                curbutton = 0;
            }

            if (curbutton <= (BUTTON_TINT - BUTTON_BRIGHTNESS)) {
                partial = true;
            } else {
                buttons[curbutton]->Turn_On();
                buttons[curbutton]->Flag_To_Redraw();
            }
            break;

        case (KN_RETURN):
            selection = curbutton + BUTTON_BRIGHTNESS;
            pressed = true;
            break;

        default:
            break;
        }

        if (pressed) {
            switch (selection) {
            case (BUTTON_RESET):
                brightness.Set_Value(128);
                contrast.Set_Value(128);
                color.Set_Value(128);
                tint.Set_Value(128);

                Options.Set_Brightness(128);
                Options.Set_Contrast(128);
                Options.Set_Color(128);
                Options.Set_Tint(128);
                break;

            case (BUTTON_OPTIONS):
                process = false;
                break;
            }

            pressed = false;
        }

        Frame_Limiter();
    }
}
