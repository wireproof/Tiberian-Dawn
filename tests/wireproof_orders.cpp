#include "common/wireproof_orders.h"
#include <cassert>
#include "common/wireproof_cheats.h"
int main() {
    WPCheats::State cheats;
    cheats.addMoney(1000);cheats.invincible(true);cheats.speed(0,12);
    assert(!cheats.snapshot().invincible && cheats.snapshot().infantry==4 && cheats.take().money==0);
    cheats.publish(true,2000,100,50);cheats.addMoney(1000);cheats.addMoney(10000);cheats.addPower(100);
    auto actions=cheats.take();assert(actions.money==11000 && actions.power==100 && cheats.take().money==0);
    cheats.invincible(true);cheats.reveal(true);cheats.speed(0,-1);cheats.speed(1,99);cheats.speed(2,7);
    auto snapshot=cheats.snapshot();assert(snapshot.invincible && snapshot.reveal && snapshot.infantry==1 && snapshot.vehicles==12 && snapshot.aircraft==7);
    cheats.addMoney(1000);cheats.publish(false,0,0,0);assert(cheats.take().money==0);
    cheats.publish(true,0,0,0);cheats.instant(true);cheats.free(true);assert(cheats.snapshot().instant && cheats.snapshot().free);
    cheats.reset();assert(!cheats.snapshot().instant && !cheats.snapshot().free);snapshot=cheats.snapshot();assert(!snapshot.available && !snapshot.invincible && !snapshot.reveal && snapshot.infantry==4 && snapshot.vehicles==4 && snapshot.aircraft==4);
    using namespace WPOrders;
    State s; Command c;
    s.setStick(1,0);assert(s.stick().intensity==0); // no commands outside gameplay
    s.publish(true,0);s.setStick(.1f,0);assert(s.stick().intensity==0); // center dead zone
    s.setStick(.5f,0);float slow=s.stick().intensity;assert(slow>0 && slow<1);
    s.setStick(1,0);assert(s.stick().intensity>slow && s.stick().x==1);
    s.setStick(1,1);auto diagonal=s.stick();assert(diagonal.intensity==1 && std::fabs(diagonal.x-diagonal.y)<.001f);
    s.setStick(NAN,1);assert(s.stick().intensity==0);
    s.setStick(1,0);s.publish(false,0);assert(s.stick().intensity==0); // pause/focus loss stops movement
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
    assert(!s.enqueue(Assign,2)); // cannot erase a group accidentally with no selection
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
