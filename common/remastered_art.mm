#include "remastered_art.h"
#include "remastered_scene.h"
#import <MetalKit/MetalKit.h>
#import <ImageIO/ImageIO.h>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <vector>
#include <array>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <chrono>

namespace {
struct Frame {std::string tileset,asset,page;int shape=0,anim=0,x=0,y=0,w=0,h=0,cw=0,ch=0,cx=0,cy=0;float fps=0;};
std::string root;
std::unordered_map<std::string,std::vector<Frame>> frames;
std::unordered_map<std::string,std::array<float,20>> teams;
bool ready=false;
std::vector<std::string> fields(const std::string&s){std::vector<std::string>r;std::stringstream ss(s);std::string x;while(std::getline(ss,x,'\t'))r.push_back(x);return r;}
std::string key(const std::string&t,const std::string&a,int f){return t+"/"+a+"/"+std::to_string(f);}
bool safe(const std::string&s){return !s.empty()&&s[0]!='/'&&s.find("..") == std::string::npos&&s.find('\\')==std::string::npos;}
const Frame* lookup(const WPRemastered::Command& c){
 std::string asset=c.asset;for(char&x:asset)x=std::toupper((unsigned char)x);
 if(asset=="SHADOW") { char n[32];std::snprintf(n,sizeof(n),"SHADOW-%02d",c.frame);auto it=frames.find(key("TD_Terrain_Shroud",n,0));if(it!=frames.end())return &it->second[0];}
 auto dot=asset.find_last_of('.');if(dot!=std::string::npos&&asset.substr(0,5)!="ICON."&&asset.substr(0,3)!="UI.")asset.resize(dot);
 const char* terrain=c.theater==0?"TD_Terrain_Desert":c.theater==3?"TD_Terrain_Winter":"TD_Terrain_Temperate";
 const char* sets[]={terrain,"TD_Units","TD_Structures","TD_VFX","TD_UI","TD_Terrain_Shroud"};
 for(auto t:sets){auto it=frames.find(key(t,asset,c.frame));if(it==frames.end())continue;auto&v=it->second;
 auto millis=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();
 return &v[v.size()>1&&v[0].fps>0?size_t(millis*v[0].fps/1000)%v.size():0];}return nullptr;
}
const char* shader=R"METAL(
#include <metal_stdlib>
using namespace metal;
struct V{float4 position [[position]];float2 uv;};
vertex V rv(uint i [[vertex_id]]){const float2 p[]={float2(-1,1),float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,-1),float2(1,1)};const float2 u[]={float2(0,0),float2(0,1),float2(1,1),float2(0,0),float2(1,1),float2(1,0)};return {float4(p[i],0,1),u[i]};}
struct P{float a[20];uint recolor;};
float3 linearize(float3 c){return select(pow((200*c+11)/211,float3(2.4)),c*25/323,c<.04045);}
float3 srgb(float3 c){return select((pow(max(c,0),float3(5.0/12))*211-11)/200,c*323/25,c<.0031308);}
float3 hsv(float3 c){float4 K=float4(0,-1.0/3,2.0/3,-1);float4 p=c.g>=c.b?float4(c.gb,K.xy):float4(c.bg,K.wz);float4 q=c.r>=p.x?float4(c.r,p.yzx):float4(p.xyw,c.r);float d=q.x-min(q.w,q.y);return float3(abs(q.z+(q.w-q.y)/(6*d+1e-10)),d/(q.x+1e-10),q.x);}
float3 levels(float3 c,float a,float b,float z,float lo,float hi){return mix(float3(lo),float3(hi),pow(clamp((c-a)/(z-a),0.0,1.0),float3(b)));}
fragment float4 rf(V v [[stage_in]],texture2d<float> tex [[texture(0)]],constant P&p [[buffer(0)]]){
 constexpr sampler s(coord::normalized,address::clamp_to_edge,filter::linear);float4 c=tex.sample(s,v.uv);if(c.a<.001)discard_fragment();
 if(p.recolor){float3 rgb=linearize(c.rgb);float3 h=hsv(rgb);float lo=hsv(floor(float3(p.a[0],p.a[1],p.a[2])*255)/255).x;float hi=hsv(floor(float3(p.a[3],p.a[4],p.a[5])*255)/255).x;
 if(h.x>=lo&&h.x<=hi&&hi>lo){h.x=h.x/(hi-lo)*(hi-lo+2*p.a[6]);h+=float3(p.a[7],p.a[8],p.a[9]);float3 m=abs(fract(h.xxx+float3(1,2.0/3,1.0/3))*6-3);rgb=h.z*mix(float3(1),clamp(m-1,0.0,1.0),h.y);rgb=levels(rgb,p.a[10],p.a[11],p.a[12],p.a[13],p.a[14]);}
 rgb=levels(rgb,p.a[15],p.a[16],p.a[17],p.a[18],p.a[19]);c.rgb=clamp(srgb(rgb),0.0,1.0);}
 return c;
})METAL";
id<MTLRenderPipelineState> pipeline=nil;
NSCache<NSString*,id<MTLTexture>>*textures=nil;
NSCache<NSString*,id>*images=nil;
void cacheTexture(NSString*key,id<MTLTexture>t){if(t)[textures setObject:t forKey:key cost:t.width*t.height*4];}
id<MTLTexture> overlayTexture(id<MTLDevice>device,int w,int h,const std::vector<uint8_t>&rgba){
 uint64_t hash=1469598103934665603ull;for(uint8_t b:rgba){hash^=b;hash*=1099511628211ull;}
 NSString*k=[NSString stringWithFormat:@"overlay:%d:%d:%llu",w,h,(unsigned long long)hash];id<MTLTexture>t=[textures objectForKey:k];if(t)return t;
 auto*d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:w height:h mipmapped:NO];t=[device newTextureWithDescriptor:d];
 if(t){[t replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:rgba.data() bytesPerRow:w*4];cacheTexture(k,t);}return t;
}
id<MTLTexture> texture(id<MTLDevice> device,const Frame&f){
 std::string k=f.page+":"+std::to_string(f.x)+":"+std::to_string(f.y)+":"+std::to_string(f.w)+":"+std::to_string(f.h);NSString*nk=[NSString stringWithUTF8String:k.c_str()];id<MTLTexture>result=[textures objectForKey:nk];if(result)return result;
 NSString*page=[NSString stringWithUTF8String:f.page.c_str()];__attribute__((objc_precise_lifetime)) id fullOwner=[images objectForKey:page];CGImageRef full=(__bridge CGImageRef)fullOwner;
 if(!full){NSString*path=[NSString stringWithUTF8String:(root+"/"+f.page).c_str()];CGImageSourceRef src=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],nullptr);if(!src)return nil;full=CGImageSourceCreateImageAtIndex(src,0,(__bridge CFDictionaryRef)@{(id)kCGImageSourceShouldCacheImmediately:@YES});CFRelease(src);if(!full)return nil;fullOwner=CFBridgingRelease(full);[images setObject:fullOwner forKey:page cost:CGImageGetBytesPerRow(full)*CGImageGetHeight(full)];}
 if(f.x<0||f.y<0||size_t(f.x+f.w)>CGImageGetWidth(full)||size_t(f.y+f.h)>CGImageGetHeight(full))return nil;
 CGImageRef crop=CGImageCreateWithImageInRect(full,CGRectMake(f.x,f.y,f.w,f.h));if(!crop)return nil;
 MTKTextureLoader*loader=[[MTKTextureLoader alloc]initWithDevice:device];result=[loader newTextureWithCGImage:crop options:@{MTKTextureLoaderOptionSRGB:@NO} error:nil];CGImageRelease(crop);
 if(result){cacheTexture(nk,result);}return result;
}
}
bool RemasteredArt_Load(const std::string& directory){
 ready=false;frames.clear();teams.clear();root=directory;std::ifstream input(root+"/frames.tsv");if(!input)return false;std::string line;std::getline(input,line);
 try{while(std::getline(input,line)){auto f=fields(line);if(f.size()<16)continue;Frame r;r.tileset=f[0];r.asset=f[1];r.shape=std::stoi(f[2]);r.anim=std::stoi(f[3]);r.fps=std::stof(f[4]);r.page=f[6];r.x=std::stoi(f[7]);r.y=std::stoi(f[8]);r.w=std::stoi(f[9]);r.h=std::stoi(f[10]);r.cw=std::stoi(f[11]);r.ch=std::stoi(f[12]);r.cx=std::stoi(f[13]);r.cy=std::stoi(f[14]);if((r.page!="-"&&!safe(r.page))||r.w<0||r.h<0||r.cw<0||r.ch<0||r.w>4096||r.h>4096)return false;frames[key(r.tileset,r.asset,r.shape)].push_back(r);}
 std::ifstream colors(root+"/teams.tsv");std::getline(colors,line);while(std::getline(colors,line)){auto f=fields(line);if(f.size()!=21)continue;std::array<float,20>a;for(int i=0;i<20;++i)a[i]=std::stof(f[i+1]);teams[f[0]]=a;}}
 catch(...){frames.clear();return false;}
 for(auto&pair:frames)std::sort(pair.second.begin(),pair.second.end(),[](const Frame&a,const Frame&b){return a.anim<b.anim;});
 ready=!frames.empty();textures=[NSCache new];textures.totalCostLimit=192*1024*1024;images=[NSCache new];images.totalCostLimit=96*1024*1024;return ready;
}
bool RemasteredArt_Ready(){return ready;}
void RemasteredArt_Render(id<MTLRenderCommandEncoder> encoder,id<MTLDevice> device,MTLPixelFormat format,const unsigned char*palette,
 int screenWidth,int screenHeight,int ox,int oy,int ow,int oh,float zoom,int mapRight,int mapTop,int mapBottom,int dw,int dh,bool healthOnly,int sourceWidth){
 const auto&scene=WPRemastered::Shared();if(!ready||!scene.valid||screenWidth<=0||screenHeight<=0)return;
 if(!pipeline){NSError*err=nil;id<MTLLibrary>lib=[device newLibraryWithSource:[NSString stringWithUTF8String:shader] options:nil error:&err];if(!lib){NSLog(@"Remastered shader: %@",err);return;}
 MTLRenderPipelineDescriptor*d=[MTLRenderPipelineDescriptor new];d.vertexFunction=[lib newFunctionWithName:@"rv"];d.fragmentFunction=[lib newFunctionWithName:@"rf"];d.colorAttachments[0].pixelFormat=format;auto a=d.colorAttachments[0];a.blendingEnabled=YES;a.sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;a.destinationRGBBlendFactor=MTLBlendFactorOneMinusSourceAlpha;a.sourceAlphaBlendFactor=MTLBlendFactorOne;a.destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;pipeline=[device newRenderPipelineStateWithDescriptor:d error:&err];if(!pipeline){NSLog(@"Remastered pipeline: %@",err);return;}}
 // Bounded caches retain hot frames instead of clearing every texture at once.
 const float sx=float(ow)/screenWidth,sy=float(oh)/screenHeight;
 [encoder setRenderPipelineState:pipeline];
 if(!healthOnly) {
 // Draw ground first. Native scorch art extends beyond a classic cell and
 // must not be overwritten by the next cell's terrain tile.
 for(int pass=0;pass<2;++pass) for(const auto&c:scene.commands){
  bool ground=!c.shroud&&(c.kind==WPRemastered::Command::Tile||c.kind==WPRemastered::Command::Fill);
  if(ground!=(pass==0))continue;
  if(c.width<=0||c.height<=0)continue;
  const Frame*f=(!(c.flags&0x0200))?lookup(c):nullptr;
  if(f&&f->page=="-")continue;
  id<MTLTexture>tex=nil;float x=c.x,y=c.y,w=c.width,h=c.height;
  struct Params{float a[20]={};uint32_t recolor=0;}p;
  if(f){tex=texture(device,*f);if(tex){const float scale=24.0f/128.0f;
   if(c.centered){x+=(c.width-f->cw*scale)/2;y+=(c.height-f->ch*scale)/2;}
   x+=f->cx*scale;y+=f->cy*scale;w=f->w*scale;h=f->h*scale;
   std::string team=c.owner==0?"GOOD":c.owner==1?(f->tileset=="TD_Structures"?"BAD_STRUCTURE":"BAD_UNIT"):c.owner==2?"NEUTRAL":c.owner>=4&&c.owner<=9?"MULTI"+std::to_string(c.owner-3):"";
   auto t=teams.find(team);if(t!=teams.end()&&t->second[12]>t->second[10]&&t->second[17]>t->second[15]){std::copy(t->second.begin(),t->second.end(),p.a);p.recolor=1;}
  }}
  if(!tex){if(c.pixels.size()!=size_t(c.width*c.height))continue;
   std::vector<uint8_t>rgba(c.pixels.size()*4);for(size_t i=0;i<c.pixels.size();++i){unsigned v=c.pixels[i];rgba[i*4]=palette[v*3]<<2;rgba[i*4+1]=palette[v*3+1]<<2;rgba[i*4+2]=palette[v*3+2]<<2;rgba[i*4+3]=c.alpha.empty()?(v?255:0):c.alpha[i];
    if(!c.ghost.empty()&&c.ghost[v]!=255){rgba[i*4]=rgba[i*4+1]=rgba[i*4+2]=0;rgba[i*4+3]=rgba[i*4+3]?128:0;}
   }
   uint64_t hash=1469598103934665603ull;for(uint8_t b:rgba){hash^=b;hash*=1099511628211ull;}
   NSString*k=[NSString stringWithFormat:@"fallback:%d:%d:%llu",c.width,c.height,(unsigned long long)hash];tex=[textures objectForKey:k];if(!tex){
   MTLTextureDescriptor*d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:c.width height:c.height mipmapped:NO];tex=[device newTextureWithDescriptor:d];[tex replaceRegion:MTLRegionMake2D(0,0,c.width,c.height) mipmapLevel:0 withBytes:rgba.data() bytesPerRow:c.width*4];
   if(tex){cacheTexture(k,tex);}}
  }
  if(!tex)continue;
  const float tx=ox+x*zoom*sx,ty=oy+(mapTop+(y-mapTop)*zoom)*sy;
  const int left=std::max(ox,0),top=std::max(int(oy+mapTop*sy),0),right=std::min(dw,int(ox+mapRight*sx)),bottom=std::min(dh,int(oy+mapBottom*sy));
  if(right<=left||bottom<=top)continue;
  [encoder setViewport:MTLViewport{tx,ty,std::max(.1f,w*zoom*sx),std::max(.1f,h*zoom*sy),0,1}];
  [encoder setScissorRect:MTLScissorRect{NSUInteger(left),NSUInteger(top),NSUInteger(right-left),NSUInteger(bottom-top)}];
  [encoder setFragmentTexture:tex atIndex:0];[encoder setFragmentBytes:&p length:sizeof(p) atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

 }
 // Remastered chrome is independent of battlefield zoom. Hitboxes remain native.
 for(const auto&c:scene.chrome){
  WPRemastered::Command q;q.asset=c.asset;const Frame*f=lookup(q);if(!f||c.width<=0||c.height<=0)continue;
  id<MTLTexture>tex=texture(device,*f);if(!tex)continue;
  float x=c.x-(c.right&&sourceWidth>0?sourceWidth-screenWidth:0),y=c.y;
  int l=std::max(0,int(ox+x*sx)),t=std::max(0,int(oy+y*sy)),r=std::min(dw,int(ox+(x+c.width)*sx)),b=std::min(dh,int(oy+(y+c.height)*sy));if(r<=l||b<=t)continue;
  struct Params{float a[20]={};uint32_t recolor=0;}p;
  [encoder setViewport:MTLViewport{ox+x*sx,oy+y*sy,c.width*sx,c.height*sy,0,1}];[encoder setScissorRect:MTLScissorRect{NSUInteger(l),NSUInteger(t),NSUInteger(r-l),NSUInteger(b-t)}];[encoder setFragmentBytes:&p length:sizeof(p) atIndex:0];[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
  if(c.text.size()==size_t(c.width*c.height)){
   std::vector<uint8_t>rgba(c.text.size()*4,0);for(size_t i=0;i<c.text.size();++i){int v=c.text[i];int red=palette[v*3],green=palette[v*3+1],blue=palette[v*3+2];if(green>red*1.3&&green>blue*1.3&&green>12){rgba[i*4]=red<<2;rgba[i*4+1]=green<<2;rgba[i*4+2]=blue<<2;rgba[i*4+3]=255;}}
   tex=overlayTexture(device,c.width,c.height,rgba);[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
  }
 }
 // Cameos remain in the established sidebar layout. Preserve original names
 // and pixel-exact production labels; dark clock masks shade the new artwork.
 for(const auto&icon:scene.sidebar){
  WPRemastered::Command c;c.asset=icon.asset;c.frame=0;c.theater=scene.theater;const Frame*f=lookup(c);if(!f||f->page=="-")continue;
  id<MTLTexture>tex=texture(device,*f);if(!tex)continue;
  float x=icon.x-(sourceWidth>0?sourceWidth-screenWidth:0);float y=icon.y;
  int left=std::max(0,int(ox+std::max(float(mapRight),x)*sx)),top=std::max(0,int(oy+std::max(float(std::max(mapTop,icon.clip_y)),y)*sy));
  int right=std::min(dw,int(ox+(x+icon.width)*sx)),bottom=std::min(dh,int(oy+std::min(float(std::min(mapBottom,icon.clip_y+icon.clip_h)),y+icon.height)*sy));
  if(right<=left||bottom<=top)continue;
  struct Params{float a[20]={};uint32_t recolor=0;}p;
  [encoder setViewport:MTLViewport{ox+x*sx,oy+y*sy,icon.width*sx,icon.height*sy,0,1}];
  [encoder setScissorRect:MTLScissorRect{NSUInteger(left),NSUInteger(top),NSUInteger(right-left),NSUInteger(bottom-top)}];
  [encoder setFragmentBytes:&p length:sizeof(p) atIndex:0];[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
  if(icon.base.size()!=size_t(icon.width*icon.height)||icon.final.size()!=icon.base.size())continue;
  std::vector<uint8_t>rgba(icon.base.size()*4,0);
  for(size_t i=0;i<icon.base.size();++i){
   const int x=int(i%icon.width),y=int(i/icon.width);unsigned b=icon.base[i],v=icon.final[i];
   bool label=y>=icon.height-8;
   // Reconstruct the clock geometrically. Palette ghost tables are not RGB
   // opacity masks and their differences can overwrite whole cameo rows.
   double angle=std::atan2(double(x-icon.width/2),double(icon.height/2-y));if(angle<0)angle+=6.283185307;
   bool clock=icon.progress>=0 && angle>6.283185307*std::min(108,icon.progress)/108.0;
   if(icon.darken||clock)rgba[i*4+3]=150;
   // Preserve only actual label/status/queue text areas from the engine.
   if(label){rgba[i*4]=palette[b*3]<<2;rgba[i*4+1]=palette[b*3+1]<<2;rgba[i*4+2]=palette[b*3+2]<<2;rgba[i*4+3]=255;}
  }
  // Explicit text avoids treating palette ghosting as status glyphs.
  auto badge=[&](const std::string&text,int x,int y){
   const char*alphabet="0123456789+READYHOL";
   const uint8_t glyphs[][7]={{14,17,19,21,25,17,14},{4,12,4,4,4,4,14},{14,17,1,2,4,8,31},{30,1,1,14,1,1,30},{2,6,10,18,31,2,2},{31,16,16,30,1,1,30},{14,16,16,30,17,17,14},{31,1,2,4,8,8,8},{14,17,17,14,17,17,14},{14,17,17,15,1,1,14},{0,4,4,31,4,4,0},{30,17,17,30,20,18,17},{31,16,16,30,16,16,31},{14,17,17,31,17,17,17},{30,17,17,17,17,17,30},{17,17,10,4,4,4,4},{17,17,17,31,17,17,17},{14,17,17,17,17,17,14},{16,16,16,16,16,16,31}};
   for(size_t n=0;n<text.size();++n){const char*g=strchr(alphabet,text[n]);if(!g)continue;for(int yy=-1;yy<8;++yy)for(int xx=-1;xx<6;++xx){int px=x+int(n)*6+xx,py=y+yy;if(px<0||py<0||px>=icon.width||py>=icon.height)continue;size_t i=(py*icon.width+px)*4;bool on=yy>=0&&yy<7&&xx>=0&&xx<5&&(glyphs[g-alphabet][yy]&(16>>xx));rgba[i]=rgba[i+1]=rgba[i+2]=on?255:0;rgba[i+3]=255;}}
  };
  if(icon.queued>0)badge("+"+std::to_string(icon.queued),2,2);
  if(icon.status){std::string text=icon.status==1?"READY":"HOLD";badge(text,(icon.width-int(text.size())*6)/2,icon.height-18);}

  tex=overlayTexture(device,icon.width,icon.height,rgba);[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
 }
 }
 if(!healthOnly)return;
 for(const auto&bar:scene.health){
  if(bar.width<=0)continue;std::vector<uint8_t>rgba(bar.width*4*4,0);
  for(int y=0;y<4;++y)for(int x=0;x<bar.width;++x){size_t i=(y*bar.width+x)*4;rgba[i+3]=255;if(y>0&&y<3&&x>0&&x<=bar.fill){rgba[i]=palette[bar.color*3]<<2;rgba[i+1]=palette[bar.color*3+1]<<2;rgba[i+2]=palette[bar.color*3+2]<<2;}}
  id<MTLTexture>tex=overlayTexture(device,bar.width,4,rgba);
  struct Params{float a[20]={};uint32_t recolor=0;}p;
  int left=std::max(0,ox),top=std::max(0,int(oy+mapTop*sy)),right=std::min(dw,int(ox+mapRight*sx)),bottom=std::min(dh,int(oy+mapBottom*sy));if(right<=left||bottom<=top)continue;
  [encoder setViewport:MTLViewport{ox+bar.x*zoom*sx,oy+(mapTop+(bar.y-mapTop)*zoom)*sy,bar.width*zoom*sx,4*zoom*sy,0,1}];[encoder setScissorRect:MTLScissorRect{NSUInteger(left),NSUInteger(top),NSUInteger(right-left),NSUInteger(bottom-top)}];[encoder setFragmentBytes:&p length:sizeof(p) atIndex:0];[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
 }

 for(const auto&cell:scene.placement){
  unsigned char rgba[24*24*4]={};
  for(int y=0;y<24;++y)for(int x=0;x<24;++x){int i=(y*24+x)*4;rgba[i]=cell.valid?32:255;rgba[i+1]=cell.valid?255:32;rgba[i+2]=32;rgba[i+3]=(x<2||y<2||x>=22||y>=22)?220:65;}
  NSString*key=cell.valid?@"placement:valid":@"placement:invalid";id<MTLTexture>tex=[textures objectForKey:key];
  if(!tex){auto*d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:24 height:24 mipmapped:NO];tex=[device newTextureWithDescriptor:d];[tex replaceRegion:MTLRegionMake2D(0,0,24,24) mipmapLevel:0 withBytes:rgba bytesPerRow:96];cacheTexture(key,tex);}
  int left=std::max(0,ox),top=std::max(0,int(oy+mapTop*sy)),right=std::min(dw,int(ox+mapRight*sx)),bottom=std::min(dh,int(oy+mapBottom*sy));if(right<=left||bottom<=top)continue;
  struct Params{float a[20]={};uint32_t recolor=0;}p;
  [encoder setViewport:MTLViewport{ox+cell.x*zoom*sx,oy+(mapTop+(cell.y-mapTop)*zoom)*sy,24*zoom*sx,24*zoom*sy,0,1}];
  [encoder setScissorRect:MTLScissorRect{NSUInteger(left),NSUInteger(top),NSUInteger(right-left),NSUInteger(bottom-top)}];[encoder setFragmentBytes:&p length:sizeof(p) atIndex:0];[encoder setFragmentTexture:tex atIndex:0];[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
 }

}
