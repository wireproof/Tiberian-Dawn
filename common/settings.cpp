#include "wwstd.h"
#include "settings.h"
#include "ini.h"
#include "miscasm.h"

SettingsClass Settings;

SettingsClass::SettingsClass()
{
    /*
    ** Mouse settings
    */
#ifdef MACOS_PORT
    // Absolute Cocoa coordinates are predictable in Retina/resizable windows
    // and do not trap the pointer on first launch.
    Mouse.RawInput = false;
#else
    Mouse.RawInput = true;
#endif
    Mouse.Sensitivity = 100;
    Mouse.ControllerEnabled = false;
    Mouse.ControllerPointerSpeed = 10;
    Options.MouseWheelScrolling = true;
    Touch.EdgeScroll = true;
    Touch.ScrollSpeed = 1;
    Touch.SelectionTolerance = 1;
    Vision.LookToScroll = true;
    Vision.ScrollSpeed = 1;
    Vision.EdgeSensitivity = 1;
    Vision.SelectionTolerance = 1;

    /*
    ** Video settings
    */
#ifdef MACOS_PORT
    // Start large enough to be comfortable on a modern Mac while retaining
    // the game's native 16:10 aspect ratio. Set_Video_Mode clamps this to the
    // usable display area on smaller screens.
    Video.WindowWidth = 1200;
    Video.WindowHeight = 750;
    Video.Windowed = true;
#else
    Video.WindowWidth = 640;
    Video.WindowHeight = 400;
    Video.Windowed = false;
#endif
    Video.Width = 0;
    Video.Height = 0;
    Video.Boxing = true;
    Video.BoxingAspectRatio = "16:10";
#ifdef IPADOS_PORT
    Video.FrameLimit = 60;
#else
    Video.FrameLimit = 120;
#endif
    Video.BatterySaving = false;
    Video.PresentationMode = 0;
    Video.ArtworkMode = 0;
    Video.TouchUIScale = 100;
    Video.LargeCursor = false;
    Video.HighContrast = false;
    Video.InterpolationMode = 2;
    Video.HardwareCursor = false;
    Video.DOSMode = false;
    Video.Scaler = "nearest";
    Video.Driver = "default";
    Video.PixelFormat = "default";
}

