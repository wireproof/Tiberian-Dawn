#pragma once
void RA_InstallLifecycleHandler(void);
void RA_SetRecoveryTactical(bool active);
bool RA_HasRecoveryAutosave(void);
bool RA_LoadRecoveryAutosave(void);
void RA_DiscardRecoveryAutosaves(void);
