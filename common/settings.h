#ifndef SETTINGS_H
#define SETTINGS_H

#include <string>
class INIClass;

class SettingsClass
{
public:
    SettingsClass();

    void Load(INIClass& ini);
    void Save(INIClass& ini);

    struct
    {
        bool RawInput;
        int Sensitivity;
        bool ControllerEnabled;
        int ControllerPointerSpeed;
    } Mouse;

    struct
    {
        int WindowWidth;
        int WindowHeight;
        bool Windowed;
        bool Boxing;
        std::string BoxingAspectRatio;
        int Width;
        int Height;
        int FrameLimit;
        bool BatterySaving;
        int PresentationMode;
        int ArtworkMode;
        int TouchUIScale;
        bool LargeCursor;
        bool HighContrast;
        int InterpolationMode;
        bool HardwareCursor;
        bool DOSMode;
        int ButtonStyle;
        std::string Scaler;
        std::string Driver;
        std::string PixelFormat;
    } Video;

    struct
    {
        bool MouseWheelScrolling;
    } Options;

    struct
    {
        bool EdgeScroll;
        int ScrollSpeed;
        int SelectionTolerance;
        bool LaptopMode;
        bool PortraitDeckAlways;
    } Touch;

    struct
    {
        bool LookToScroll;
        int ScrollSpeed;
        int EdgeSensitivity;
        int SelectionTolerance;
    } Vision;
};

extern SettingsClass Settings;

#endif
