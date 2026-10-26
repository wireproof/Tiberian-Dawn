#pragma once
#include <cstring>
namespace WPCheats {
inline bool MilitaryBuildType(const char* name) {
    if(!name)return false;
    static const char* names[]={"WEAP","GTWR","ATWR","OBLI","HQ","GUN","FACT","PROC","SILO","HPAD","SAM","AFLD","NUKE","NUK2","PYLE","FIX","HAND","TMPL","EYE","SBAG","CYCL","BRIK","BARB","WOOD","E1","E2","E3","E4","E5","E6","RMBO","HTNK","MTNK","LTNK","STNK","FTNK","APC","MLRS","JEEP","BGGY","HARV","ARTY","MSAM","MCV","BIKE","ORCA","HELI","TRAN"};
    for(const char* n:names)if(!strcmp(name,n))return true;
    return false;
}
}
