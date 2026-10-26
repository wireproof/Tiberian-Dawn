#include "ipados_layout.h"

#include <algorithm>
#include <cmath>

namespace
{
int Clamp(int value, int minimum, int maximum)
{
    return std::max(minimum, std::min(value, maximum));
}

IPadViewport Fit_Viewport(int available_width,
                          int available_height,
                          int game_width,
                          int game_height,
                          bool integer_scaling)
{
    IPadViewport viewport = {0, 0, 1, 1};
    const int integer_scale = std::min(available_width / game_width, available_height / game_height);
    if (integer_scaling && integer_scale >= 1) {
        viewport.width = game_width * integer_scale;
        viewport.height = game_height * integer_scale;
        return viewport;
    }

    const double aspect = static_cast<double>(game_width) / game_height;
    viewport.width = available_width;
    viewport.height = static_cast<int>(std::floor(viewport.width / aspect + 0.5));
    if (viewport.height > available_height) {
        viewport.height = available_height;
        viewport.width = static_cast<int>(std::floor(viewport.height * aspect + 0.5));
    }
    viewport.width = Clamp(viewport.width, 1, available_width);
    viewport.height = Clamp(viewport.height, 1, available_height);
    return viewport;
}
}

IPadLayout Calculate_IPad_Layout(int output_width,
                                 int output_height,
                                 int window_width,
                                 int window_height,
                                 int game_width,
                                 int game_height,
                                 IPadLayoutInsets safe_area,
                                 bool integer_scaling, bool fill_display)
{
    IPadLayout layout = {};
    layout.output_width = std::max(1, output_width);
    layout.output_height = std::max(1, output_height);
    layout.window_width = std::max(1, window_width);
    layout.window_height = std::max(1, window_height);
    layout.game_width = std::max(1, game_width);
    layout.game_height = std::max(1, game_height);
    layout.compact = window_width < game_width || window_height < game_height;

    layout.safe_area.left = Clamp(safe_area.left, 0, layout.output_width - 1);
    layout.safe_area.top = Clamp(safe_area.top, 0, layout.output_height - 1);
    layout.safe_area.right = Clamp(safe_area.right, 0, layout.output_width - layout.safe_area.left - 1);
    layout.safe_area.bottom = Clamp(safe_area.bottom, 0, layout.output_height - layout.safe_area.top - 1);

    const int available_width = layout.output_width - layout.safe_area.left - layout.safe_area.right;
    const int available_height = layout.output_height - layout.safe_area.top - layout.safe_area.bottom;
    layout.viewport = Fit_Viewport(available_width,
                                   available_height,
                                   layout.game_width,
                                   layout.game_height,
                                   integer_scaling);
    if (fill_display) { layout.viewport.width = available_width; layout.viewport.height = available_height; }
    layout.viewport.x = layout.safe_area.left + (available_width - layout.viewport.width) / 2;
    layout.viewport.y = layout.safe_area.top + (available_height - layout.viewport.height) / 2;
    return layout;
}

void Map_IPad_Output_Point(const IPadLayout& layout, float output_x, float output_y, int& game_x, int& game_y)
{
    const float scale_x = layout.viewport.width / static_cast<float>(std::max(1, layout.game_width));
    const float scale_y = layout.viewport.height / static_cast<float>(std::max(1, layout.game_height));
    game_x = static_cast<int>((output_x - layout.viewport.x) / scale_x);
    game_y = static_cast<int>((output_y - layout.viewport.y) / scale_y);
    game_x = Clamp(game_x, 0, std::max(0, layout.game_width - 1));
    game_y = Clamp(game_y, 0, std::max(0, layout.game_height - 1));
}

void Map_IPad_Window_Point(const IPadLayout& layout, float window_x, float window_y, int& game_x, int& game_y)
{
    const float output_x = window_x * layout.output_width / static_cast<float>(std::max(1, layout.window_width));
    const float output_y = window_y * layout.output_height / static_cast<float>(std::max(1, layout.window_height));
    Map_IPad_Output_Point(layout, output_x, output_y, game_x, game_y);
}

void Map_IPad_Normalized_Point(const IPadLayout& layout,
                               float normalized_x,
                               float normalized_y,
                               int& game_x,
                               int& game_y)
{
    Map_IPad_Output_Point(layout,
                          normalized_x * layout.output_width,
                          normalized_y * layout.output_height,
                          game_x,
                          game_y);
}

int IPad_Game_Pixels_For_Window_Points(const IPadLayout& layout, float points)
{
    if (points <= 0.0f) return 0;

    const float output_per_window_x =
        layout.output_width / static_cast<float>(std::max(1, layout.window_width));
    const float output_per_window_y =
        layout.output_height / static_cast<float>(std::max(1, layout.window_height));
    const float viewport_points_w = layout.viewport.width / std::max(0.0001f, output_per_window_x);
    const float viewport_points_h = layout.viewport.height / std::max(0.0001f, output_per_window_y);
    const float game_pixels_per_point_x = layout.game_width / std::max(1.0f, viewport_points_w);
    const float game_pixels_per_point_y = layout.game_height / std::max(1.0f, viewport_points_h);
    return std::max(1,
                    static_cast<int>(std::ceil(points
                                               * std::max(game_pixels_per_point_x,
                                                          game_pixels_per_point_y))));
}
