#include "remastered_scene.h"
#include <algorithm>
#include <cctype>
#include <unordered_map>
namespace WPRemastered {
namespace {
std::unordered_map<const void*, std::string>& Assets() {
    static std::unordered_map<const void*, std::string> assets;
    return assets;
}
std::string Canonical(const char* filename) {
    std::string name = filename ? filename : "";
    const auto slash = name.find_last_of("/\\");
    if (slash != std::string::npos) name.erase(0, slash + 1);
    const auto dot = name.find_last_of('.');
    if (dot != std::string::npos) name.resize(dot);
    for (char& c : name) c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    return name;
}
Command Base(Command::Kind kind, int x, int y, int w, int h) {
    const Scene& s = Shared();
    Command c; c.kind = kind; c.x = x; c.y = y; c.width = w; c.height = h;
    c.theater = s.theater; c.owner = s.owner; c.shroud = s.shroud;
    c.clip_x = s.clip_x; c.clip_y = s.clip_y; c.clip_w = s.clip_w; c.clip_h = s.clip_h;
    return c;
}
bool Valid(int w, int h) { return w > 0 && h > 0 && w <= 4096 && h <= 4096; }
}
Scene& Shared() { static Scene scene; return scene; }
void Begin(int theater, int x, int y, int width, int height) {
    Scene& s = Shared(); s.commands.clear(); s.health.clear(); s.placement.clear(); s.valid = false; s.capturing = true;
    s.shroud = false; s.owner = -1; s.theater = theater;
    s.clip_x = x; s.clip_y = y; s.clip_w = width; s.clip_h = height;
}
void RecordPlacement(int x,int y,bool valid) { if(Shared().capturing){Placement p;p.x=x;p.y=y;p.valid=valid;Shared().placement.push_back(p);} }
void RecordHealth(int x, int y, int width, int fill, uint8_t color) {
    if (!Shared().capturing || width < 3 || width > 4096) return;
    Health health; health.x = x; health.y = y; health.width = width;
    health.fill = std::max(0, std::min(fill, width - 2)); health.color = color;
    Shared().health.push_back(health);
}
void End() { Shared().capturing = false; Shared().valid = true; }
void Clear() { Shared() = Scene(); }
void RegisterAsset(const void* pointer, const char* filename) {
    if (pointer && filename) Assets()[pointer] = Canonical(filename);
}
std::string AssetName(const void* pointer) {
    const auto it = Assets().find(pointer); return it == Assets().end() ? std::string() : it->second;
}
void RecordTile(const char* name, int frame, int x, int y, int width, int height, const uint8_t* pixels) {
    if (!Shared().capturing || !Valid(width, height)) return;
    Command c = Base(Command::Tile, x, y, width, height); c.asset = Canonical(name); c.frame = frame;
    if (pixels) { c.pixels.assign(pixels, pixels + width * height); c.alpha.assign(width * height, 255); }
    Shared().commands.push_back(std::move(c));
}
void RecordFill(int x, int y, int width, int height, uint8_t index) {
    if (!Shared().capturing || !Valid(width, height)) return;
    Command c = Base(Command::Fill, x, y, width, height);
    c.pixels.assign(width * height, index); c.alpha.assign(width * height, 255);
    Shared().commands.push_back(std::move(c));
}
void RecordSprite(const void* pointer, int frame, int x, int y, int width, int height,
                  unsigned flags, const uint8_t* pixels, const uint8_t* remap, const uint8_t* ghost) {
    if (!Shared().capturing || !pixels || !Valid(width, height)) return;
    Command c = Base(Command::Sprite, x, y, width, height);
    c.asset = AssetName(pointer); c.frame = frame; c.flags = flags; c.centered = (flags & 0x20) != 0;
    if (c.centered) { c.x -= width / 2; c.y -= height / 2; }
    const size_t size = static_cast<size_t>(width) * height;
    c.pixels.resize(size); c.alpha.resize(size);
    for (size_t i = 0; i < size; ++i) {
        const uint8_t p = pixels[i];
        c.pixels[i] = remap && (flags & 0x100) ? remap[p] : p;
        c.alpha[i] = p ? 255 : 0;
    }
    if (ghost && (flags & 0x1000)) {
        unsigned max_table = 0;
        bool has_table = false;
        for (unsigned i = 0; i < 256; ++i) if (ghost[i] != 255) {
            max_table = std::max(max_table, static_cast<unsigned>(ghost[i])); has_table = true;
        }
        c.ghost.assign(ghost, ghost + 256 + (has_table ? (max_table + 1) * 256 : 0));
    }
    Shared().commands.push_back(std::move(c));
}
void ClearSidebar() { Shared().sidebar.clear(); Shared().chrome.clear(); }
void RecordSidebarIcon(const char* asset, int x, int y, int width, int height,
                       int clip_x, int clip_y, int clip_w, int clip_h,
                       const uint8_t* base, const uint8_t* final, int progress, bool darken, int queued, int status) {
    if (!asset || !*asset || !base || !final || !Valid(width, height) || clip_w <= 0 || clip_h <= 0) return;
    SidebarIcon icon;
    icon.progress=progress;icon.darken=darken;icon.queued=queued;icon.status=status;
    icon.asset = asset; icon.x = x; icon.y = y; icon.width = width; icon.height = height;
    icon.clip_x = clip_x; icon.clip_y = clip_y; icon.clip_w = clip_w; icon.clip_h = clip_h;
    icon.base.assign(base, base + static_cast<size_t>(width) * height);
    icon.final.assign(final, final + static_cast<size_t>(width) * height);
    Shared().sidebar.push_back(std::move(icon));
}

}
