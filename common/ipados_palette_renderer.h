#ifndef TIBERIAN_DAWN_IPADOS_PALETTE_RENDERER_H
#define TIBERIAN_DAWN_IPADOS_PALETTE_RENDERER_H

#include <cstdint>

struct SDL_Renderer;

struct IPadPaletteRect
{
    int x;
    int y;
    int width;
    int height;
};

struct IPadPaletteCursor
{
    const void* pixels;
    int pitch;
    int width;
    int height;
    int hotspot_x;
    int hotspot_y;
    int kind;
    IPadPaletteRect destination;
    bool visible;
    bool pixels_changed;
};

struct IPadSelectionOverlay
{
    IPadPaletteRect destination;
    std::uint8_t palette_index;
};

struct IPadHDBuggyOverlay
{
    IPadPaletteRect body_destination;
    IPadPaletteRect turret_destination;
    IPadPaletteRect health_destination;
    int body_frame;
    int turret_frame;
    int health_fill_width;
    std::uint8_t palette_index;
    std::uint8_t health_palette_index;
    bool health_visible;
    int atlas_kind;
};

struct IPadHDInfantryOverlay
{
    IPadPaletteRect destination;
    IPadPaletteRect health_destination;
    int frame;
    int health_fill_width;
    std::uint8_t palette_index;
    std::uint8_t health_palette_index;
    bool health_visible;
};

struct IPadHDBuildingOverlay
{
    IPadPaletteRect destination;
    IPadPaletteRect health_destination;
    int frame;
    int activity_frame;
    int health_fill_width;
    int completion;
    int damage;
    std::uint8_t palette_index;
    std::uint8_t health_palette_index;
    bool health_visible;
    bool repairing;
    int faction_kind;
};

typedef void* IPadPaletteRenderer;

IPadPaletteRenderer IPad_Palette_Create(SDL_Renderer* renderer,
                                        int width,
                                        int height,
                                        const char* modern_cursor_path,
                                        const char* buggy_atlas_path,
                                        const char* humvee_atlas_path,
                                        const char* minigunner_atlas_path,
                                        const char* gdi_mcv_atlas_path,
                                        const char* nod_mcv_atlas_path,
                                        const char* gdi_infrastructure_atlas_path,
                                        const char* nod_infrastructure_atlas_path,
                                        const char* gdi_infrastructure_activity_atlas_path,
                                        const char* nod_infrastructure_activity_atlas_path,
                                        int modern_asset_scale);
void IPad_Palette_Destroy(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Buggy_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Humvee_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Minigunner_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_GDI_MCV_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Nod_MCV_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_GDI_Infrastructure_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Nod_Infrastructure_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_GDI_Infrastructure_Activity_Artwork(IPadPaletteRenderer renderer);
bool IPad_Palette_Has_Nod_Infrastructure_Activity_Artwork(IPadPaletteRenderer renderer);

// presentation_mode: 0 = sharp fractional, 1 = integer pixel-perfect,
// 2 = classic nearest-neighbour fractional.
// artwork_mode: 0 = original palette output, 1 = optional modern filter.
bool IPad_Palette_Render(IPadPaletteRenderer renderer,
                         SDL_Renderer* sdl_renderer,
                         const void* indexed_pixels,
                         int indexed_pitch,
                         bool indexed_pixels_changed,
                         IPadPaletteRect indexed_update,
                         const std::uint8_t* rgb6_palette,
                         bool palette_changed,
                         int presentation_mode,
                         int artwork_mode,
                         IPadPaletteRect viewport,
                         IPadPaletteRect world_clip,
                         const IPadHDBuildingOverlay* buildings,
                         int building_count,
                         const IPadHDBuggyOverlay* buggies,
                         int buggy_count,
                         const IPadHDInfantryOverlay* infantry,
                         int infantry_count,
                         const IPadSelectionOverlay* selections,
                         int selection_count,
                         IPadPaletteCursor cursor, float map_zoom, int map_right, int map_top);

#endif
