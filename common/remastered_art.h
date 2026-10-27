#pragma once
#include <string>
bool RemasteredArt_Load(const std::string& directory);
bool RemasteredArt_Ready();
#ifdef __OBJC__
#import <Metal/Metal.h>
void RemasteredArt_Render(id<MTLRenderCommandEncoder> encoder, id<MTLDevice> device,
                         MTLPixelFormat format, const unsigned char* palette,
                         int screenWidth, int screenHeight, int outputX, int outputY,
                         int outputWidth, int outputHeight, float zoom,
                         int mapRight, int mapTop, int mapBottom,
                         int drawableWidth, int drawableHeight, bool healthOnly = false, int sourceWidth = 0);
#endif
