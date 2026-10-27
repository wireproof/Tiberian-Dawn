#include "common/remastered_scene.h"
#include "common/wireproof_production_queue.h"
#include <cstdio>
#include <cstdlib>
#include <vector>
// Explicit checks remain enabled in Release/RelWithDebInfo builds.
#define CHECK(condition) do { if (!(condition)) { std::fprintf(stderr, "line %d: %s\n", __LINE__, #condition); return EXIT_FAILURE; } } while (false)
int main() {
    WPProduction::Queue q;
    CHECK(q.add(2)&&q.add(2)&&q.add(3));CHECK(q.count(2)==2);
    CHECK(q.next(true)==-1);CHECK(q.next(false)==2);CHECK(q.next(false)==-1);
    CHECK(q.remove(2));CHECK(!q.remove(2)); // dispatched head is immutable
    q.retry();CHECK(q.next(false)==2);q.acknowledge(99);CHECK(q.next(false)==-1);q.acknowledge(2);
    CHECK(q.next(false)==3);q.acknowledge(3);CHECK(q.next(false)==-1);
    for(int i=0;i<99;++i)CHECK(q.add(i));CHECK(!q.add(100));q.clear();CHECK(q.next(false)==-1);
    using namespace WPRemastered;
    Clear();
    int identity = 1;
    RegisterAsset(&identity, "private/path/MTNK.SHP");
    CHECK(AssetName(&identity) == "MTNK");
    RegisterAsset(&identity, "FACTMAKE.SHP");
    CHECK(AssetName(&identity) == "FACTMAKE"); // Reused cached pointers must update.
    uint8_t pixels[] = {0, 1, 2, 3};
    uint8_t remap[256];
    for (int i = 0; i < 256; ++i) remap[i] = static_cast<uint8_t>(i);
    remap[1] = 0;
    RecordFill(0, 0, 2, 2, 0);
    RecordHealth(0, 0, 24, 22, 4);
    CHECK(Shared().commands.empty() && Shared().health.empty());
    Begin(1, 10, 20, 100, 200);
    RecordPlacement(24,48,true);CHECK(Shared().placement.size()==1 && Shared().placement[0].valid);
    Shared().owner = 1;
    RecordSprite(&identity, 32, 40, 50, 2, 2, 0x120, pixels, remap, nullptr);
    pixels[2] = 99; // Commands own their pixels, independent of reusable shape buffers.
    const Command& sprite = Shared().commands.front();
    CHECK(sprite.asset == "FACTMAKE" && sprite.frame == 32 && sprite.owner == 1);
    CHECK(sprite.x == 39 && sprite.y == 49 && sprite.centered);
    CHECK(sprite.clip_x == 10 && sprite.clip_y == 20 && sprite.clip_w == 100 && sprite.clip_h == 200);
    CHECK(sprite.pixels[2] == 2);
    CHECK(sprite.pixels[0] == 0 && sprite.alpha[0] == 0);
    CHECK(sprite.pixels[1] == 0 && sprite.alpha[1] == 255); // Opaque palette black is not transparency.
    Shared().shroud = true;
    RecordFill(10, 20, 2, 2, 0);
    CHECK(Shared().commands.back().shroud && Shared().commands.back().alpha[0] == 255);
    Shared().shroud = false;
    RecordHealth(12, 23, 24, 100, 5);
    CHECK(Shared().health.size() == 1 && Shared().health.front().fill == 22);
    CHECK(Shared().health.front().color == 5);
    End();
    CHECK(Shared().valid && !Shared().capturing);
    RecordHealth(0, 0, 24, 22, 5);
    CHECK(Shared().health.size() == 1);
    Begin(0, 0, 0, 20, 20);
    CHECK(Shared().commands.empty() && Shared().health.empty() && Shared().placement.empty() && !Shared().valid);
    RecordTile("CLEAR1.TEM", 4, -12, 0, 2, 2, pixels);
    CHECK(Shared().commands.front().asset == "CLEAR1");
    CHECK(Shared().commands.front().frame == 4 && Shared().commands.front().x == -12);
    CHECK(Shared().commands.front().alpha[0] == 255); // Ground tile zero is opaque.
    std::vector<uint8_t> ghost(256 + 512, 255);
    ghost[2] = 1; ghost[256 + 256 + 17] = 42;
    RecordSprite(&identity, 0, 0, 0, 2, 2, 0x1000, pixels, nullptr, ghost.data());
    CHECK(Shared().commands.back().ghost.size() == 768);
    CHECK(Shared().commands.back().ghost[529] == 42);
    const size_t before = Shared().commands.size();
    RecordTile("CLEAR1", 0, 0, 0, -1, 2, pixels);
    RecordSprite(&identity, 0, 0, 0, 2, 2, 0, nullptr, nullptr, nullptr);
    CHECK(Shared().commands.size() == before);
    Clear();
    CHECK(!Shared().valid && Shared().commands.empty() && Shared().health.empty());
    return EXIT_SUCCESS;
}
