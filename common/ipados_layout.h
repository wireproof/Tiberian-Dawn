#ifndef IPADOS_LAYOUT_H
#define IPADOS_LAYOUT_H

struct IPadLayoutInsets
{
    int left;
    int top;
    int right;
    int bottom;
};

struct IPadViewport
{
    int x;
    int y;
    int width;
    int height;
};

struct IPadLayout
{
    int output_width;
    int output_height;
    int window_width;
    int window_height;
    int game_width;
    int game_height;
    IPadLayoutInsets safe_area;
    IPadViewport viewport;
    bool compact;
};

IPadLayout Calculate_IPad_Layout(int output_width,
                                 int output_height,
                                 int window_width,
                                 int window_height,
                                 int game_width,
                                 int game_height,
                                 IPadLayoutInsets safe_area,
                                 bool integer_scaling, bool fill_display = false);

void Map_IPad_Output_Point(const IPadLayout& layout, float output_x, float output_y, int& game_x, int& game_y);
void Map_IPad_Window_Point(const IPadLayout& layout, float window_x, float window_y, int& game_x, int& game_y);
void Map_IPad_Normalized_Point(const IPadLayout& layout,
                               float normalized_x,
                               float normalized_y,
                               int& game_x,
                               int& game_y);

// Converts a physical UIKit/AppKit point size into logical game pixels for the
// current fitted viewport. This keeps finger slop and hit targets ergonomic
// across Retina scale, rotation, and Stage Manager window sizes.
int IPad_Game_Pixels_For_Window_Points(const IPadLayout& layout, float points);

void Calculate_Adaptive_Game_Size(int available_width, int available_height, int& width, int& height);
void Map_Battlefield_Point(int& x, int& y, int right, int top, int view_width, int backing_width, float zoom, int sidebar_bottom = 2147483647);
void Unzoom_IPad_Battlefield_Point(int& x, int& y, int right, int top, float zoom);
#endif
