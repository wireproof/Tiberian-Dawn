#include "../common/remastered_art.mm"
#include <cassert>
#include <iostream>
// Optional private-pack integration test. argv[1] is the Resources directory
// containing separate RemasteredArt and RemasteredArtRA packs.
// Compile this file + common/remastered_scene.cpp with -fobjc-arc, C++14, and
// Foundation, Metal, MetalKit, ImageIO and CoreGraphics frameworks.
int main(int argc, char** argv){
 if(argc!=2){std::cerr << "Usage: verify_remastered_apple /path/to/Resources\n";return 2;}
 const std::string root=std::string(argv[1])+"/RemasteredArt";
 @autoreleasepool {
 RemasteredArt_SetGame(true);
 assert(RemasteredArt_Load(root));
 WPRemastered::Command c;c.asset="1TNK";c.frame=0;c.theater=0;
 assert(lookup(c)&&lookup(c)->tileset=="RA_Units");
 c.asset="CLEAR1";assert(lookup(c)&&lookup(c)->tileset=="RA_Terrain_Temperate");
 c.theater=1;assert(lookup(c)&&lookup(c)->tileset=="RA_Terrain_Snow");
 c.theater=2;assert(lookup(c)&&lookup(c)->tileset=="RA_Terrain_Interior");
 c.asset="ICON.1TNK";assert(lookup(c)&&lookup(c)->tileset=="RA_UI");
 assert(teamName(5,"")=="GERMANY");
 RemasteredArt_SetGame(false);
 assert(RemasteredArt_Load(root));
 c.asset="MTNK";c.frame=0;c.theater=1;assert(lookup(c)&&lookup(c)->tileset=="TD_Units");
 c.asset="CLEAR1";c.theater=0;assert(lookup(c)&&lookup(c)->tileset=="TD_Terrain_Desert");
 std::cout << "RA and TD pack isolation, theaters, units, icons and team selection passed\n";
}}
