// Host-only lifecycle regression. Run scripts/test-game-session-visibility.py.
// SDL/UIKit are modeled here; the tested helper is extracted from the real backend.

#include <cassert>
#include <vector>
static int handle;
static int* window=&handle;
static bool render_active=true, focus=true, audio=true, shown=true, force_present=false;
static bool dawn=true;
static std::vector<int> events;
void Set_Video_Render_Active(bool active){render_active=active;}
void Focus_Loss(){focus=false;audio=false;if(dawn)render_active=false;}
void Focus_Restore(){focus=true;audio=true;if(dawn)render_active=true;}
struct KeyboardStub { void Clear(){for(int e:events){if(e==0)Focus_Loss();else Focus_Restore();}events.clear();}} keyboard;
static KeyboardStub* Keyboard=&keyboard;
void SDL_ShowWindow(int*){shown=true;} // UIKit retains SDL input focus: no FOCUS_GAINED.
void SDL_RaiseWindow(int*){}
void SDL_HideWindow(int*){shown=false;events.push_back(0);}
void Refresh_Video_Layout(){}
#include "game_session_visibility_under_test.h"

int main(){
 for(bool engine:{true,false}){
  dawn=engine;
  for(int cycle=0;cycle<10;++cycle){
   events.push_back(1); // delayed restore must not restart audio after hiding.
   Video_Set_Game_Window_Visible(false);
   assert(!shown && !focus && !audio && !render_active && events.empty());
   events.push_back(0); // stale HIDDEN event before resumed session.
   Video_Set_Game_Window_Visible(true);
   assert(shown && focus && audio && render_active && force_present && events.empty());
  }
 }
 window=nullptr; Video_Set_Game_Window_Visible(true); Video_Set_Game_Window_Visible(false);
}