void SettingsClass::Load(INIClass& ini)
{
    char buf[128];

    /*
    ** Mouse settings
    */
    Mouse.RawInput = ini.Get_Bool("Mouse", "RawInput", Mouse.RawInput);
    Mouse.Sensitivity = ini.Get_Int("Mouse", "Sensitivity", Mouse.Sensitivity);
    Mouse.ControllerEnabled = ini.Get_Bool("Mouse", "ControllerEnabled", Mouse.ControllerEnabled);
    Mouse.ControllerPointerSpeed = ini.Get_Int("Mouse", "ControllerPointerSpeed", Mouse.ControllerPointerSpeed);
    /*
    ** Compatibility with CNCNet configuration for this feature
    */
    Options.MouseWheelScrolling = ini.Get_Bool("Options", "MouseWheelScrolling", Options.MouseWheelScrolling);
    Options.MouseWheelScrolling = ini.Get_Bool("Mouse", "MouseWheelScrolling", Options.MouseWheelScrolling);
    Touch.EdgeScroll = ini.Get_Bool("iPadOS", "TouchEdgeScroll", Touch.EdgeScroll);
    Touch.ScrollSpeed = Bound(ini.Get_Int("iPadOS", "TouchScrollSpeed", Touch.ScrollSpeed), 0, 2);
    Touch.SelectionTolerance =
        Bound(ini.Get_Int("iPadOS", "TouchSelectionTolerance", Touch.SelectionTolerance), 0, 2);

    /*
    ** Video settings
    */
    Video.WindowWidth = ini.Get_Int("Video", "WindowWidth", Video.WindowWidth);
    Video.WindowHeight = ini.Get_Int("Video", "WindowHeight", Video.WindowHeight);
#ifdef MACOS_PORT
    // Migrate the original port's fixed first-run size. That build ignored
    // the saved window dimensions and always opened at 640x400 points.
    if (Video.WindowWidth == 640 && Video.WindowHeight == 400) {
        Video.WindowWidth = 1200;
        Video.WindowHeight = 750;
    }
#endif
    Video.Windowed = ini.Get_Bool("Video", "Windowed", Video.Windowed);
    Video.Boxing = ini.Get_Bool("Video", "Boxing", Video.Boxing);
    Video.BoxingAspectRatio = ini.Get_String("Video", "BoxingAspectRatio", Video.BoxingAspectRatio);
    Video.Width = ini.Get_Int("Video", "Width", Video.Width);
    Video.Height = ini.Get_Int("Video", "Height", Video.Height);
    Video.FrameLimit = ini.Get_Int("Video", "FrameLimit", Video.FrameLimit);
    Video.BatterySaving = ini.Get_Bool("Video", "BatterySaving", Video.BatterySaving);
    // Read the former iPadOS section first so existing installations retain
    // their choices, then prefer the shared Apple section used by both apps.
    Video.PresentationMode = Bound(ini.Get_Int("iPadOS", "PresentationMode", Video.PresentationMode), 0, 3);
    Video.ArtworkMode = Bound(ini.Get_Int("iPadOS", "ArtworkMode", Video.ArtworkMode), 0, 1);
    Video.TouchUIScale = Bound(ini.Get_Int("iPadOS", "TouchUIScale", Video.TouchUIScale), 100, 150);
    Video.LargeCursor = ini.Get_Bool("iPadOS", "LargeCursor", Video.LargeCursor);
    Video.HighContrast = ini.Get_Bool("iPadOS", "HighContrast", Video.HighContrast);
    Video.PresentationMode = Bound(ini.Get_Int("Apple", "PresentationMode", Video.PresentationMode), 0, 3);
    Video.ArtworkMode = Bound(ini.Get_Int("Apple", "ArtworkMode", Video.ArtworkMode), 0, 1);
    Video.TouchUIScale = Bound(ini.Get_Int("Apple", "UIScale", Video.TouchUIScale), 100, 150);
    Video.LargeCursor = ini.Get_Bool("Apple", "LargeCursor", Video.LargeCursor);
    Video.HighContrast = ini.Get_Bool("Apple", "HighContrast", Video.HighContrast);
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
    if (ini.Get_Int("Apple", "WireproofLayoutVersion", 0) < 2) {
        Video.LargeCursor = true; Video.PresentationMode = 0;
    }
#endif
    Video.HardwareCursor = ini.Get_Bool("Video", "HardwareCursor", Video.HardwareCursor);
    Video.DOSMode = ini.Get_Bool("Video", "DOSMode", Video.DOSMode);
    Video.Scaler = ini.Get_String("Video", "Scaler", Video.Scaler);
    Video.Driver = ini.Get_String("Video", "Driver", Video.Driver);
    Video.PixelFormat = ini.Get_String("Video", "PixelFormat", Video.PixelFormat);

    /*
    ** VQA and WSA interpolation mode 0 = scanlines, 1 = vertical doubling, 2 = linear
    */
    Video.InterpolationMode = Bound(ini.Get_Int("Video", "InterpolationMode", Video.InterpolationMode), 0, 2);

    /*
    ** Native Vision Pro controls. These values are harmless on the other
    ** targets, but live in their own section because gaze-assisted scrolling
    ** and spatial pinch tolerances are visionOS capabilities.
    */
    Vision.LookToScroll = ini.Get_Bool("visionOS", "LookToScroll", Vision.LookToScroll);
    Vision.ScrollSpeed = Bound(ini.Get_Int("visionOS", "ScrollSpeed", Vision.ScrollSpeed), 0, 2);
    Vision.EdgeSensitivity =
        Bound(ini.Get_Int("visionOS", "EdgeSensitivity", Vision.EdgeSensitivity), 0, 2);
    Vision.SelectionTolerance =
        Bound(ini.Get_Int("visionOS", "SelectionTolerance", Vision.SelectionTolerance), 0, 2);

    /*
    ** Boxing and raw input require software cursor.
    */
    if (Video.Boxing || Mouse.RawInput || Mouse.ControllerEnabled) {
        Video.HardwareCursor = false;
    }

    ini.Get_String("Video", "ButtonStyle", "Default", buf, sizeof(buf));
    if (!stricmp(buf, "Gold")) {
        Video.ButtonStyle = 1;
    } else if (!stricmp(buf, "Classic") || !stricmp(buf, "DOS")) {
        Video.ButtonStyle = 0;
    } else {
        Video.ButtonStyle = -1;
    }
}

