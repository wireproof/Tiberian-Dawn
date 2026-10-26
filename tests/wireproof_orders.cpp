#include "common/wireproof_menu_layout.h"
#include "common/wireproof_camera.h"
#include <climits>
#include "common/wireproof_orders.h"
#include <cassert>
#include "common/wireproof_cheats.h"
int main() {
    for(const auto size : {std::pair<int,int>{640,400},{640,910},{1100,400}}) {
        auto menu=WPMenu::Calculate(size.first,size.second,6);
        assert(menu.x>=0 && menu.x+menu.width<=size.first);
        assert(menu.y+menu.height<=size.second-menu.footerHeight);
        assert(menu.y+20+5*menu.step+menu.buttonHeight<menu.y+menu.height);
    }
    // Duo cover hosting can keep the inner window dimensions and reserve an
    // edge strip. Both orientations must choose cover; normal inner insets do not.
    assert(WPCamera::CoverDisplay(900,1280,0,0,180,64));
    assert(WPCamera::CoverDisplay(1280,900,160,0,0,84));
    assert(!WPCamera::CoverDisplay(900,1280,0,0,0,46));
    assert(!WPCamera::CoverDisplay(1280,900,0,0,0,46));
    assert(WPCamera::CoverDisplay(720,1216,0,0,0,0));
    assert(WPCamera::CoverDisplay(1216,720,0,0,0,0));
    WPOrders::State settings;
    assert(settings.joystickSetting(false)==4 && settings.joystickSetting(true)==4);
    settings.setJoystickSetting(false,99);assert(settings.joystickSetting(false)==8);
    settings.setJoystickSetting(true,-1);assert(settings.joystickSetting(true)==1);
    assert(WPMenu::Calculate(640,1400,6).step<=52);
    assert(WPCamera::SidebarSlots(400,182,48,24,24)==4);
    assert(WPCamera::SidebarSlots(910,182,48,24,24)==14);
    assert(WPCamera::SidebarSlots(200,182,48,24,24)==1);
    assert(WPCamera::SidebarSlots(4096,182,48,24,24)==24);
    assert(WPCamera::PortraitSidebarSlots(640,910)==5);
    assert(WPCamera::PortraitSidebarSlots(400,910)==5);
    assert(WPCamera::PortraitSidebarSlots(910,640)==0);
    using WPCamera::ClampAxis;
    // Large drags across every edge, nonzero map origins, and oversized views.
    assert(ClampAxis(256,-4096,256,8192,2048)==256);
    assert(ClampAxis(6300,4096,256,8192,2048)==6400);
    assert(ClampAxis(1000,128,256,8192,2048)==1128);
    assert(ClampAxis(1000,-128,256,8192,2048)==872);
    assert(ClampAxis(256,INT_MIN,256,8192,2048)==256);
    assert(ClampAxis(256,INT_MAX,256,8192,2048)==6400);
    assert(ClampAxis(512,200,256,1024,2048)==256);
    int edge=256;
    for(int i=0;i<1000;++i)edge=ClampAxis(edge,-1000,256,8192,2048);
    assert(edge==256);
    assert(ClampAxis(edge,100,256,8192,2048)==356); // immediate reverse away from edge

    WPCheats::State cheats;
    cheats.addMoney(1000);cheats.invincible(true);cheats.speed(0,12);
    assert(!cheats.snapshot().invincible && cheats.snapshot().infantry==4 && cheats.take().money==0);
    cheats.publish(true,2000,100,50);cheats.addMoney(1000);cheats.addMoney(10000);cheats.addPower(100);
    auto actions=cheats.take();assert(actions.money==11000 && actions.power==100 && cheats.take().money==0);
    cheats.invincible(true);cheats.reveal(true);cheats.speed(0,-1);cheats.speed(1,99);cheats.speed(2,7);
    auto snapshot=cheats.snapshot();assert(snapshot.invincible && snapshot.reveal && snapshot.infantry==1 && snapshot.vehicles==12 && snapshot.aircraft==7);
    cheats.addMoney(1000);cheats.publish(false,0,0,0);assert(cheats.take().money==0);
    cheats.publish(true,0,0,0);cheats.instant(true);cheats.free(true);assert(cheats.snapshot().instant && cheats.snapshot().free);
    cheats.weapons(true);cheats.anywhere(true);assert(cheats.snapshot().weapons && cheats.snapshot().anywhere);
    cheats.addMoney(1000);cheats.addPower(100);
    cheats.reset();snapshot=cheats.snapshot();
    assert(!snapshot.available && snapshot.money==0 && snapshot.power==0 && cheats.take().money==0 && cheats.take().power==0);
    assert(snapshot.weapons && snapshot.anywhere && snapshot.instant && snapshot.free && snapshot.invincible && snapshot.reveal);
    assert(snapshot.infantry==1 && snapshot.vehicles==12 && snapshot.aircraft==7);
    cheats.weapons(false);assert(cheats.snapshot().weapons); // inactive settings cannot change
    cheats.publish(true,20,30,40);assert(cheats.snapshot().weapons);
    static WPCheats::Snapshot disk;
    WPCheats::State persisted({},[](const WPCheats::Snapshot& value){disk=value;});
    persisted.publish(true,999,100,50);persisted.weapons(true);persisted.reveal(true);persisted.speed(2,9);persisted.addMoney(1000);
    WPCheats::State relaunched(disk);auto loaded=relaunched.snapshot();
    assert(loaded.weapons && loaded.reveal && loaded.aircraft==9 && !loaded.available && loaded.money==0 && loaded.power==0 && relaunched.take().money==0);
    persisted.weapons(false);WPCheats::State disabled(disk);assert(!disabled.snapshot().weapons);
    using namespace WPOrders;
    State s; Command c;
    assert(s.uiScale()==100);s.setUIScale(10);assert(s.uiScale()==75);s.setUIScale(200);assert(s.uiScale()==150);
    for(int scale=75;scale<=150;scale+=5){s.setUIScale(scale);assert(s.uiScale()==scale);}
    s.setUIScale(125);s.publish(false,0);assert(s.uiScale()==125);s.setUIScale(100);
    s.setStick(1,0);assert(s.stick().intensity==0); // no commands outside gameplay
    s.publish(true,0);s.setStick(.1f,0);assert(s.stick().intensity==0); // center dead zone
    s.setStick(.5f,0);float slow=s.stick().intensity;assert(slow>0 && slow<1);
    s.setStick(1,0);assert(s.stick().intensity>slow && s.stick().x==1);
    s.setStick(1,1);auto diagonal=s.stick();assert(diagonal.intensity==1 && std::fabs(diagonal.x-diagonal.y)<.001f);
    s.setStick(NAN,1);assert(s.stick().intensity==0);
    s.setStick(1,0);s.publish(false,0);assert(s.stick().intensity==0); // pause/focus loss stops movement
    s.setMapDrag(true);assert(!s.mapDrag());
    s.publish(true,0);s.setMapDrag(true);assert(s.mapDrag() && !s.panHeld());
    s.setMapDrag(false);assert(!s.mapDrag());
    s.setMapDrag(true);s.publish(false,0);assert(!s.mapDrag());
    assert(s.zoomQuarters()==6);
    s.setZoomQuarters(-10); assert(s.zoomQuarters()==2);
    for (int q=2;q<=12;++q) { assert(s.zoomQuarters()==q); s.stepZoom(1); }
    assert(s.zoomQuarters()==12); s.stepZoom(1); assert(s.zoomQuarters()==12);
    for (int q=12;q>=2;--q) { assert(s.zoomQuarters()==q); s.stepZoom(-1); }
    assert(s.zoomQuarters()==2);
    s.setZoomQuarters(7); s.publish(false,0); assert(s.zoomQuarters()==7); // retains preference between missions
    s.setZoomQuarters(6);
    s.hold_pan(true); assert(!s.panHeld()); // cannot latch a modifier in menus
    s.publish(true,0); s.hold_pan(true); assert(s.panHeld()); // no selected units required
    s.hold_pan(false); assert(!s.panHeld());
    s.hold_pan(true); s.publish(false,0); assert(!s.panHeld()); // leaving gameplay cancels hold
    assert(!s.enqueue(Stop)); // menus cannot queue delayed battlefield commands
    s.publish(true,0);
    assert(s.enqueue(Assign,2)); assert(s.take(c) && c.kind==Assign && c.group==2); // long hold clears an empty selection
    assert(!s.enqueue(Attack));
    assert(s.enqueue(Recall,9)); assert(s.take(c) && c.kind==Recall && c.group==9);
    assert(!s.enqueue(Recall,10));
    s.publish(true,3); s.force(1); assert(s.snapshot().force==1);
    s.force(0); assert(s.snapshot().force==0);
    assert(s.enqueue(Assign,4)); assert(s.enqueue(Guard));
    assert(s.take(c) && c.kind==Assign && c.group==4);
    assert(s.take(c) && c.kind==Guard); assert(!s.take(c));
    s.force(2); s.publish(true,0); assert(s.snapshot().force==0);
    s.publish(true,2); s.force(1); s.enqueue(Stop);
    s.publish(false,0); assert(!s.take(c) && s.snapshot().force==0);
    s.publish(true,2); for (int i=0;i<32;i++) assert(s.enqueue(Stop));
    assert(!s.enqueue(Stop));
}
