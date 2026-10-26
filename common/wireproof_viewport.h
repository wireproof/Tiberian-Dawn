#ifndef WIREPROOF_VIEWPORT_H
#define WIREPROOF_VIEWPORT_H
// Engine-thread only. Never alter simulation state when changing the view.
void WP_Update_Battlefield_Viewport(bool active, bool menu = false, bool classic = false);
void WP_Begin_Campaign_Presentation();
#endif
