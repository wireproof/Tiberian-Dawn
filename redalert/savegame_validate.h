#ifndef REDALERT_SAVEGAME_VALIDATE_H
#define REDALERT_SAVEGAME_VALIDATE_H
#include "common/sha.h"
#include <cstdio>
#include <cstring>
#include <algorithm>
// Validate the on-disk encrypted bytes without deserializing game state. The
// digest detects corruption, not maliciously re-signed or trusted game content.
template<typename SaveHouse = int>
inline bool RA_ValidateSaveFile(const char* path, char* title, size_t capacity,
                               unsigned* scenario, int* faction, size_t descriptionSize,
                               unsigned expectedVersion, bool allowAftermath, int houseCount)
{
    if(!path || !title || capacity==0 || descriptionSize==0 || descriptionSize>4096)return false;
    title[0]=0;
    FILE* file=std::fopen(path,"rb");if(!file)return false;
    struct Close {FILE* file;~Close(){std::fclose(file);}} close{file};
    char description[4096];unsigned scen=0,version=0;SaveHouse house{};unsigned char digest[20];
    if(std::fread(description,1,descriptionSize,file)!=descriptionSize ||
       !std::memchr(description,0,descriptionSize) ||
       std::fread(&scen,1,sizeof(scen),file)!=sizeof(scen) ||
       std::fread(&house,1,sizeof(house),file)!=sizeof(house) ||
       std::fread(&version,1,sizeof(version),file)!=sizeof(version) ||
       std::fread(digest,1,sizeof(digest),file)!=sizeof(digest))return false;
    if((version!=expectedVersion && !(allowAftermath && version==expectedVersion+1)) || house<0 || house>=houseCount)return false;
    SHAEngine sha;unsigned char buffer[16384];size_t total=0,count;
    while((count=std::fread(buffer,1,sizeof(buffer),file))!=0){
        total+=count;if(total>128u*1024u*1024u)return false;
        sha.Hash(buffer,static_cast<int32_t>(count));
    }
    if(std::ferror(file) || total==0)return false;
    unsigned char actual[20];sha.Result(actual);
    if(std::memcmp(actual,digest,sizeof(digest)))return false;
    size_t length=std::strlen(description);
    while(length && (description[length-1]=='\r' || description[length-1]=='\n'))--length;
    length=std::min(length,capacity-1);std::memcpy(title,description,length);title[length]=0;
    if(scenario)*scenario=scen;if(faction)*faction=static_cast<int>(house);
    return true;
}
#endif
