#pragma once
#include "wwkeyboard.h"
#ifdef VISIONOS_PORT
#include "visionos_input.h"
#endif

class WWKeyboardClassSDL2 : public WWKeyboardClass
{
public:
    WWKeyboardClassSDL2();
    virtual ~WWKeyboardClassSDL2();

    void Clear(void) override;
    void Fill_Buffer_From_System(void) override;
    bool Is_Gamepad_Active() override;
    void Open_Controller() override;
    void Close_Controller() override;
    bool Is_Analog_Scroll_Active() override;
    unsigned char Get_Scroll_Direction() override;
    float Get_Scroll_Intensity() override;
    KeyASCIIType To_ASCII(unsigned short key) override;
#ifdef IPADOS_PORT
    bool Put_Touch_Mouse_Message(unsigned short key, int x, int y, bool release = false)
    {
        return Put_Mouse_Message(static_cast<unsigned short>(key | WWKEY_DBL_BIT), x, y, release);
    }
    bool Put_Pencil_Mouse_Message(unsigned short key, int x, int y, bool release = false)
    {
        return Put_Mouse_Message(static_cast<unsigned short>(key | WWKEY_DBL_BIT | WWKEY_VK_BIT), x, y, release);
    }
#endif
    bool Put_Text_Character(unsigned char character)
    {
        return Put(static_cast<unsigned short>(WWKEY_TEXT_BIT | character));
    }

private:
    void Handle_Controller_Axis_Event(const SDL_ControllerAxisEvent& motion);
    void Handle_Controller_Button_Event(const SDL_ControllerButtonEvent& button);
    void Process_Controller_Axis_Motion();

    // used to convert user-friendly pointer speed values into more useable ones
    static constexpr float CONTROLLER_SPEED_MOD = 2000000.0f;
    // bigger value correndsponds to faster pointer movement speed with bigger stick axis values
    static constexpr float CONTROLLER_AXIS_SPEEDUP = 1.03f;
    // speedup value while the trigger is pressed
    static constexpr int CONTROLLER_TRIGGER_SPEEDUP = 2;

    enum
    {
        CONTROLLER_L_DEADZONE = 4000,
        CONTROLLER_R_DEADZONE = 6000,
        CONTROLLER_TRIGGER_R_DEADZONE = 3000
    };

    SDL_GameController* GameController = nullptr;
    int16_t ControllerLeftXAxis = 0;
    int16_t ControllerLeftYAxis = 0;
    int16_t ControllerRightXAxis = 0;
    int16_t ControllerRightYAxis = 0;
    uint32_t LastControllerTime = 0;
    float ControllerSpeedBoost = 1;
    bool AnalogScrollActive = false;
    ScrollDirType ScrollDirection = SDIR_NONE;
#ifdef VISIONOS_PORT
    VisionOSInputState VisionInputState;
#endif
#ifdef IPADOS_PORT
    bool LifecycleWatchInstalled = false;
#endif
};
