#include "wireproof_orders.h"
namespace WPOrders { State& Shared() { static State state; return state; } }
