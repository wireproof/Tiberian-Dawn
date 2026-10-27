// Private imported artwork draw records; no game artwork is stored in this source file.
#ifndef REMASTERED_SCENE_H
#define REMASTERED_SCENE_H
#include <cstdint>
#include <string>
#include <vector>
namespace WPRemastered {
struct Command {
    enum Kind { Sprite, Tile, Fill };
    Kind kind = Sprite;
    std::string asset;
    int frame = 0, x = 0, y = 0, width = 0, height = 0;
    int theater = 0, owner = -1;
    unsigned flags = 0;
    int clip_x = 0, clip_y = 0, clip_w = 0, clip_h = 0;
    bool shroud = false, centered = false, sidebar = false;
    // width/height are the original classic canvas. x/y are its top left.
    // Indexed fallback pixels already have the fading remap applied. Alpha
    // preserves coverage when an opaque source remaps to palette index zero.
    std::vector<uint8_t> pixels, alpha, ghost;
};
struct SidebarIcon {
    std::string asset;
    int x = 0, y = 0, width = 0, height = 0;
    int clip_x = 0, clip_y = 0, clip_w = 0, clip_h = 0;
    // Difference between these snapshots retains classic clock and READY/HOLD overlays.
    std::vector<uint8_t> base, final;
};
struct Health {
    int x = 0, y = 0, width = 0, fill = 0;
    uint8_t color = 0;
};
struct Scene {
    bool capturing = false, valid = false, shroud = false;
    int theater = 0, clip_x = 0, clip_y = 0, clip_w = 0, clip_h = 0;
    int owner = -1;
    std::vector<Command> commands;
    std::vector<SidebarIcon> sidebar;
    std::vector<Health> health;
};
Scene& Shared();
void Begin(int theater, int x, int y, int width, int height);
void End();
void Clear();
void ClearSidebar();
void RecordHealth(int x, int y, int width, int fill, uint8_t color);
void RecordSidebarIcon(const char* asset, int x, int y, int width, int height,
                       int clip_x, int clip_y, int clip_w, int clip_h,
                       const uint8_t* base, const uint8_t* final);
void RegisterAsset(const void* pointer, const char* filename);
std::string AssetName(const void* pointer);
void RecordTile(const char* name, int frame, int x, int y, int width, int height, const uint8_t* pixels = nullptr);
void RecordFill(int x, int y, int width, int height, uint8_t index);
void RecordSprite(const void* pointer, int frame, int x, int y, int width, int height,
                  unsigned flags, const uint8_t* pixels, const uint8_t* remap, const uint8_t* ghost);
}
#endif
