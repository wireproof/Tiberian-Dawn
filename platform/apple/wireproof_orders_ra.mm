// Build the same native command surfaces for Red Alert in its separate engine.
// Objective-C class names and exported entry points must be unique because the
// Tiberian Dawn app and RedAlertEngine are loaded in one process.
#define WP_RA_UI 1
#define WPControlPositionStore WPRASharedControlPositionStore
#define WPMapJoystick WPRASharedMapJoystick
#define WPOrdersPanel WPRASharedOrdersPanel
#define WPGameToolbar WPRASharedGameToolbar
#define WPRadarMap WPRASharedRadarMap
#define WPLaptopDock WPRASharedLaptopDock
#define WP_InstallOrdersPanel RA_InstallOrdersPanel
#define WP_Publish_Order_Icon RA_Publish_Order_Icon
#include "wireproof_orders.mm"
