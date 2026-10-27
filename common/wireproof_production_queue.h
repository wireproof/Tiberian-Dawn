#pragma once
#include <algorithm>
#include <deque>
namespace WPProduction {
class Queue {
    std::deque<int> items;
    bool sent=false;
public:
    bool add(int id){if(id<0||items.size()>=99)return false;items.push_back(id);return true;}
    bool remove(int id){for(size_t n=items.size();n>0;--n)if(items[n-1]==id&&!(sent&&n==1)){items.erase(items.begin()+n-1);return true;}return false;}
    int count(int id)const{return int(std::count(items.begin(),items.end(),id));}
    int next(bool busy){if(busy||sent||items.empty())return -1;sent=true;return items.front();}
    void retry(){sent=false;}
    void acknowledge(int id){if(sent&&!items.empty()&&items.front()==id){items.pop_front();sent=false;}}
    void clear(){items.clear();sent=false;}
};
}