void SettingsClass::Save(INIClass& ini)
{
    /*
    ** Mouse settings
    */
    ini.Put_Bool("Mouse", "RawInput", Mouse.RawInput);
    ini.Put_Int("Mouse", "Sensitivity", Mouse.Sensitivity);
    ini.Put_Bool("Mouse", "ControllerEnabled", Mouse.ControllerEnabled);
    ini.Put_Int("Mouse", "ControllerPointerSpeed", Mouse.ControllerPointerSpeed);
    ini.Put_Bool("Mouse", "MouseWheelScrolling", Options.MouseWheelScrolling);
    ini.Put_Bool("iPadOS", "TouchEdgeScroll", Touch.EdgeScroll);
    ini.Put_Int("iPadOS", "TouchScrollSpeed", Touch.ScrollSpeed);
    ini.Put_Int("iPadOS", "TouchSelectionTolerance", Touch.SelectionTolerance);

    /*
    ** Video settings
    */
    ini.Put_Int("Video", "WindowWidth", Video.WindowWidth);
    ini.Put_Int("Video", "WindowHeight", Video.WindowHeight);
    ini.Put_Bool("Video", "Windowed", Video.Windowed);
    ini.Put_Bool("Video", "Boxing", Video.Boxing);
    ini.Put_String("Video", "BoxingAspectRatio", Video.BoxingAspectRatio);
    ini.Put_Int("Video", "Width", Video.Width);
    ini.Put_Int("Video", "Height", Video.Height);
    ini.Put_Int("Video", "FrameLimit", Video.FrameLimit);
    ini.Put_Bool("Video", "BatterySaving", Video.BatterySaving);
    ini.Put_Int("Apple", "WireproofLayoutVersion", 2);
    ini.Put_Int("Apple", "PresentationMode", Video.PresentationMode);
    ini.Put_Int("Apple", "ArtworkMode", Video.ArtworkMode);
    ini.Put_Int("Apple", "UIScale", Video.TouchUIScale);
    ini.Put_Bool("Apple", "LargeCursor", Video.LargeCursor);
    ini.Put_Bool("Apple", "HighContrast", Video.HighContrast);
    ini.Put_Bool("Video", "HardwareCursor", Video.HardwareCursor);
    ini.Put_Bool("Video", "DOSMode", Video.DOSMode);
    ini.Put_String("Video", "Scaler", Video.Scaler);
    ini.Put_String("Video", "Driver", Video.Driver);
    ini.Put_String("Video", "PixelFormat", Video.PixelFormat);

    /*
    ** VQA and WSA interpolation mode 0 = scanlines, 1 = vertical doubling, 2 = linear
    */
    ini.Put_Int("Video", "InterpolationMode", Video.InterpolationMode);

    ini.Put_Bool("visionOS", "LookToScroll", Vision.LookToScroll);
    ini.Put_Int("visionOS", "ScrollSpeed", Vision.ScrollSpeed);
    ini.Put_Int("visionOS", "EdgeSensitivity", Vision.EdgeSensitivity);
    ini.Put_Int("visionOS", "SelectionTolerance", Vision.SelectionTolerance);

    ini.Put_String(
        "Video", "ButtonStyle", Video.ButtonStyle == -1 ? "Default" : (Video.ButtonStyle == 1 ? "Gold" : "Classic"));
}
