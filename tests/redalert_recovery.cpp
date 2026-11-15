#include "common/fixed.h"
#include "redalert/defines.h"
#include "redalert/savegame_validate.h"
#include "redalert/recovery_policy.h"
#include "common/recovery_transaction.h"
#include <cassert>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <sys/time.h>
#include <unistd.h>

static void Write(const std::string& path,const std::string& bytes) {
    std::ofstream out(path,std::ios::binary|std::ios::trunc);out.write(bytes.data(),bytes.size());assert(out.good());
}
static std::string Read(const std::string& path) {
    std::ifstream in(path,std::ios::binary);return {std::istreambuf_iterator<char>(in),std::istreambuf_iterator<char>()};
}
static std::string SaveBytes() {
    char description[DESCRIP_MAX]={0};strcpy(description,"RA recovery test\r\n");
    unsigned scenario=1,version=1234;HousesType house=HOUSE_GREECE;
    const std::string payload="Opaque encrypted-payload fixture";char digest[20];SHAEngine sha;sha.Hash(payload.data(),payload.size());sha.Result(digest);
    std::string bytes(description,sizeof(description));
    bytes.append(reinterpret_cast<char*>(&scenario),sizeof(scenario));bytes.append(reinterpret_cast<char*>(&house),sizeof(house));
    bytes.append(reinterpret_cast<char*>(&version),sizeof(version));bytes.append(digest,sizeof(digest));bytes+=payload;return bytes;
}
static bool Validate(const std::string& path) {
    char title[DESCRIP_MAX];return RA_ValidateSaveFile<HousesType>(path.c_str(),title,sizeof(title),nullptr,nullptr,DESCRIP_MAX,1234,true,HOUSE_COUNT);
}
static void SetTime(const std::string& path,long seconds) {
    timeval times[2]={{seconds,0},{seconds,0}};assert(utimes(path.c_str(),times)==0);
}
int main() {
    // Only owned active single-player tactical gameplay may write recovery.
    bool state[]={true,true,true,false,false,true,true,false,false};
    auto eligible=[&]{return RA_RecoveryEligible(state[0],state[1],state[2],state[3],state[4],state[5],state[6],state[7],state[8]);};
    assert(eligible());
    for(int i=0;i<9;++i){state[i]=!state[i];assert(!eligible());state[i]=!state[i];}
    char pattern[]="/tmp/redalert-recovery-XXXXXX";char* dir=mkdtemp(pattern);assert(dir);
    const std::string root=dir,first=root+"/autosave.ra0",second=root+"/autosave.ra1",temp=root+"/autosave.ra.tmp",manual=root+"/savegame.000";
    const std::string valid=SaveBytes();Write(manual,"Existing manual save, never touched");
    assert(RA_LatestValidRecovery(first,second,Validate).empty());
    auto writer=[&](const std::string& path){Write(path,valid);return Validate(path);};
    auto result=Commit_Recovery_File(temp,first,second,root,writer);assert(result.committed && result.target_path==first);
    SetTime(first,100);
    result=Commit_Recovery_File(temp,first,second,root,writer);assert(result.committed && result.target_path==second);
    SetTime(second,200);assert(RA_LatestValidRecovery(first,second,Validate)==second);
    std::string damaged=valid;damaged.back()^=1;Write(second,damaged);SetTime(second,200);
    assert(RA_LatestValidRecovery(first,second,Validate)==first); // newest corrupt -> older valid
    result=Commit_Recovery_File(temp,first,second,root,[&](const std::string& path){Write(path,damaged);return Validate(path);});
    assert(!result.committed && result.error==RECOVERY_COMMIT_WRITER_FAILED);
    assert(Read(first)==valid && Read(second)==damaged && access(temp.c_str(),F_OK)!=0);
    result=Commit_Recovery_File(temp,first,second,root,writer);assert(result.committed && result.target_path==first);
    assert(RA_LatestValidRecovery(first,second,Validate)==first);
    assert(Read(manual)=="Existing manual save, never touched");
    unlink(first.c_str());unlink(second.c_str());assert(symlink(manual.c_str(),second.c_str())==0);
    assert(RA_LatestValidRecovery(first,second,Validate).empty()); // don't load a linked external file
    unlink(second.c_str());unlink(manual.c_str());assert(rmdir(root.c_str())==0);
    puts("Red Alert recovery: gameplay eligibility, two-slot transaction, newest-valid digest fallback, failed-write preservation, and manual-save isolation passed.");
}
