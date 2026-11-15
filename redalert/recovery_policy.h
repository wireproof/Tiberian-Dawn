#pragma once
#include <algorithm>
#include <string>
#include <vector>
#include <sys/stat.h>

// Pure policy kept separate from live game state for host-only safety tests.
inline bool RA_RecoveryEligible(bool tactical, bool gameActive, bool player,
                                bool movie, bool replay, bool singlePlayer,
                                bool owner, bool editor, bool dialog)
{
    return tactical && gameActive && player && !movie && !replay && singlePlayer
           && owner && !editor && !dialog;
}

template<typename Validate>
std::string RA_LatestValidRecovery(const std::string& first, const std::string& second, Validate validate)
{
    struct Candidate {std::string path; struct stat status;};
    std::vector<Candidate> candidates;
    for(const std::string& path : {first,second}) {
        struct stat status;
        if(lstat(path.c_str(),&status)==0 && S_ISREG(status.st_mode))candidates.push_back({path,status});
    }
    auto newer=[](const Candidate& a,const Candidate& b){
#if defined(__APPLE__)
        const auto& left=a.status.st_mtimespec;const auto& right=b.status.st_mtimespec;
#else
        const auto& left=a.status.st_mtim;const auto& right=b.status.st_mtim;
#endif
        return left.tv_sec>right.tv_sec || (left.tv_sec==right.tv_sec && left.tv_nsec>right.tv_nsec);
    };
    if(candidates.size()==2 && newer(candidates[1],candidates[0]))std::swap(candidates[0],candidates[1]);
    for(const auto& candidate:candidates)if(validate(candidate.path))return candidate.path;
    return {};
}
