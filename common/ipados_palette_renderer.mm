#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>

#include "ipados_palette_renderer.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <SDL.h>

@interface TiberianDawnPaletteRendererState : NSObject
{
@public
    id<MTLDevice> Device;
    id<MTLRenderPipelineState> BasePipeline;
    id<MTLRenderPipelineState> CursorPipeline;
    id<MTLRenderPipelineState> ModernCursorPipeline;
    id<MTLRenderPipelineState> SelectionPipeline;
    id<MTLRenderPipelineState> HDSpritePipeline;
    id<MTLRenderPipelineState> HDBuildingPipeline;
    id<MTLRenderPipelineState> HDSpriteShadowPipeline;
    id<MTLRenderPipelineState> HealthPipeline;
    id<MTLTexture> IndexTexture;
    id<MTLTexture> PaletteTexture;
    id<MTLTexture> CursorTexture;
    id<MTLTexture> ModernCursorTexture;
    id<MTLTexture> BuggyAtlasTexture;
    id<MTLTexture> HumveeAtlasTexture;
    id<MTLTexture> MinigunnerAtlasTexture;
    id<MTLTexture> GDIMCVAtlasTexture;
    id<MTLTexture> NodMCVAtlasTexture;
    id<MTLTexture> GDIInfrastructureAtlasTexture;
    id<MTLTexture> NodInfrastructureAtlasTexture;
    id<MTLTexture> GDIInfrastructureActivityAtlasTexture;
    id<MTLTexture> NodInfrastructureActivityAtlasTexture;
    int Width;
    int Height;
    int CursorWidth;
    int CursorHeight;
    int ModernAssetScale;
    bool HasIndices;
    bool HasPalette;
    bool HasCursor;
}
@end

@implementation TiberianDawnPaletteRendererState
@end

