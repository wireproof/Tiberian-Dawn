#include "common/wireproof_orders.h"
#include <cassert>
int main() {
    using namespace WPOrders;
    State s; Command c;
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
