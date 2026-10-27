#pragma once
class TechnoClass;
#if defined(IPADOS_PORT) || defined(MACOS_PORT) || defined(VISIONOS_PORT)
bool WP_Queue_Add(int type,int id);
bool WP_Queue_Remove(int type,int id);
int WP_Queue_Count(int type,int id);
void WP_Queue_Acknowledge(int house,int type,int id);
void WP_Production_Tick();
void WP_Production_Reset();
void WP_Rally_Clear();
void WP_Rally_New(TechnoClass* unit);
void WP_Rally_Forget(TechnoClass* unit);
bool WP_Rally_Click(int cell,bool ground);
#else
inline bool WP_Queue_Add(int,int){return false;}
inline bool WP_Queue_Remove(int,int){return false;}
inline int WP_Queue_Count(int,int){return 0;}
inline void WP_Queue_Acknowledge(int,int,int){}
inline void WP_Production_Tick(){}
inline void WP_Production_Reset(){}
inline void WP_Rally_Clear(){}
inline void WP_Rally_New(TechnoClass*){}
inline void WP_Rally_Forget(TechnoClass*){}
inline bool WP_Rally_Click(int,bool){return false;}
#endif
