#pragma once
class TechnoClass;
#if defined(IPADOS_PORT) || defined(MACOS_PORT)
bool RA_QueueAdd(int type,int id);
int RA_QueueCount(int type,int id);
void RA_QueueCancel(int type,int id,bool active);
void RA_QueueAcknowledge(int house,int type,int id);
void RA_QueueCancelled(int house,int type);
void RA_ResetProduction();
void RA_ProductionTick();
void RA_ClearRallies();
void RA_RallyNew(TechnoClass* unit);
void RA_RallyForget(TechnoClass* unit);
bool RA_RallyClick(int cell);
#else
inline void RA_QueueAcknowledge(int,int,int){}
inline void RA_QueueCancelled(int,int){}
inline void RA_RallyNew(TechnoClass*){}
inline void RA_RallyForget(TechnoClass*){}
inline bool RA_RallyClick(int){return false;}
#endif