namespace
{
const char* PaletteShaderSource = R"METAL(
#include <metal_stdlib>
using namespace metal;

struct PaletteVertexOutput { float4 position [[position]]; float2 uv; };
struct PaletteParameters {
    packed_float2 source_size;
    packed_float2 output_size;
    uint mode;
    uint artwork_mode;
};

struct BuildingParameters {
    packed_float2 source_size;
    packed_float2 output_size;
    uint mode;
    uint artwork_mode;
    float completion;
    float damage;
    uint repairing;
    uint padding;
};

vertex PaletteVertexOutput TiberianDawnPaletteVertex(uint vertex_id [[vertex_id]])
{
    const float2 positions[] = {
        float2(-1.0, 1.0), float2(-1.0, -1.0), float2(1.0, -1.0),
        float2(-1.0, 1.0), float2(1.0, -1.0), float2(1.0, 1.0)
    };
    const float2 coordinates[] = {
        float2(0.0, 0.0), float2(0.0, 1.0), float2(1.0, 1.0),
        float2(0.0, 0.0), float2(1.0, 1.0), float2(1.0, 0.0)
    };
    PaletteVertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    output.uv = coordinates[vertex_id];
    return output;
}

static float4 palette_color(texture2d<uint, access::read> indices,
                            texture2d<float, access::read> palette,
                            int2 coordinate,
                            int2 source_size)
{
    const uint2 clamped = uint2(clamp(coordinate, int2(0), source_size - 1));
    const uint index = indices.read(clamped).r;
    return palette.read(uint2(index, 0));
}

static float color_distance(float3 first, float3 second)
{
    const float3 difference = abs(first - second);
    return dot(difference, float3(0.299, 0.587, 0.114));
}

static float corner_proximity(float2 local, float2 corner)
{
    return 1.0 - smoothstep(0.12, 0.72, length(local - corner));
}

static float4 modernized_color(texture2d<uint, access::read> indices,
                               texture2d<float, access::read> palette,
                               float2 uv,
                               int2 source_size,
                               float4 presented)
{
    const float2 source_coordinate = uv * float2(source_size);
    const int2 center_coordinate = int2(source_coordinate);
    const float2 local = fract(source_coordinate);
    const float3 center = palette_color(indices, palette, center_coordinate, source_size).rgb;
    const float3 north = palette_color(indices, palette, center_coordinate + int2(0, -1), source_size).rgb;
    const float3 south = palette_color(indices, palette, center_coordinate + int2(0, 1), source_size).rgb;
    const float3 west = palette_color(indices, palette, center_coordinate + int2(-1, 0), source_size).rgb;
    const float3 east = palette_color(indices, palette, center_coordinate + int2(1, 0), source_size).rgb;

    float corner_weight = 0.0;
    float3 corner_color = presented.rgb;
#define TIBERIAN_DAWN_CORNER(first, second, location) \
    { \
        const float agreement = 1.0 - smoothstep(0.035, 0.14, color_distance(first, second)); \
        const float separation = smoothstep(0.07, 0.24, \
            min(color_distance(center, first), color_distance(center, second))); \
        const float candidate_weight = agreement * separation * corner_proximity(local, location); \
        if (candidate_weight > corner_weight) { \
            corner_weight = candidate_weight; \
            corner_color = (first + second) * 0.5; \
        } \
    }
    TIBERIAN_DAWN_CORNER(north, west, float2(0.0, 0.0));
    TIBERIAN_DAWN_CORNER(north, east, float2(1.0, 0.0));
    TIBERIAN_DAWN_CORNER(south, west, float2(0.0, 1.0));
    TIBERIAN_DAWN_CORNER(south, east, float2(1.0, 1.0));
#undef TIBERIAN_DAWN_CORNER

    float3 result = mix(presented.rgb, corner_color, min(0.24, corner_weight * 0.24));
    const float3 neighbour_average = (north + south + west + east) * 0.25;
    const float edge = max(max(color_distance(center, north), color_distance(center, south)),
                           max(color_distance(center, west), color_distance(center, east)));
    const float detail_strength = (1.0 - smoothstep(0.35, 0.85, edge)) * (1.0 - corner_weight) * 0.055;
    result += (center - neighbour_average) * detail_strength;

    const float luminance = dot(result, float3(0.299, 0.587, 0.114));
    result = mix(float3(luminance), result, 1.05);
    const float3 contrast_curve = result * result * (3.0 - 2.0 * result);
    result = mix(result, contrast_curve, 0.10);
    return float4(clamp(result, 0.0, 1.0), presented.a);
}

fragment float4 TiberianDawnPaletteFragment(PaletteVertexOutput input [[stage_in]],
                                         constant PaletteParameters& parameters [[buffer(0)]],
                                         constant float4& scene [[buffer(1)]],
                                         constant float2& view_size [[buffer(2)]],
                                         texture2d<uint, access::read> indices [[texture(0)]],
                                         texture2d<float, access::read> palette [[texture(1)]])
{
    const float2 source_size = float2(parameters.source_size);
    const int2 integer_source_size = int2(source_size);
    float2 point = input.uv * view_size;
    if(scene.y>0 && point.y<scene.z && view_size.x<480) {
        point.x*=480.0/view_size.x;
        if(point.x>=160)point.x+=source_size.x-480;
    }
    else if (scene.y > 0 && (point.x < scene.y || point.y >= scene.w) && point.y >= scene.z) {
        point.x /= scene.x;
        point.y = scene.z + (point.y - scene.z) / scene.x;
    }
    else if (scene.y>0 && ((point.y>=scene.z && point.y<scene.w && point.x>=scene.y) || (point.y<scene.z && point.x>=view_size.x-320))) {
        point.x+=source_size.x-view_size.x;
    }
    const float2 uv = point / source_size;
    const float2 source_position = point - 0.5;
    const int2 base = int2(floor(source_position));
    float4 presented;
    if (parameters.mode != 0) {
        presented = palette_color(indices, palette, int2(point), integer_source_size);
    } else {
        const float2 scale = max(float2(parameters.output_size) / source_size, float2(1.0));
        const float2 fraction = fract(source_position);
        const float2 half_width = min(float2(0.5), float2(0.5) / scale);
        const float2 blend = smoothstep(float2(0.5) - half_width, float2(0.5) + half_width, fraction);
        const float4 top_left = palette_color(indices, palette, base, integer_source_size);
        const float4 top_right = palette_color(indices, palette, base + int2(1, 0), integer_source_size);
        const float4 bottom_left = palette_color(indices, palette, base + int2(0, 1), integer_source_size);
        const float4 bottom_right = palette_color(indices, palette, base + int2(1, 1), integer_source_size);
        presented = mix(mix(top_left, top_right, blend.x), mix(bottom_left, bottom_right, blend.x), blend.y);
    }
    return parameters.artwork_mode == 0
        ? presented
        : modernized_color(indices, palette, uv, integer_source_size, presented);
}

fragment float4 TiberianDawnPaletteCursorFragment(PaletteVertexOutput input [[stage_in]],
                                               constant PaletteParameters& parameters [[buffer(0)]],
                                               texture2d<uint, access::read> indices [[texture(0)]],
                                               texture2d<float, access::read> palette [[texture(1)]])
{
    const int2 source_size = int2(float2(parameters.source_size));
    return palette_color(indices, palette, int2(input.uv * float2(source_size)), source_size);
}

fragment float4 TiberianDawnModernCursorFragment(PaletteVertexOutput input [[stage_in]],
                                              texture2d<float> artwork [[texture(0)]])
{
    constexpr sampler artwork_sampler(coord::normalized,
                                      address::clamp_to_edge,
                                      min_filter::linear,
                                      mag_filter::linear);
    return artwork.sample(artwork_sampler, input.uv);
}

fragment float4 TiberianDawnHDSpriteFragment(PaletteVertexOutput input [[stage_in]],
                                          constant PaletteParameters& parameters [[buffer(0)]],
                                          texture2d<float> atlas [[texture(0)]],
                                          texture2d<float, access::read> palette [[texture(1)]])
{
    constexpr sampler sprite_sampler(coord::normalized,
                                     address::clamp_to_edge,
                                     min_filter::linear,
                                     mag_filter::linear);
    const uint frame = parameters.mode;
    const uint columns = max(uint(parameters.source_size.x), 1u);
    const float rows = max(float(parameters.source_size.y), 1.0);
    const float2 atlas_size = float2(atlas.get_width(), atlas.get_height());
    const float2 cell = float2(frame % columns, frame / columns);
    const float2 inset = 0.5 / atlas_size;
    const float2 grid = float2(float(columns), rows);
    const float2 cell_min = cell / grid + inset;
    const float2 cell_max = (cell + 1.0) / grid - inset;
    const float2 atlas_uv = mix(cell_min, cell_max, input.uv);
    float4 artwork = atlas.sample(sprite_sampler, atlas_uv);
    if (artwork.a <= 0.002) discard_fragment();

    // The generated master uses neutral light body panels. Tint those panels
    // with the current house colour while preserving metal, tyres and detail.
    const float maximum = max(artwork.r, max(artwork.g, artwork.b));
    const float minimum = min(artwork.r, min(artwork.g, artwork.b));
    const float saturation = maximum - minimum;
    const float luminance = dot(artwork.rgb, float3(0.299, 0.587, 0.114));
    const float neutral = 1.0 - smoothstep(0.055, 0.22, saturation);
    const float paint = neutral * smoothstep(0.28, 0.70, luminance) * (1.0 - smoothstep(0.88, 0.99, luminance));
    const float3 house = palette.read(uint2(parameters.artwork_mode & 255u, 0)).rgb;
    const float house_luminance = dot(house, float3(0.299, 0.587, 0.114));
    const float3 readable_house = mix(house, float3(1.0), clamp(0.28 - house_luminance * 0.15, 0.06, 0.22));
    artwork.rgb = mix(artwork.rgb, readable_house * (0.62 + luminance * 0.48), paint * 0.78);
    return artwork;
}

fragment float4 TiberianDawnHDBuildingFragment(PaletteVertexOutput input [[stage_in]],
                                            constant BuildingParameters& parameters [[buffer(0)]],
                                            texture2d<float> atlas [[texture(0)]],
                                            texture2d<float, access::read> palette [[texture(1)]])
{
    constexpr sampler sprite_sampler(coord::normalized,
                                     address::clamp_to_edge,
                                     min_filter::linear,
                                     mag_filter::linear);
    const uint frame = parameters.mode;
    const uint columns = max(uint(parameters.source_size.x), 1u);
    const float rows = max(float(parameters.source_size.y), 1.0);
    const float2 atlas_size = float2(atlas.get_width(), atlas.get_height());
    const float2 cell = float2(frame % columns, frame / columns);
    const float2 inset = 0.5 / atlas_size;
    const float2 grid = float2(float(columns), rows);
    const float2 atlas_uv = mix(cell / grid + inset,
                                (cell + 1.0) / grid - inset,
                                input.uv);
    float4 artwork = atlas.sample(sprite_sampler, atlas_uv);
    if (artwork.a <= 0.002) discard_fragment();

    const float completion = clamp(parameters.completion, 0.0, 1.0);
    const float2 reveal_cell = floor(input.uv * float2(79.0, 61.0));
    const float reveal_noise = fract(sin(dot(reveal_cell,
                                             float2(12.9898, 78.233))
                                           + float(frame) * 19.19) * 43758.5453);
    const float reveal_edge = 1.0 - completion;
    const float reveal_position = input.uv.y + (reveal_noise - 0.5) * 0.075;
    if (completion < 0.999 && reveal_position < reveal_edge) discard_fragment();

    // Preserve the same neutral-panel house-colour treatment as mobile HD art.
    const float maximum = max(artwork.r, max(artwork.g, artwork.b));
    const float minimum = min(artwork.r, min(artwork.g, artwork.b));
    const float saturation = maximum - minimum;
    const float luminance = dot(artwork.rgb, float3(0.299, 0.587, 0.114));
    const float neutral = 1.0 - smoothstep(0.055, 0.22, saturation);
    const float paint = neutral * smoothstep(0.28, 0.70, luminance)
                        * (1.0 - smoothstep(0.88, 0.99, luminance));
    const float3 house = palette.read(uint2(parameters.artwork_mode & 255u, 0)).rgb;
    const float house_luminance = dot(house, float3(0.299, 0.587, 0.114));
    const float3 readable_house = mix(house,
                                      float3(1.0),
                                      clamp(0.28 - house_luminance * 0.15, 0.06, 0.22));
    artwork.rgb = mix(artwork.rgb,
                      readable_house * (0.62 + luminance * 0.48),
                      paint * 0.78);

    // Construction and deconstruction share one bottom-up assembly mask. The
    // engine reverses completion for sell/deploy-back, avoiding any style cut.
    if (completion < 0.999) {
        const float assembly_band = 1.0 - smoothstep(0.018,
                                                     0.085,
                                                     abs(reveal_position - reveal_edge));
        artwork.rgb = mix(artwork.rgb, float3(0.96, 0.68, 0.18), assembly_band * 0.48);
    }

    // A stable procedural soot pattern communicates damage without switching
    // back to the low-resolution damaged SHP. As health returns, it fades out.
    const float damage = clamp(parameters.damage, 0.0, 1.0);
    const float2 damage_cell = floor(input.uv * float2(43.0, 37.0));
    const float soot_noise = fract(sin(dot(damage_cell,
                                           float2(39.3468, 11.135))
                                         + float(frame) * 7.73) * 24634.6345);
    const float soot = damage * smoothstep(0.76 - damage * 0.24, 0.98, soot_noise);
    const float damaged_luminance = dot(artwork.rgb, float3(0.299, 0.587, 0.114));
    artwork.rgb = mix(artwork.rgb, float3(damaged_luminance) * 0.58, damage * 0.42);
    artwork.rgb *= 1.0 - damage * 0.16 - soot * 0.48;
    const float ember = smoothstep(0.975, 0.997, soot_noise)
                        * smoothstep(0.58, 0.96, damage);
    artwork.rgb += ember * float3(0.34, 0.055, 0.008);

    if (parameters.repairing != 0u) {
        const float repair_line = smoothstep(0.82,
                                             0.98,
                                             fract((input.uv.x + input.uv.y) * 7.0));
        artwork.rgb = mix(artwork.rgb, float3(0.42, 0.92, 0.58), repair_line * 0.18);
    }
    artwork.rgb = clamp(artwork.rgb, 0.0, 1.0);
    return artwork;
}

fragment float4 TiberianDawnHDShadowFragment(PaletteVertexOutput input [[stage_in]],
                                          constant PaletteParameters& parameters [[buffer(0)]],
                                          texture2d<float> atlas [[texture(0)]])
{
    constexpr sampler sprite_sampler(coord::normalized,
                                     address::clamp_to_edge,
                                     min_filter::linear,
                                     mag_filter::linear);
    const uint frame = parameters.mode;
    const uint columns = max(uint(parameters.source_size.x), 1u);
    const float rows = max(float(parameters.source_size.y), 1.0);
    const float2 atlas_size = float2(atlas.get_width(), atlas.get_height());
    const float2 cell = float2(frame % columns, frame / columns);
    const float2 inset = 0.5 / atlas_size;
    const float2 grid = float2(float(columns), rows);
    const float2 atlas_uv = mix(cell / grid + inset,
                                (cell + 1.0) / grid - inset,
                                input.uv);
    const float alpha = atlas.sample(sprite_sampler, atlas_uv).a;
    if (alpha <= 0.002) discard_fragment();
    return float4(0.0, 0.0, 0.0, alpha * 0.30);
}

fragment float4 TiberianDawnHealthFragment(PaletteVertexOutput input [[stage_in]],
                                        constant PaletteParameters& parameters [[buffer(0)]],
                                        texture2d<float, access::read> palette [[texture(1)]])
{
    const float2 size = max(float2(parameters.output_size), float2(1.0));
    const float2 pixel = input.uv * size;
    const float border = max(1.0, floor(size.y * 0.22));
    const bool outline = pixel.x < border || pixel.x >= size.x - border
                         || pixel.y < border || pixel.y >= size.y - border;
    if (outline) return float4(0.008, 0.010, 0.008, 0.96);

    const float fill_width = max(0.0, float(parameters.source_size.x));
    if (pixel.x < border + fill_width) {
        const float3 health = palette.read(uint2(parameters.mode & 255u, 0)).rgb;
        return float4(health, 0.98);
    }
    return float4(0.055, 0.060, 0.052, 0.94);
}

fragment float4 TiberianDawnSelectionFragment(PaletteVertexOutput input [[stage_in]],
                                           constant PaletteParameters& parameters [[buffer(0)]],
                                           texture2d<float, access::read> palette [[texture(1)]])
{
    const float2 size = max(float2(parameters.output_size), float2(1.0));
    const float2 pixel = input.uv * size;
    const float corner_length = clamp(min(size.x, size.y) * 0.30, 10.0, 38.0);

    const float horizontal_corner = max(1.0 - smoothstep(corner_length, corner_length + 1.5, pixel.x),
                                        smoothstep(size.x - corner_length - 1.5,
                                                   size.x - corner_length,
                                                   pixel.x));
    const float vertical_corner = max(1.0 - smoothstep(corner_length, corner_length + 1.5, pixel.y),
                                      smoothstep(size.y - corner_length - 1.5,
                                                 size.y - corner_length,
                                                 pixel.y));
    const float horizontal_distance = min(pixel.y, size.y - pixel.y);
    const float vertical_distance = min(pixel.x, size.x - pixel.x);
    const float edge_distance = min(horizontal_distance, vertical_distance);

    const float corner = max((1.0 - smoothstep(5.0, 7.0, horizontal_distance)) * horizontal_corner,
                             (1.0 - smoothstep(5.0, 7.0, vertical_distance)) * vertical_corner);
    const float outline = 1.0 - smoothstep(4.5, 6.5, edge_distance);
    const float accent_line = 1.0 - smoothstep(1.25, 2.75, edge_distance);
    const float frame = max(outline * 0.78, corner);

    const float3 house_color = palette.read(uint2(parameters.mode & 255u, 0)).rgb;
    const float luminance = dot(house_color, float3(0.299, 0.587, 0.114));
    const float3 accent = mix(house_color, float3(1.0), clamp(0.42 - luminance * 0.25, 0.12, 0.34));
    const float3 outline_color = float3(0.012, 0.016, 0.014);
    if (frame > 0.001) {
        const float accent_weight = max(accent_line, corner * 0.86);
        return float4(mix(outline_color, accent, accent_weight), max(frame * 0.92, accent_weight));
    }

    // A restrained tint keeps the selected footprint readable without hiding
    // unit detail. It also makes the modern indicator unmistakable on bright terrain.
    return float4(accent, 0.055);
}
)METAL";

