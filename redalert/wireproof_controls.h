#pragma once
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
void RA_ProcessControls();
void RA_ResetControls();
void RA_BeginPresentation();
void RA_RequestOptions();
bool RA_BuildAnywhere(const void* house);
bool RA_UnlockBuildType(const void* house,const char* name);
int RA_ScaleSpeed(const void* house,int base,int category);
bool RA_PlayerInvincible(const void* house);
bool RA_FreeProduction(const void* house);
bool RA_InstantProduction(const void* house);
#else
inline void RA_ProcessControls() {}
inline void RA_ResetControls() {}
inline void RA_BeginPresentation() {}
inline void RA_RequestOptions() {}
inline bool RA_BuildAnywhere(const void*) { return false; }
inline bool RA_UnlockBuildType(const void*,const char*) { return false; }
inline int RA_ScaleSpeed(const void*,int base,int) { return base; }
inline bool RA_PlayerInvincible(const void*) { return false; }
inline bool RA_FreeProduction(const void*) { return false; }
inline bool RA_InstantProduction(const void*) { return false; }
#endif
