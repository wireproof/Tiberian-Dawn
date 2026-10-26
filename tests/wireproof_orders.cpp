#include "common/wireproof_orders.h"
#include <cassert>
int main() {
    using namespace WPOrders;
    State s; Command c;
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