struct PaletteParameters
{
    float source_width;
    float source_height;
    float output_width;
    float output_height;
    std::uint32_t mode;
    std::uint32_t artwork_mode;
};

struct BuildingParameters
{
    float source_width;
    float source_height;
    float output_width;
    float output_height;
    std::uint32_t mode;
    std::uint32_t artwork_mode;
    float completion;
    float damage;
    std::uint32_t repairing;
    std::uint32_t padding;
};

TiberianDawnPaletteRendererState* State(IPadPaletteRenderer renderer)
{
    return (__bridge TiberianDawnPaletteRendererState*)renderer;
}

id<MTLTexture> MakeIndexTexture(id<MTLDevice> device, int width, int height)
{
    if (!device || width <= 0 || height <= 0) return nil;
    MTLTextureDescriptor* descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Uint
                                 width:static_cast<NSUInteger>(width)
                                height:static_cast<NSUInteger>(height)
                             mipmapped:NO];
    descriptor.usage = MTLTextureUsageShaderRead;
    descriptor.storageMode = MTLStorageModeShared;
    return [device newTextureWithDescriptor:descriptor];
}

id<MTLRenderPipelineState> MakePipeline(id<MTLDevice> device,
                                        id<MTLLibrary> library,
                                        MTLPixelFormat output_format,
                                        NSString* fragment_name,
                                        bool blending)
{
    id<MTLFunction> vertex = [library newFunctionWithName:@"TiberianDawnPaletteVertex"];
    id<MTLFunction> fragment = [library newFunctionWithName:fragment_name];
    if (!vertex || !fragment) return nil;

    MTLRenderPipelineDescriptor* descriptor = [MTLRenderPipelineDescriptor new];
    descriptor.label = [@"Tiberian Dawn " stringByAppendingString:fragment_name];
    descriptor.vertexFunction = vertex;
    descriptor.fragmentFunction = fragment;
    descriptor.colorAttachments[0].pixelFormat = output_format;
    if (blending) {
        descriptor.colorAttachments[0].blendingEnabled = YES;
        descriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        descriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    }
    NSError* error = nil;
    id<MTLRenderPipelineState> pipeline = [device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    if (!pipeline) NSLog(@"Tiberian Dawn palette pipeline failed: %@", error.localizedDescription);
    return pipeline;
}

void SetViewport(id<MTLRenderCommandEncoder> encoder, IPadPaletteRect rectangle)
{
    MTLViewport viewport = {static_cast<double>(rectangle.x),
                            static_cast<double>(rectangle.y),
                            static_cast<double>(rectangle.width),
                            static_cast<double>(rectangle.height),
                            0.0,
                            1.0};
    [encoder setViewport:viewport];
}

void SetScissor(id<MTLRenderCommandEncoder> encoder, IPadPaletteRect rectangle, CAMetalLayer* layer)
{
    const int width = static_cast<int>(layer.drawableSize.width);
    const int height = static_cast<int>(layer.drawableSize.height);
    const int left = std::max(0, rectangle.x);
    const int top = std::max(0, rectangle.y);
    const int right = std::max(left, std::min(width, rectangle.x + rectangle.width));
    const int bottom = std::max(top, std::min(height, rectangle.y + rectangle.height));
    MTLScissorRect scissor = {static_cast<NSUInteger>(left),
                              static_cast<NSUInteger>(top),
                              static_cast<NSUInteger>(right - left),
                              static_cast<NSUInteger>(bottom - top)};
    [encoder setScissorRect:scissor];
}
}

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
                                        int modern_asset_scale)
{
    if (!renderer || width <= 0 || height <= 0) return nullptr;
    CAMetalLayer* layer = (__bridge CAMetalLayer*)SDL_RenderGetMetalLayer(renderer);
    if (!layer || !layer.device) return nullptr;

    NSError* library_error = nil;
    NSString* source = [NSString stringWithUTF8String:PaletteShaderSource];
    id<MTLLibrary> library = [layer.device newLibraryWithSource:source options:nil error:&library_error];
    if (!library) {
        NSLog(@"Tiberian Dawn palette renderer unavailable; using SDL fallback: %@", library_error.localizedDescription);
        return nullptr;
    }

    TiberianDawnPaletteRendererState* state = [TiberianDawnPaletteRendererState new];
    state->Device = layer.device;
    state->Width = width;
    state->Height = height;
    state->IndexTexture = MakeIndexTexture(state->Device, width, height);

    MTLTextureDescriptor* palette_descriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                 width:256
                                height:1
                             mipmapped:NO];
    palette_descriptor.usage = MTLTextureUsageShaderRead;
    palette_descriptor.storageMode = MTLStorageModeShared;
    state->PaletteTexture = [state->Device newTextureWithDescriptor:palette_descriptor];
    state->BasePipeline = MakePipeline(state->Device,
                                       library,
                                       layer.pixelFormat,
                                       @"TiberianDawnPaletteFragment",
                                       false);
    state->CursorPipeline = MakePipeline(state->Device,
                                         library,
                                         layer.pixelFormat,
                                         @"TiberianDawnPaletteCursorFragment",
                                         true);
    state->ModernCursorPipeline = MakePipeline(state->Device,
                                               library,
                                               layer.pixelFormat,
                                               @"TiberianDawnModernCursorFragment",
                                               true);
    state->SelectionPipeline = MakePipeline(state->Device,
                                            library,
                                            layer.pixelFormat,
                                            @"TiberianDawnSelectionFragment",
                                            true);
    state->HDSpritePipeline = MakePipeline(state->Device,
                                           library,
                                           layer.pixelFormat,
                                           @"TiberianDawnHDSpriteFragment",
                                           true);
    state->HDBuildingPipeline = MakePipeline(state->Device,
                                             library,
                                             layer.pixelFormat,
                                             @"TiberianDawnHDBuildingFragment",
                                             true);
    state->HDSpriteShadowPipeline = MakePipeline(state->Device,
                                                 library,
                                                 layer.pixelFormat,
                                                 @"TiberianDawnHDShadowFragment",
                                                 true);
    state->HealthPipeline = MakePipeline(state->Device,
                                         library,
                                         layer.pixelFormat,
                                         @"TiberianDawnHealthFragment",
                                         true);
    state->ModernAssetScale = modern_asset_scale == 2 || modern_asset_scale == 4 ? modern_asset_scale : 4;
    MTKTextureLoader* loader = [[MTKTextureLoader alloc] initWithDevice:state->Device];
    if (modern_cursor_path && modern_cursor_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:modern_cursor_path];
        NSError* texture_error = nil;
        state->ModernCursorTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                  options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                            MTKTextureLoaderOptionOrigin:
                                                                                MTKTextureLoaderOriginTopLeft}
                                                                    error:&texture_error];
        if (!state->ModernCursorTexture) {
            NSLog(@"Tiberian Dawn HD cursor rejected; original cursor fallback active: %@", texture_error.localizedDescription);
        } else {
            NSLog(@"Tiberian Dawn HD cursor active: %lux%lu, logical scale %dx",
                  static_cast<unsigned long>(state->ModernCursorTexture.width),
                  static_cast<unsigned long>(state->ModernCursorTexture.height),
                  state->ModernAssetScale);
        }
    }
    if (buggy_atlas_path && buggy_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:buggy_atlas_path];
        NSError* texture_error = nil;
        state->BuggyAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                               options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                         MTKTextureLoaderOptionOrigin:
                                                                             MTKTextureLoaderOriginTopLeft}
                                                                 error:&texture_error];
        if (!state->BuggyAtlasTexture || state->BuggyAtlasTexture.width != 768
            || state->BuggyAtlasTexture.height != 768) {
            NSLog(@"Tiberian Dawn HD buggy atlas rejected; original sprite fallback active: %@", texture_error.localizedDescription);
            state->BuggyAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD buggy atlas active: %lux%lu, 64 frames",
                  static_cast<unsigned long>(state->BuggyAtlasTexture.width),
                  static_cast<unsigned long>(state->BuggyAtlasTexture.height));
        }
    }
    if (humvee_atlas_path && humvee_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:humvee_atlas_path];
        NSError* texture_error = nil;
        state->HumveeAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                          MTKTextureLoaderOptionOrigin:
                                                                              MTKTextureLoaderOriginTopLeft}
                                                                  error:&texture_error];
        if (!state->HumveeAtlasTexture || state->HumveeAtlasTexture.width != 768
            || state->HumveeAtlasTexture.height != 768) {
            NSLog(@"Tiberian Dawn HD humvee atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->HumveeAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD humvee atlas active: %lux%lu, 64 frames",
                  static_cast<unsigned long>(state->HumveeAtlasTexture.width),
                  static_cast<unsigned long>(state->HumveeAtlasTexture.height));
        }
    }
    if (minigunner_atlas_path && minigunner_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:minigunner_atlas_path];
        NSError* texture_error = nil;
        state->MinigunnerAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                   options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                             MTKTextureLoaderOptionOrigin:
                                                                                 MTKTextureLoaderOriginTopLeft}
                                                                     error:&texture_error];
        if (!state->MinigunnerAtlasTexture || state->MinigunnerAtlasTexture.width != 768
            || state->MinigunnerAtlasTexture.height != 960) {
            NSLog(@"Tiberian Dawn HD minigunner atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->MinigunnerAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD minigunner atlas active: %lux%lu, 80 frames",
                  static_cast<unsigned long>(state->MinigunnerAtlasTexture.width),
                  static_cast<unsigned long>(state->MinigunnerAtlasTexture.height));
        }
    }
    if (gdi_mcv_atlas_path && gdi_mcv_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:gdi_mcv_atlas_path];
        NSError* texture_error = nil;
        state->GDIMCVAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                               options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                         MTKTextureLoaderOptionOrigin:
                                                                             MTKTextureLoaderOriginTopLeft}
                                                                 error:&texture_error];
        if (!state->GDIMCVAtlasTexture || state->GDIMCVAtlasTexture.width != 1536
            || state->GDIMCVAtlasTexture.height != 192) {
            NSLog(@"Tiberian Dawn HD GDI MCV atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->GDIMCVAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD GDI MCV atlas active: %lux%lu, 8 frames",
                  static_cast<unsigned long>(state->GDIMCVAtlasTexture.width),
                  static_cast<unsigned long>(state->GDIMCVAtlasTexture.height));
        }
    }
    if (nod_mcv_atlas_path && nod_mcv_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:nod_mcv_atlas_path];
        NSError* texture_error = nil;
        state->NodMCVAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                               options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                         MTKTextureLoaderOptionOrigin:
                                                                             MTKTextureLoaderOriginTopLeft}
                                                                 error:&texture_error];
        if (!state->NodMCVAtlasTexture || state->NodMCVAtlasTexture.width != 1536
            || state->NodMCVAtlasTexture.height != 192) {
            NSLog(@"Tiberian Dawn HD Nod MCV atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->NodMCVAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD Nod MCV atlas active: %lux%lu, 8 frames",
                  static_cast<unsigned long>(state->NodMCVAtlasTexture.width),
                  static_cast<unsigned long>(state->NodMCVAtlasTexture.height));
        }
    }
    if (gdi_infrastructure_atlas_path && gdi_infrastructure_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:gdi_infrastructure_atlas_path];
        NSError* texture_error = nil;
        state->GDIInfrastructureAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                          options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                                    MTKTextureLoaderOptionOrigin:
                                                                                        MTKTextureLoaderOriginTopLeft}
                                                                            error:&texture_error];
        if (!state->GDIInfrastructureAtlasTexture || state->GDIInfrastructureAtlasTexture.width != 768
            || state->GDIInfrastructureAtlasTexture.height != 256) {
            NSLog(@"Tiberian Dawn HD GDI infrastructure atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->GDIInfrastructureAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD GDI infrastructure atlas active: %lux%lu, 3 frames",
                  static_cast<unsigned long>(state->GDIInfrastructureAtlasTexture.width),
                  static_cast<unsigned long>(state->GDIInfrastructureAtlasTexture.height));
        }
    }
    if (nod_infrastructure_atlas_path && nod_infrastructure_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:nod_infrastructure_atlas_path];
        NSError* texture_error = nil;
        state->NodInfrastructureAtlasTexture = [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                                          options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                                                    MTKTextureLoaderOptionOrigin:
                                                                                        MTKTextureLoaderOriginTopLeft}
                                                                            error:&texture_error];
        if (!state->NodInfrastructureAtlasTexture || state->NodInfrastructureAtlasTexture.width != 768
            || state->NodInfrastructureAtlasTexture.height != 256) {
            NSLog(@"Tiberian Dawn HD Nod infrastructure atlas rejected; original sprite fallback active: %@",
                  texture_error.localizedDescription);
            state->NodInfrastructureAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD Nod infrastructure atlas active: %lux%lu, 3 frames",
                  static_cast<unsigned long>(state->NodInfrastructureAtlasTexture.width),
                  static_cast<unsigned long>(state->NodInfrastructureAtlasTexture.height));
        }
    }
    if (gdi_infrastructure_activity_atlas_path && gdi_infrastructure_activity_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:gdi_infrastructure_activity_atlas_path];
        NSError* texture_error = nil;
        state->GDIInfrastructureActivityAtlasTexture =
            [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                        options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                  MTKTextureLoaderOptionOrigin:
                                                      MTKTextureLoaderOriginTopLeft}
                                          error:&texture_error];
        if (!state->GDIInfrastructureActivityAtlasTexture
            || state->GDIInfrastructureActivityAtlasTexture.width != 2560
            || state->GDIInfrastructureActivityAtlasTexture.height != 768) {
            NSLog(@"Tiberian Dawn HD GDI infrastructure activity atlas rejected; original animation fallback active: %@",
                  texture_error.localizedDescription);
            state->GDIInfrastructureActivityAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD GDI infrastructure activity atlas active: %lux%lu, 30 frames",
                  static_cast<unsigned long>(state->GDIInfrastructureActivityAtlasTexture.width),
                  static_cast<unsigned long>(state->GDIInfrastructureActivityAtlasTexture.height));
        }
    }
    if (nod_infrastructure_activity_atlas_path && nod_infrastructure_activity_atlas_path[0] != '\0') {
        NSString* path = [NSString stringWithUTF8String:nod_infrastructure_activity_atlas_path];
        NSError* texture_error = nil;
        state->NodInfrastructureActivityAtlasTexture =
            [loader newTextureWithContentsOfURL:[NSURL fileURLWithPath:path]
                                        options:@{MTKTextureLoaderOptionSRGB: @NO,
                                                  MTKTextureLoaderOptionOrigin:
                                                      MTKTextureLoaderOriginTopLeft}
                                          error:&texture_error];
        if (!state->NodInfrastructureActivityAtlasTexture
            || state->NodInfrastructureActivityAtlasTexture.width != 2560
            || state->NodInfrastructureActivityAtlasTexture.height != 768) {
            NSLog(@"Tiberian Dawn HD Nod infrastructure activity atlas rejected; original animation fallback active: %@",
                  texture_error.localizedDescription);
            state->NodInfrastructureActivityAtlasTexture = nil;
        } else {
            NSLog(@"Tiberian Dawn HD Nod infrastructure activity atlas active: %lux%lu, 30 frames",
                  static_cast<unsigned long>(state->NodInfrastructureActivityAtlasTexture.width),
                  static_cast<unsigned long>(state->NodInfrastructureActivityAtlasTexture.height));
        }
    }
    if (!state->IndexTexture || !state->PaletteTexture || !state->BasePipeline || !state->CursorPipeline
        || !state->ModernCursorPipeline || !state->SelectionPipeline || !state->HDSpritePipeline
        || !state->HDBuildingPipeline
        || !state->HDSpriteShadowPipeline || !state->HealthPipeline) {
        return nullptr;
    }
    NSLog(@"Tiberian Dawn palette renderer active: %dx%d indexed Metal texture", width, height);
    return (__bridge_retained void*)state;
}

