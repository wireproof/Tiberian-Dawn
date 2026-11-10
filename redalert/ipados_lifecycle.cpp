#include "ipados_lifecycle.h"
#include "function.h"
#include "externs.h"
#include "common/app_lifecycle.h"
#include "common/debugstring.h"
#include "common/paths.h"
#include "common/recovery_transaction.h"
#include "common/settings.h"
#include "common/video.h"
#include "recovery_policy.h"
#include <fcntl.h>
#include <unistd.h>

extern "C" bool RedAlert_ValidateSaveGame(const char*,char*,size_t,unsigned*,int*);
extern "C" void RedAlert_EndBackgroundTask(void);

namespace {
// Isolated from manual SAVEGAME slots and TD recovery files, even if users
// later move the game directories. These files never enter cloud/backup exports.
const char* const RecoveryNames[]={"autosave.ra0","autosave.ra1"};
const char* const TemporaryName="autosave.ra.tmp";
bool Tactical=false;
bool Saving=false;
bool HasSavedFrame=false;
unsigned SavedFrame=0;

std::string UserPath(const char* name) {return Paths.Concatenate_Paths(Paths.User_Path(),name);}
void SyncPath(const std::string& path) {
    const int fd=open(path.c_str(),O_RDONLY);if(fd>=0){fsync(fd);close(fd);}
}
bool Validate(const std::string& path) {
    char title[DESCRIP_MAX];unsigned scenario;int faction;
    return RedAlert_ValidateSaveGame(path.c_str(),title,sizeof(title),&scenario,&faction);
}
std::string Latest() {return RA_LatestValidRecovery(UserPath(RecoveryNames[0]),UserPath(RecoveryNames[1]),Validate);}

bool Eligible() {
    return RA_RecoveryEligible(Tactical,GameActive,PlayerPtr!=nullptr,InMovie,Session.Play,
                              Session.Type==GAME_NORMAL || Session.Type==GAME_SKIRMISH,
                              Video_Game_Window_Is_Visible(),Debug_Map,SpecialDialog!=SDLG_NONE);
}
void SaveRecovery() {
    if(Saving || !Eligible() || (HasSavedFrame && SavedFrame==Frame))return;
    Saving=true;
    const RecoveryCommitResult result=Commit_Recovery_File(
        UserPath(TemporaryName),UserPath(RecoveryNames[0]),UserPath(RecoveryNames[1]),Paths.User_Path(),
        [](const std::string& path) {
            // Save_Game historically does not propagate every pipe I/O failure.
            // Require a complete matching header + digest before replacing a slot.
            return Save_Game(path.c_str(),"Red Alert recovery autosave") && Validate(path);
        });
    if(result.committed){HasSavedFrame=true;SavedFrame=Frame;}
    if(!result.committed || !result.durable)DBG_ERROR("Red Alert recovery commit error %d",static_cast<int>(result.error));
    Saving=false;
}
void FlushSettings() {
    Options.Save_Settings();
    CCFileClass file(CONFIG_FILE_NAME);INIClass ini;ini.Load(file);Settings.Save(ini);ini.Save(file);
    SyncPath(UserPath("redalert.ini"));
}
void Handle(AppLifecycleEvent event) {
    switch(event) {
    case APP_LIFECYCLE_ENTERED_BACKGROUND:
    case APP_LIFECYCLE_TERMINATING:
        if(Saving)return; // Save_Game callbacks may pump duplicate lifecycle events.
        // SDL_WINDOW_SHOWN is ownership, not scene activation: the selected
        // engine stays shown during background, retained inactive engines don't.
        if(Video_Game_Window_Is_Visible()) {
            FlushSettings();SaveRecovery();
        }
        RedAlert_EndBackgroundTask();
        break;
    case APP_LIFECYCLE_LOW_MEMORY:
        if(Video_Game_Window_Is_Visible() && !InMovie)Free_Interpolated_Palettes();
        break;
    default:break;
    }
}
}
void RA_InstallLifecycleHandler() {Set_App_Lifecycle_Handler(Handle);}
void RA_SetRecoveryTactical(bool active) {
    Tactical=active;
    if(active)HasSavedFrame=false;
}
bool RA_HasRecoveryAutosave() {
    unlink(UserPath(TemporaryName).c_str());return !Latest().empty();
}
bool RA_LoadRecoveryAutosave() {
    const std::string path=Latest();if(path.empty() || !Load_Game(path.c_str()))return false;
    if(PlayerPtr)CurrentObject.Set_Active_Context(PlayerPtr->Class->House);
    return true;
}
void RA_DiscardRecoveryAutosaves() {
    for(const char* name:RecoveryNames)unlink(UserPath(name).c_str());
    unlink(UserPath(TemporaryName).c_str());SyncPath(Paths.User_Path());HasSavedFrame=false;
}