void IPad_Palette_Destroy(IPadPaletteRenderer renderer)
{
    if (renderer) (void)CFBridgingRelease(renderer);
}

bool IPad_Palette_Has_Buggy_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->BuggyAtlasTexture;
}

bool IPad_Palette_Has_Humvee_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->HumveeAtlasTexture;
}

bool IPad_Palette_Has_Minigunner_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->MinigunnerAtlasTexture;
}

bool IPad_Palette_Has_GDI_MCV_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->GDIMCVAtlasTexture;
}

bool IPad_Palette_Has_Nod_MCV_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->NodMCVAtlasTexture;
}

bool IPad_Palette_Has_GDI_Infrastructure_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->GDIInfrastructureAtlasTexture;
}

bool IPad_Palette_Has_Nod_Infrastructure_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->NodInfrastructureAtlasTexture;
}

bool IPad_Palette_Has_GDI_Infrastructure_Activity_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->GDIInfrastructureActivityAtlasTexture;
}

bool IPad_Palette_Has_Nod_Infrastructure_Activity_Artwork(IPadPaletteRenderer renderer)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    return state && state->NodInfrastructureActivityAtlasTexture;
}

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
                         IPadPaletteCursor cursor, float map_zoom, int map_right, int map_top, int view_width, int view_height, int map_bottom, IPadPaletteRect help_overlay)
{
    TiberianDawnPaletteRendererState* state = State(renderer);
    if (!state || !sdl_renderer || !indexed_pixels || indexed_pitch < state->Width || !rgb6_palette
        || viewport.width <= 0 || viewport.height <= 0) return false;

    if (indexed_pixels_changed || !state->HasIndices) {
        if (!state->HasIndices) {
            indexed_update = {0, 0, state->Width, state->Height};
        } else {
            const int left = std::max(0, indexed_update.x);
            const int top = std::max(0, indexed_update.y);
            const int right = std::min(state->Width, indexed_update.x + indexed_update.width);
            const int bottom = std::min(state->Height, indexed_update.y + indexed_update.height);
            indexed_update = {left, top, std::max(0, right - left), std::max(0, bottom - top)};
        }
        if (indexed_update.width <= 0 || indexed_update.height <= 0) return false;
        const auto* update_bytes = static_cast<const std::uint8_t*>(indexed_pixels)
                                   + indexed_update.y * indexed_pitch + indexed_update.x;
        [state->IndexTexture replaceRegion:MTLRegionMake2D(indexed_update.x,
                                                           indexed_update.y,
                                                           indexed_update.width,
                                                           indexed_update.height)
                               mipmapLevel:0
                                 withBytes:update_bytes
                               bytesPerRow:static_cast<NSUInteger>(indexed_pitch)];
        state->HasIndices = true;
    }
    if (palette_changed || !state->HasPalette) {
        std::array<std::uint8_t, 256 * 4> rgba = {};
        for (int index = 0; index < 256; ++index) {
            rgba[index * 4] = static_cast<std::uint8_t>(rgb6_palette[index * 3] << 2);
            rgba[index * 4 + 1] = static_cast<std::uint8_t>(rgb6_palette[index * 3 + 1] << 2);
            rgba[index * 4 + 2] = static_cast<std::uint8_t>(rgb6_palette[index * 3 + 2] << 2);
            rgba[index * 4 + 3] = index == 0 ? 0 : 255;
        }
        [state->PaletteTexture replaceRegion:MTLRegionMake2D(0, 0, 256, 1)
                                 mipmapLevel:0
                                   withBytes:rgba.data()
                                 bytesPerRow:256 * 4];
        state->HasPalette = true;
    }

    CAMetalLayer* layer = (__bridge CAMetalLayer*)SDL_RenderGetMetalLayer(sdl_renderer);
    id<MTLRenderCommandEncoder> encoder = (__bridge id<MTLRenderCommandEncoder>)SDL_RenderGetMetalCommandEncoder(sdl_renderer);
    if (!layer || !encoder) return false;

    const PaletteParameters parameters = {static_cast<float>(state->Width),
                                          static_cast<float>(state->Height),
                                          static_cast<float>(viewport.width),
                                          static_cast<float>(viewport.height),
                                          static_cast<std::uint32_t>(presentation_mode),
                                          static_cast<std::uint32_t>(artwork_mode)};
    const float view_size[2]={float(view_width),float(view_height)};
    [encoder setFragmentBytes:view_size length:sizeof(view_size) atIndex:2];
    const float scene[4] = {map_zoom, float(map_right), float(map_top), float(map_bottom)};
    [encoder setFragmentBytes:scene length:sizeof(scene) atIndex:1];
    SetViewport(encoder, viewport);
    SetScissor(encoder, viewport, layer);
    [encoder setRenderPipelineState:state->BasePipeline];
    [encoder setFragmentTexture:state->IndexTexture atIndex:0];
    [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
    [encoder setFragmentBytes:&parameters length:sizeof(parameters) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

    if (artwork_mode != 0 && buildings && building_count > 0) {
        // Infrastructure lives underneath mobile objects. Its atlas cells
        // contain the faction-specific power plant, barracks and yard.
        [encoder setRenderPipelineState:state->HDBuildingPipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < building_count; ++index) {
            const IPadHDBuildingOverlay& building = buildings[index];
            id<MTLTexture> infrastructure_atlas = building.faction_kind == 1
                                                       ? state->NodInfrastructureAtlasTexture
                                                       : state->GDIInfrastructureAtlasTexture;
            const bool active = building.activity_frame >= 0;
            if (active) {
                infrastructure_atlas = building.faction_kind == 1
                                           ? state->NodInfrastructureActivityAtlasTexture
                                           : state->GDIInfrastructureActivityAtlasTexture;
            }
            const int atlas_frame = active ? building.activity_frame : building.frame;
            const int columns = active ? 10 : 3;
            const int rows = active ? 3 : 1;
            const int frame_count = active ? 30 : 3;
            if (!infrastructure_atlas || atlas_frame < 0 || atlas_frame >= frame_count
                || building.destination.width <= 0 || building.destination.height <= 0) continue;
            [encoder setFragmentTexture:infrastructure_atlas atIndex:0];
            const BuildingParameters sprite_parameters = {
                static_cast<float>(columns),
                static_cast<float>(rows),
                static_cast<float>(building.destination.width),
                static_cast<float>(building.destination.height),
                static_cast<std::uint32_t>(atlas_frame),
                static_cast<std::uint32_t>(building.palette_index),
                static_cast<float>(building.completion) / 255.0f,
                static_cast<float>(building.damage) / 255.0f,
                building.repairing ? 1u : 0u,
                0u,
            };
            SetViewport(encoder, building.destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&sprite_parameters length:sizeof(sprite_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }

    if (artwork_mode != 0 && buggies && buggy_count > 0) {
        const auto vehicle_texture = [state](int atlas_kind) -> id<MTLTexture> {
            switch (atlas_kind) {
                case 1: return state->HumveeAtlasTexture;
                case 2: return state->GDIMCVAtlasTexture;
                case 3: return state->NodMCVAtlasTexture;
                default: return state->BuggyAtlasTexture;
            }
        };
        // The HD body replaces the classic sprite. Recreate its grounding
        // shadow from the body alpha before drawing the coloured components.
        [encoder setRenderPipelineState:state->HDSpriteShadowPipeline];
        for (int index = 0; index < buggy_count; ++index) {
            const IPadHDBuggyOverlay& buggy = buggies[index];
            id<MTLTexture> vehicle_atlas = vehicle_texture(buggy.atlas_kind);
            if (!vehicle_atlas) continue;
            [encoder setFragmentTexture:vehicle_atlas atIndex:0];
            const int atlas_rows = buggy.atlas_kind >= 2 ? 1 : 8;
            const int frame_count = 8 * atlas_rows;
            if (buggy.body_frame < 0 || buggy.body_frame >= frame_count
                || buggy.body_destination.width <= 0
                || buggy.body_destination.height <= 0) continue;
            IPadPaletteRect shadow_destination = buggy.body_destination;
            shadow_destination.x += std::max(1, shadow_destination.width / 12);
            shadow_destination.y += std::max(1, shadow_destination.height / 8);
            const PaletteParameters shadow_parameters = {
                8.0f,
                static_cast<float>(atlas_rows),
                static_cast<float>(shadow_destination.width),
                static_cast<float>(shadow_destination.height),
                static_cast<std::uint32_t>(buggy.body_frame),
                0,
            };
            SetViewport(encoder, shadow_destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&shadow_parameters length:sizeof(shadow_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }

        [encoder setRenderPipelineState:state->HDSpritePipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < buggy_count; ++index) {
            const IPadHDBuggyOverlay& buggy = buggies[index];
            id<MTLTexture> vehicle_atlas = vehicle_texture(buggy.atlas_kind);
            if (!vehicle_atlas) continue;
            [encoder setFragmentTexture:vehicle_atlas atIndex:0];
            const int frames[2] = {buggy.body_frame, buggy.turret_frame};
            const IPadPaletteRect destinations[2] = {buggy.body_destination, buggy.turret_destination};
            const int atlas_rows = buggy.atlas_kind >= 2 ? 1 : 8;
            const int frame_count = 8 * atlas_rows;
            for (int component = 0; component < 2; ++component) {
                if (frames[component] < 0 || frames[component] >= frame_count
                    || destinations[component].width <= 0
                    || destinations[component].height <= 0) continue;
                const PaletteParameters sprite_parameters = {
                    8.0f,
                    static_cast<float>(atlas_rows),
                    static_cast<float>(destinations[component].width),
                    static_cast<float>(destinations[component].height),
                    static_cast<std::uint32_t>(frames[component]),
                    static_cast<std::uint32_t>(buggy.palette_index),
                };
                SetViewport(encoder, destinations[component]);
                SetScissor(encoder, world_clip, layer);
                [encoder setFragmentBytes:&sprite_parameters length:sizeof(sprite_parameters) atIndex:0];
                [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            }
        }
    }

    if (artwork_mode != 0 && state->MinigunnerAtlasTexture && infantry && infantry_count > 0) {
        [encoder setRenderPipelineState:state->HDSpriteShadowPipeline];
        [encoder setFragmentTexture:state->MinigunnerAtlasTexture atIndex:0];
        for (int index = 0; index < infantry_count; ++index) {
            const IPadHDInfantryOverlay& soldier = infantry[index];
            if (soldier.frame < 0 || soldier.frame >= 80 || soldier.destination.width <= 0
                || soldier.destination.height <= 0) continue;
            IPadPaletteRect shadow_destination = soldier.destination;
            shadow_destination.x += std::max(1, shadow_destination.width / 16);
            shadow_destination.y += std::max(1, shadow_destination.height / 10);
            const PaletteParameters shadow_parameters = {
                8.0f,
                10.0f,
                static_cast<float>(shadow_destination.width),
                static_cast<float>(shadow_destination.height),
                static_cast<std::uint32_t>(soldier.frame),
                0,
            };
            SetViewport(encoder, shadow_destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&shadow_parameters length:sizeof(shadow_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }

        [encoder setRenderPipelineState:state->HDSpritePipeline];
        [encoder setFragmentTexture:state->MinigunnerAtlasTexture atIndex:0];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < infantry_count; ++index) {
            const IPadHDInfantryOverlay& soldier = infantry[index];
            if (soldier.frame < 0 || soldier.frame >= 80 || soldier.destination.width <= 0
                || soldier.destination.height <= 0) continue;
            const PaletteParameters sprite_parameters = {
                8.0f,
                10.0f,
                static_cast<float>(soldier.destination.width),
                static_cast<float>(soldier.destination.height),
                static_cast<std::uint32_t>(soldier.frame),
                static_cast<std::uint32_t>(soldier.palette_index),
            };
            SetViewport(encoder, soldier.destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&sprite_parameters length:sizeof(sprite_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }

    if (artwork_mode != 0 && selections && selection_count > 0) {
        [encoder setRenderPipelineState:state->SelectionPipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < selection_count; ++index) {
            const IPadSelectionOverlay& selection = selections[index];
            if (selection.destination.width <= 0 || selection.destination.height <= 0) continue;
            const PaletteParameters selection_parameters = {
                1.0f,
                1.0f,
                static_cast<float>(selection.destination.width),
                static_cast<float>(selection.destination.height),
                static_cast<std::uint32_t>(selection.palette_index),
                0,
            };
            SetViewport(encoder, selection.destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&selection_parameters length:sizeof(selection_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }

    // Health bars are deliberately last among world overlays so neither the
    // HD chassis nor the modern selection frame can cover their centre.
    if (artwork_mode != 0 && buildings && building_count > 0) {
        [encoder setRenderPipelineState:state->HealthPipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < building_count; ++index) {
            const IPadHDBuildingOverlay& building = buildings[index];
            if (!building.health_visible || building.health_destination.width <= 0
                || building.health_destination.height <= 0) continue;
            const PaletteParameters health_parameters = {
                static_cast<float>(building.health_fill_width),
                1.0f,
                static_cast<float>(building.health_destination.width),
                static_cast<float>(building.health_destination.height),
                static_cast<std::uint32_t>(building.health_palette_index),
                0,
            };
            SetViewport(encoder, building.health_destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&health_parameters length:sizeof(health_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }
    if (artwork_mode != 0 && buggies && buggy_count > 0) {
        [encoder setRenderPipelineState:state->HealthPipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < buggy_count; ++index) {
            const IPadHDBuggyOverlay& buggy = buggies[index];
            if (!buggy.health_visible || buggy.health_destination.width <= 0
                || buggy.health_destination.height <= 0) continue;
            const PaletteParameters health_parameters = {
                static_cast<float>(buggy.health_fill_width),
                1.0f,
                static_cast<float>(buggy.health_destination.width),
                static_cast<float>(buggy.health_destination.height),
                static_cast<std::uint32_t>(buggy.health_palette_index),
                0,
            };
            SetViewport(encoder, buggy.health_destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&health_parameters length:sizeof(health_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }
    if (artwork_mode != 0 && infantry && infantry_count > 0) {
        [encoder setRenderPipelineState:state->HealthPipeline];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        for (int index = 0; index < infantry_count; ++index) {
            const IPadHDInfantryOverlay& soldier = infantry[index];
            if (!soldier.health_visible || soldier.health_destination.width <= 0
                || soldier.health_destination.height <= 0) continue;
            const PaletteParameters health_parameters = {
                static_cast<float>(soldier.health_fill_width),
                1.0f,
                static_cast<float>(soldier.health_destination.width),
                static_cast<float>(soldier.health_destination.height),
                static_cast<std::uint32_t>(soldier.health_palette_index),
                0,
            };
            SetViewport(encoder, soldier.health_destination);
            SetScissor(encoder, world_clip, layer);
            [encoder setFragmentBytes:&health_parameters length:sizeof(health_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }

    // The indexed label was drawn last in the classic framebuffer, but HD
    // objects are composed later. Restore only its rectangle above those objects.
    if(help_overlay.width>0 && help_overlay.height>0) {
        SetViewport(encoder,viewport);SetScissor(encoder,help_overlay,layer);
        [encoder setRenderPipelineState:state->BasePipeline];
        [encoder setFragmentTexture:state->IndexTexture atIndex:0];
        [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
        [encoder setFragmentBytes:&parameters length:sizeof(parameters) atIndex:0];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    }
    if (cursor.visible && cursor.pixels && cursor.width > 0 && cursor.height > 0
        && cursor.destination.width > 0 && cursor.destination.height > 0) {
        if (!state->CursorTexture || state->CursorWidth != cursor.width || state->CursorHeight != cursor.height) {
            state->CursorTexture = MakeIndexTexture(state->Device, cursor.width, cursor.height);
            state->CursorWidth = cursor.width;
            state->CursorHeight = cursor.height;
            state->HasCursor = false;
        }
        if (state->CursorTexture && (cursor.pixels_changed || !state->HasCursor)) {
            [state->CursorTexture replaceRegion:MTLRegionMake2D(0, 0, cursor.width, cursor.height)
                                    mipmapLevel:0
                                      withBytes:cursor.pixels
                                    bytesPerRow:static_cast<NSUInteger>(cursor.pitch)];
            state->HasCursor = true;
        }
        const bool use_modern_cursor = artwork_mode != 0 && state->ModernCursorTexture && cursor.kind == 1;
        if (use_modern_cursor) {
            const double output_per_legacy_x = cursor.destination.width / static_cast<double>(cursor.width);
            const double output_per_legacy_y = cursor.destination.height / static_cast<double>(cursor.height);
            const double pointer_x = cursor.destination.x + cursor.hotspot_x * output_per_legacy_x;
            const double pointer_y = cursor.destination.y + cursor.hotspot_y * output_per_legacy_y;
            // HD cursor assets use a two-logical-pixel transparent inset so the
            // visible arrow tip remains antialiased without moving its hotspot.
            const double logical_hotspot = 2.0;
            IPadPaletteRect modern_destination = {
                static_cast<int>(std::lround(pointer_x - logical_hotspot * output_per_legacy_x)),
                static_cast<int>(std::lround(pointer_y - logical_hotspot * output_per_legacy_y)),
                std::max(1,
                         static_cast<int>(std::lround(state->ModernCursorTexture.width
                                                      / static_cast<double>(state->ModernAssetScale)
                                                      * output_per_legacy_x))),
                std::max(1,
                         static_cast<int>(std::lround(state->ModernCursorTexture.height
                                                      / static_cast<double>(state->ModernAssetScale)
                                                      * output_per_legacy_y))),
            };
            SetViewport(encoder, modern_destination);
            SetScissor(encoder, viewport, layer);
            [encoder setRenderPipelineState:state->ModernCursorPipeline];
            [encoder setFragmentTexture:state->ModernCursorTexture atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        } else if (state->HasCursor) {
            const PaletteParameters cursor_parameters = {static_cast<float>(cursor.width),
                                                         static_cast<float>(cursor.height),
                                                         static_cast<float>(cursor.destination.width),
                                                         static_cast<float>(cursor.destination.height),
                                                         2,
                                                         0};
            SetViewport(encoder, cursor.destination);
            SetScissor(encoder, viewport, layer);
            [encoder setRenderPipelineState:state->CursorPipeline];
            [encoder setFragmentTexture:state->CursorTexture atIndex:0];
            [encoder setFragmentTexture:state->PaletteTexture atIndex:1];
            [encoder setFragmentBytes:&cursor_parameters length:sizeof(cursor_parameters) atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        }
    }
    return true;
}
