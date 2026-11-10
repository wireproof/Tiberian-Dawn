#import <AVFAudio/AVFAudio.h>
#import <Foundation/Foundation.h>

#include "platform/apple/ipados_platform.h"
#include "common/ipados_audio_engine.h"

static void RAInstallCommandDeck();

// The Red Alert engine is compiled independently during bring-up. Its
// immutable disc folders are read from the app bundle; saves use the separate
// vanillara user suffix.
// The combined app will choose the engine before entering either game loop.
extern "C" bool TiberianDawn_PrepareGameData(void)
{
    @autoreleasepool {
        NSURL *bundleData = [[NSBundle mainBundle] resourceURL];
        bundleData = [bundleData URLByAppendingPathComponent:@"RAData" isDirectory:YES];
        NSFileManager *files = [NSFileManager defaultManager];
        if (!bundleData) {
            NSLog(@"Red Alert bundle data directory is unavailable");
            return false;
        }
        for (NSString *name in @[@"REDALERT.MIX", @"allied/MAIN.MIX", @"soviet/MAIN.MIX"]) {
            NSURL *source = [bundleData URLByAppendingPathComponent:name];
            NSDictionary *attributes = [files attributesOfItemAtPath:source.path error:nil];
            if (![attributes[NSFileSize] respondsToSelector:@selector(unsignedLongLongValue)]
                || [attributes[NSFileSize] unsignedLongLongValue] == 0) {
                NSLog(@"Red Alert bundle asset missing: %@", name);
                return false;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{RAInstallCommandDeck();});
        NSLog(@"Red Alert bundle data is available");
        return true;
    }
}

extern "C" void TiberianDawn_ConfigureAudioSession(void)
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
}

extern "C" bool TiberianDawn_RebuildAudioEngine(void) { return IPad_Audio_Rebuild(); }
extern "C" void TiberianDawn_SetCompactWindowWarning(bool) {}

#import <UIKit/UIKit.h>
#include <SDL.h>
#include <SDL_syswm.h>
#include "common/wireproof_orders.h"
#include "common/wireproof_laptop.h"
#include "common/wireproof_camera.h"
static bool RAHasPartialHinge=false;
#include "common/wireproof_cheats.h"
#include "wireproof_controls.h"
#include "wireproof_rules.h"
extern void RA_ShowBackup();
extern void RA_ShowCloud();
#include <cmath>

// Red Alert owns separate state and preferences. Never reuse TD's rules or
// its UIKit classes: both engines live in the same Objective-C runtime.
namespace WPCheats {
Snapshot LoadPreferences() {
    Snapshot s;NSDictionary* p=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"Wireproof.RedAlert.Cheats.v1"];
    auto flag=[&](NSString* key){id v=p[key];return [v isKindOfClass:NSNumber.class] && [v boolValue];};
    s.invincible=flag(@"invincible");s.reveal=flag(@"reveal");s.instant=flag(@"instant");
    s.free=flag(@"free");s.weapons=flag(@"weapons");s.anywhere=flag(@"anywhere");s.unlock=flag(@"unlock");s.damagedHealth=flag(@"damagedHealth");
    auto speed=[&](NSString* key){id v=p[key];if(![v isKindOfClass:NSNumber.class])return 4;double n=[v doubleValue];return std::isfinite(n)&&n==std::floor(n)&&n>=1&&n<=12?(int)n:4;};
    s.infantry=speed(@"infantry");s.vehicles=speed(@"vehicles");s.aircraft=speed(@"aircraft");return s;
}
void SavePreferences(const Snapshot& s) {
    [NSUserDefaults.standardUserDefaults setObject:@{@"invincible":@(s.invincible),@"reveal":@(s.reveal),
        @"instant":@(s.instant),@"free":@(s.free),@"weapons":@(s.weapons),@"anywhere":@(s.anywhere),@"unlock":@(s.unlock),@"damagedHealth":@(s.damagedHealth),@"infantry":@(s.infantry),@"vehicles":@(s.vehicles),@"aircraft":@(s.aircraft)} forKey:@"Wireproof.RedAlert.Cheats.v1"];
}
}

@interface WPRARadar : UIView
@property(nonatomic) CGPoint previous;
@property(nonatomic) CGPoint camera;
@end
@implementation WPRARadar
- (void)drawRect:(CGRect)rect {
    auto r=WPOrders::Shared().radarSnapshot();
    [[UIColor colorWithWhite:.05 alpha:1] setFill];UIRectFill(self.bounds);
    self.accessibilityLabel=r.active?@"Radar. Drag to move map.":@"Map trackpad. Drag to pan.";
    if(!r.active || r.rgba.empty())return;
    NSData* data=[NSData dataWithBytes:r.rgba.data() length:r.rgba.size()];
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(r.width,r.height,8,32,r.width*4,color,kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);
    [[UIImage imageWithCGImage:image] drawInRect:self.bounds];
    CGImageRelease(image);CGColorSpaceRelease(color);CGDataProviderRelease(provider);
    [[UIColor whiteColor] setStroke];
    UIBezierPath* path=[UIBezierPath bezierPathWithRect:CGRectMake(r.cameraX*self.bounds.size.width/r.width,r.cameraY*self.bounds.size.height/r.height,
        r.cameraWidth*self.bounds.size.width/r.width,r.cameraHeight*self.bounds.size.height/r.height)];path.lineWidth=2;[path stroke];
}
- (void)centerRadarAt:(CGPoint)p {
    auto r=WPOrders::Shared().radarSnapshot();if(r.width<=0 || r.height<=0)return;
    if(r.active) self.camera=CGPointMake(r.mapX+p.x/self.bounds.size.width*r.width,r.mapY+p.y/self.bounds.size.height*r.height);
    else self.camera=CGPointMake(self.camera.x-(p.x-self.previous.x)*MAX(1,r.cameraWidth)*2/MAX(1,self.bounds.size.width),
        self.camera.y-(p.y-self.previous.y)*MAX(1,r.cameraHeight)*2/MAX(1,self.bounds.size.height));
    self.previous=p;
    self.camera=CGPointMake(MAX(r.mapX,MIN(r.mapX+r.width-1,self.camera.x)),MAX(r.mapY,MIN(r.mapY+r.height-1,self.camera.y)));
    WPOrders::Shared().enqueueRadarCenter(int(lround(self.camera.x)),int(lround(self.camera.y)));
}
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {
    auto r=WPOrders::Shared().radarSnapshot();self.previous=[touches.anyObject locationInView:self];
    self.camera=CGPointMake(r.mapX+r.cameraX+r.cameraWidth/2.,r.mapY+r.cameraY+r.cameraHeight/2.);
    if(r.active)[self centerRadarAt:self.previous];
}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {[self centerRadarAt:[touches.anyObject locationInView:self]];}
@end

static UIImage* RABuildCameo(NSString* asset) {
    static NSDictionary* index;static NSCache* cache;static NSCache* pages;static NSString* root;static dispatch_once_t once;
    dispatch_once(&once,^{
        root=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"RemasteredArtRA"];
        NSString* manifest=[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"frames.tsv"] encoding:NSUTF8StringEncoding error:nil];
        NSMutableDictionary* entries=[NSMutableDictionary new];
        [manifest enumerateLinesUsingBlock:^(NSString* line,BOOL*){
            if(![line hasPrefix:@"RA_UI\tICON."])return;NSArray* p=[line componentsSeparatedByString:@"\t"];
            if(p.count>=11 && [p[2] isEqual:@"0"])entries[p[1]]=@[p[6],p[7],p[8],p[9],p[10]];
        }];index=[entries copy];cache=[NSCache new];cache.countLimit=100;pages=[NSCache new];pages.countLimit=4;
    });
    NSString* key=[@"ICON." stringByAppendingString:asset.uppercaseString];UIImage* image=[cache objectForKey:key];if(image)return image;
    NSArray* e=index[key];if(!e)return nil;UIImage* page=[pages objectForKey:e[0]];
    if(!page){page=[UIImage imageWithContentsOfFile:[root stringByAppendingPathComponent:e[0]]];if(page)[pages setObject:page forKey:e[0]];}
    CGRect rect=CGRectMake([e[1] integerValue],[e[2] integerValue],[e[3] integerValue],[e[4] integerValue]);
    if(!page.CGImage || rect.origin.x<0 || rect.origin.y<0 || rect.size.width<=0 || rect.size.height<=0 || CGRectGetMaxX(rect)>CGImageGetWidth(page.CGImage) || CGRectGetMaxY(rect)>CGImageGetHeight(page.CGImage))return nil;
    CGImageRef crop=CGImageCreateWithImageInRect(page.CGImage,rect);if(!crop)return nil;
    image=[UIImage imageWithCGImage:crop];CGImageRelease(crop);[cache setObject:image forKey:key];return image;
}

// Shared SDL touch scrolling consumes this normalized stick on the game thread.
static NSMutableDictionary* RAJoystickSettings() {
    return [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"Wireproof.RedAlert.Joystick.v1"] mutableCopy]?:[NSMutableDictionary new];
}
static void RASaveJoystickSetting(bool speed,int value) {
    WPOrders::Shared().setJoystickSetting(speed,value);NSMutableDictionary* settings=RAJoystickSettings();
    settings[speed?@"speed":@"size"]=@(WPOrders::Shared().joystickSetting(speed));
    [NSUserDefaults.standardUserDefaults setObject:settings forKey:@"Wireproof.RedAlert.Joystick.v1"];
}
@interface WPRAJoystick : UIView
@property(nonatomic,strong) UILabel* arrows;
@property(nonatomic,copy) NSString* profile;
@property(nonatomic) BOOL positioning;
@property(nonatomic) CGPoint dragOffset;
- (void)refreshInWindow:(UIWindow*)window;
@end
@implementation WPRAJoystick
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.08 alpha:.7];self.layer.borderColor=[UIColor colorWithWhite:1 alpha:.45].CGColor;self.layer.borderWidth=2;
        self.accessibilityLabel=@"Pan battlefield. Hold and drag to reposition.";
        self.arrows=[UILabel new];self.arrows.text=@"✥";self.arrows.textAlignment=NSTextAlignmentCenter;
        self.arrows.textColor=UIColor.whiteColor;self.arrows.font=[UIFont systemFontOfSize:44];[self addSubview:self.arrows];
        UILongPressGestureRecognizer* move=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(reposition:)];move.minimumPressDuration=.45;[self addGestureRecognizer:move];
        NSDictionary* settings=RAJoystickSettings();for(NSString* key in @[@"size",@"speed"]){id v=settings[key];if([v isKindOfClass:NSNumber.class] && std::isfinite([v doubleValue]))WPOrders::Shared().setJoystickSetting([key isEqual:@"speed"],[v intValue]);}
    }return self;
}
- (void)refreshInWindow:(UIWindow*)window {
    if(self.positioning)return;UIEdgeInsets safe=window.safeAreaInsets;CGSize size=window.bounds.size;
    bool cover=WPCamera::CoverDisplay(size.width,size.height,safe.left,safe.top,safe.right,safe.bottom);
    self.profile=[NSString stringWithFormat:@"%@%@",cover?@"cover":@"inner",size.width>size.height?@"Landscape":@"Portrait"];
    NSDictionary* settings=RAJoystickSettings();
    auto value=[&](NSString* suffix,double fallback){id n=settings[[self.profile stringByAppendingString:suffix]];double v=[n respondsToSelector:@selector(doubleValue)]?[n doubleValue]:fallback;return std::isfinite(v)&&v>=0&&v<=1?v:fallback;};
    CGFloat diameter=WPOrders::Shared().joystickSetting(false)*24;
    CGFloat availableW=MAX(0,size.width-safe.left-safe.right-diameter),availableH=MAX(0,size.height-safe.top-safe.bottom-diameter);
    self.frame=CGRectMake(safe.left+value(@"X",.08)*availableW,safe.top+value(@"Y",.9)*availableH,diameter,diameter);
    self.layer.cornerRadius=diameter/2;self.arrows.frame=self.bounds;
}
- (void)reposition:(UILongPressGestureRecognizer*)gesture {
    UIWindow* window=self.window;if(!window)return;CGPoint point=[gesture locationInView:window];
    if(gesture.state==UIGestureRecognizerStateBegan){self.positioning=YES;self.dragOffset=CGPointMake(point.x-self.frame.origin.x,point.y-self.frame.origin.y);WPOrders::Shared().setStick(0,0);}
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged){
        UIEdgeInsets safe=window.safeAreaInsets;CGRect frame=self.frame;
        frame.origin.x=MAX(safe.left,MIN(window.bounds.size.width-safe.right-frame.size.width,point.x-self.dragOffset.x));
        frame.origin.y=MAX(safe.top,MIN(window.bounds.size.height-safe.bottom-frame.size.height,point.y-self.dragOffset.y));self.frame=frame;
    }
    if(gesture.state==UIGestureRecognizerStateEnded || gesture.state==UIGestureRecognizerStateCancelled){
        UIEdgeInsets safe=window.safeAreaInsets;NSMutableDictionary* settings=RAJoystickSettings();
        settings[[self.profile stringByAppendingString:@"X"]]=@((self.frame.origin.x-safe.left)/MAX(1,window.bounds.size.width-safe.left-safe.right-self.bounds.size.width));
        settings[[self.profile stringByAppendingString:@"Y"]]=@((self.frame.origin.y-safe.top)/MAX(1,window.bounds.size.height-safe.top-safe.bottom-self.bounds.size.height));
        [NSUserDefaults.standardUserDefaults setObject:settings forKey:@"Wireproof.RedAlert.Joystick.v1"];self.positioning=NO;
    }
}
- (void)updateStick:(NSSet<UITouch*>*)touches {
    if(self.positioning)return;CGPoint p=[touches.anyObject locationInView:self];CGFloat radius=self.bounds.size.width/2;
    WPOrders::Shared().setStick((p.x-radius)/radius,(p.y-radius)/radius);
}
- (void)touchesBegan:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {[self updateStick:touches];}
- (void)touchesMoved:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {[self updateStick:touches];}
- (void)touchesEnded:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {WPOrders::Shared().setStick(0,0);}
- (void)touchesCancelled:(NSSet<UITouch*>*)touches withEvent:(UIEvent*)event {WPOrders::Shared().setStick(0,0);}
@end

@interface WPRAToolbar : UIView
@property(nonatomic,strong) UIButton* toggle;
@property(nonatomic,strong) UISegmentedControl* tabs;
@property(nonatomic,strong) UIScrollView* content;
@property(nonatomic,strong) UILabel* title;
@property(nonatomic) BOOL expanded;
@property(nonatomic) NSInteger group;
@property(nonatomic) NSInteger buildCategory;
@property(nonatomic,copy) NSString* fingerprint;
- (void)refresh;
@end
@implementation WPRAToolbar
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithRed:.08 green:.09 blue:.11 alpha:.96];self.layer.cornerRadius=16;
        self.toggle=[UIButton buttonWithType:UIButtonTypeSystem];[self.toggle setTitle:@"RA • Command Deck" forState:UIControlStateNormal];
        self.toggle.tintColor=UIColor.whiteColor;self.toggle.titleLabel.font=[UIFont boldSystemFontOfSize:16];
        [self.toggle addTarget:self action:@selector(toggleDeck) forControlEvents:UIControlEventTouchUpInside];[self addSubview:self.toggle];
        self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"Build",@"Commands",@"Radar",@"Cheats",@"Options"]];
        self.tabs.selectedSegmentIndex=0;[self.tabs addTarget:self action:@selector(changeTab) forControlEvents:UIControlEventValueChanged];[self addSubview:self.tabs];
        self.content=[UIScrollView new];[self addSubview:self.content];self.group=1;
    }return self;
}
- (void)toggleDeck {self.expanded=!self.expanded;self.fingerprint=nil;[self refresh];}
- (void)changeTab {self.fingerprint=nil;self.content.contentOffset=CGPointZero;[self refresh];}
- (UIButton*)button:(NSString*)text y:(CGFloat)y action:(void(^)(void))action {
    UIButton* b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=CGRectMake(10,y,self.bounds.size.width-20,42);
    [b setTitle:text forState:UIControlStateNormal];b.tintColor=UIColor.whiteColor;b.backgroundColor=[UIColor colorWithWhite:.19 alpha:1];b.layer.cornerRadius=8;
    b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];b.titleLabel.adjustsFontSizeToFitWidth=YES;b.titleLabel.minimumScaleFactor=.8;
    [b addAction:[UIAction actionWithHandler:^(UIAction*){action();}] forControlEvents:UIControlEventTouchUpInside];[self.content addSubview:b];return b;
}
- (void)refresh {
    auto state=WPOrders::Shared().snapshot();self.hidden=!state.active;
    if(self.hidden){self.expanded=NO;self.fingerprint=nil;return;}
    UIWindow* window=self.window;if(!window)return;
    WPLaptop::SetPortraitWindow(window.bounds.size.height>window.bounds.size.width*1.05);
    UIEdgeInsets postureSafe=window.safeAreaInsets;
    const bool cover=WPCamera::CoverDisplay(window.bounds.size.width,window.bounds.size.height,postureSafe.left,postureSafe.top,postureSafe.right,postureSafe.bottom);
    WPLaptop::SetFoldedPortrait(RAHasPartialHinge && !cover && window.bounds.size.height>window.bounds.size.width*1.05);
    const bool dock=WPLaptop::Active();if(dock)self.expanded=YES;
    UIEdgeInsets safe=window.safeAreaInsets;CGFloat width=dock?window.bounds.size.width:MIN(430,window.bounds.size.width-safe.left-safe.right-20);
    CGFloat height=dock?window.bounds.size.height/2:self.expanded?MIN(520,window.bounds.size.height-safe.top-safe.bottom-24):44;
    self.frame=dock?CGRectMake(0,window.bounds.size.height/2,width,height):CGRectMake(window.bounds.size.width-safe.right-width-10,safe.top+10,width,height);
    self.toggle.frame=CGRectMake(0,0,width,44);self.tabs.hidden=self.content.hidden=!self.expanded;
    self.tabs.frame=CGRectMake(8,46,width-16,34);self.content.frame=CGRectMake(0,88,width,height-96-(dock?safe.bottom:0));
    if(!self.expanded)return;
    self.content.scrollEnabled=self.tabs.selectedSegmentIndex!=2;
    auto items=WPOrders::Shared().productionSnapshot();auto cheat=WPCheats::Shared().snapshot();
    NSMutableString* key=[NSMutableString stringWithFormat:@"%ld.%f.%f.%d.%d",(long)self.tabs.selectedSegmentIndex,width,height,WPLaptop::Enabled().load(),WPLaptop::AlwaysPortrait().load()];
    if(self.tabs.selectedSegmentIndex==0) {
        [key appendFormat:@"/%ld",(long)self.buildCategory];
        for(const auto& p:items)[key appendFormat:@"/%d,%d,%d,%d,%d,%d",p.type,p.id,p.progress,p.ready,p.paused,p.queued];
    } else if(self.tabs.selectedSegmentIndex==1) [key appendFormat:@"/%ld/%d/%d/%d/%d",(long)self.group,state.selected,state.force,state.rally,WPOrders::Shared().mapDrag()];
    else if(self.tabs.selectedSegmentIndex==3) [key appendFormat:@"/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d/%d",cheat.available,cheat.money,cheat.invincible,cheat.reveal,cheat.instant,cheat.free,cheat.weapons,cheat.anywhere,cheat.infantry,cheat.vehicles,cheat.aircraft];
    if(self.tabs.selectedSegmentIndex==3)[key appendFormat:@"/%d/%d",cheat.unlock,cheat.damagedHealth];
    else if(self.tabs.selectedSegmentIndex==4) [key appendFormat:@"/%d/%d/%d",state.remastered,WPOrders::Shared().joystickSetting(false),WPOrders::Shared().joystickSetting(true)];
    if([key isEqual:self.fingerprint]) {for(UIView* v in self.content.subviews)if([v isKindOfClass:WPRARadar.class])[v setNeedsDisplay];return;}
    self.fingerprint=key;for(UIView* v in self.content.subviews)[v removeFromSuperview];CGFloat y=0;
    if(self.tabs.selectedSegmentIndex==0) {
        UISegmentedControl* category=[[UISegmentedControl alloc] initWithItems:@[@"Structures",@"Infantry",@"Vehicles",@"Special"]];
        category.frame=CGRectMake(10,0,width-20,34);category.selectedSegmentIndex=self.buildCategory;
        [category addAction:[UIAction actionWithHandler:^(UIAction*){self.buildCategory=category.selectedSegmentIndex;self.fingerprint=nil;[self refresh];}] forControlEvents:UIControlEventValueChanged];[self.content addSubview:category];y=42;
        int columns=MAX(2,int((width-20)/150)),index=0;CGFloat tileWidth=(width-20-(columns-1)*8)/columns;
        for(const auto& p:items) {
            if(p.category!=self.buildCategory)continue;
            NSString* name=[NSString stringWithUTF8String:p.name.c_str()]?:@"Unit";
            NSString* status=p.ready?@"READY":p.paused?@"ON HOLD":p.queued?[NSString stringWithFormat:@"%d%% • %d queued",p.progress*100/54,p.queued]:@"";
            int type=p.type,id=p.id,category=p.category;bool ready=p.ready;
            CGFloat x=10+(index%columns)*(tileWidth+8),row=y+(index/columns)*152;
            UIButton* tile=[self button:@"" y:row action:^{if(category==3)WPOrders::Shared().enqueueSpecial(id);else WPOrders::Shared().enqueueProduction(false,type,id,category==0);if(category==0 && ready && !WPLaptop::Active()){self.expanded=NO;[self refresh];}}];
            tile.frame=CGRectMake(x,row,tileWidth,108);tile.accessibilityLabel=[name stringByAppendingFormat:@" %@",status];
            UIImage* cameo=RABuildCameo([NSString stringWithUTF8String:p.asset.c_str()]?:@"");
            UIImageView* image=[[UIImageView alloc] initWithImage:cameo?:[UIImage systemImageNamed:category==0?@"building.2":category==1?@"person.fill":category==2?@"car.fill":@"bolt.fill"]];
            image.frame=CGRectMake(4,4,tileWidth-8,60);image.contentMode=UIViewContentModeScaleAspectFit;image.tintColor=UIColor.lightGrayColor;[tile addSubview:image];
            UILabel* label=[[UILabel alloc] initWithFrame:CGRectMake(3,66,tileWidth-6,38)];label.text=[name stringByAppendingFormat:@"\n%@",status];label.numberOfLines=2;label.textAlignment=NSTextAlignmentCenter;label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];[tile addSubview:label];
            if(p.queued && category!=3){UIButton* cancel=[self button:category==0?(p.paused?@"Refund":@"Hold"):@"Cancel queue" y:row+112 action:^{WPOrders::Shared().enqueueProduction(true,type,id,category==0);}];cancel.frame=CGRectMake(x,row+112,tileWidth,32);}
            ++index;
        }
        y+=((index+columns-1)/columns)*152;
    } else if(self.tabs.selectedSegmentIndex==1) {
        NSArray* names=@[@"Stop",@"Guard area",@"Scatter",@"Force attack",@"Force move",@"Cancel action"];
        for(int i=0;i<6;++i){auto kind=(WPOrders::Kind)i;[self button:names[i] y:y action:^{WPOrders::Shared().enqueue(kind);if(kind==WPOrders::Attack || kind==WPOrders::Move){self.expanded=NO;[self refresh];}}];y+=46;}
        NSArray* rallies=@[@"Set infantry rally point",@"Set vehicle rally point",@"Clear rally points"];
        for(int i=0;i<3;++i){auto kind=(WPOrders::Kind)(WPOrders::RallyInfantry+i);[self button:rallies[i] y:y action:^{WPOrders::Shared().enqueue(kind);self.expanded=NO;[self refresh];}];y+=46;}
        UIScrollView* groups=[[UIScrollView alloc] initWithFrame:CGRectMake(10,y,width-20,48)];[self.content addSubview:groups];
        CGFloat groupWidth=MAX(44,(width-20-8*4)/9);
        for(int group=1;group<=9;++group){UIButton* button=[self button:[NSString stringWithFormat:@"%d",group] y:y action:^{self.group=group;WPOrders::Shared().enqueue(WPOrders::Recall,group);self.fingerprint=nil;[self refresh];}];[groups addSubview:button];button.frame=CGRectMake((group-1)*(groupWidth+4),0,groupWidth,44);button.backgroundColor=self.group==group?UIColor.systemRedColor:[UIColor colorWithWhite:.19 alpha:1];}groups.contentSize=CGSizeMake(9*(groupWidth+4),44);y+=50;
        for(int i=0;i<4;++i){auto kind=(WPOrders::Kind)(WPOrders::Recall+i);[self button:@[@"Recall group",@"Assign selection to group",@"Add group to selection",@"Center group"][i] y:y action:^{WPOrders::Shared().enqueue(kind,(int)self.group);}];y+=46;}
        [self button:WPOrders::Shared().mapDrag()?@"Map drag: ON":@"Map drag: OFF" y:y action:^{WPOrders::Shared().setMapDrag(!WPOrders::Shared().mapDrag());self.fingerprint=nil;[self refresh];}];y+=46;
    } else if(self.tabs.selectedSegmentIndex==2) {
        WPRARadar* radar=[[WPRARadar alloc] initWithFrame:CGRectMake(10,0,width-20,MAX(80,self.content.bounds.size.height-8))];[self.content addSubview:radar];y=radar.frame.size.height+10;
    } else if(self.tabs.selectedSegmentIndex==3) {
        if(!cheat.available){[self button:@"Cheats are single-player only" y:y action:^{}];y+=46;}
        else {
            [self button:[NSString stringWithFormat:@"Credits: %d • Add 10,000",cheat.money] y:y action:^{WPCheats::Shared().addMoney(10000);}];y+=46;
            [self button:@"Add 100 power" y:y action:^{WPCheats::Shared().addPower(100);}];y+=46;
            NSArray* names=@[@"Invincible forces",@"Reveal map",@"Instant production",@"Free production",@"Recharge available superweapons",@"Build anywhere",@"Unlock military roster",@"Damaged-building health"];
            bool values[]={cheat.invincible,cheat.reveal,cheat.instant,cheat.free,cheat.weapons,cheat.anywhere,cheat.unlock,cheat.damagedHealth};
            for(int i=0;i<8;++i){bool value=values[i];[self button:[NSString stringWithFormat:@"%@: %@",names[i],value?@"ON":@"OFF"] y:y action:^{auto& c=WPCheats::Shared();switch(i){case 0:c.invincible(!value);break;case 1:c.reveal(!value);break;case 2:c.instant(!value);break;case 3:c.free(!value);break;case 4:c.weapons(!value);break;case 5:c.anywhere(!value);break;case 6:c.unlock(!value);break;case 7:c.damagedHealth(!value);break;}}];y+=46;}
            int speeds[]={cheat.infantry,cheat.vehicles,cheat.aircraft};
            for(int i=0;i<3;++i){int current=speeds[i];[self button:[NSString stringWithFormat:@"%@ speed: %.2fx • tap to increase",@[@"Infantry",@"Vehicles / ships",@"Aircraft"][i],current/4.] y:y action:^{WPCheats::Shared().speed(i,current>=12?1:current+1);}];y+=46;}
        }
    } else {
        [self button:@"Save / Load / Game Options" y:y action:^{RA_RequestOptions();self.expanded=NO;[self refresh];}];y+=46;
        [self button:@"Back up / Import Red Alert Saves" y:y action:^{RA_ShowBackup();}];y+=46;
        [self button:@"iCloud Sync • Red Alert" y:y action:^{RA_ShowCloud();}];y+=46;
        [self button:@"Workshop • Red Alert Rules" y:y action:^{RA_ShowWorkshop();}];y+=46;
        [self button:WPLaptop::Enabled().load()?@"Laptop deck: ON":@"Laptop deck: OFF" y:y action:^{WPOrders::Shared().enqueue(WPOrders::ToggleLaptop);}];y+=46;
        [self button:WPLaptop::AlwaysPortrait().load()?@"Always portrait deck: ON":@"Always portrait deck: OFF" y:y action:^{WPOrders::Shared().enqueue(WPOrders::TogglePortraitDeck);}];y+=46;
        [self button:[NSString stringWithFormat:@"Joystick size: %d",WPOrders::Shared().joystickSetting(false)] y:y action:^{int value=WPOrders::Shared().joystickSetting(false);RASaveJoystickSetting(false,value>=8?2:value+1);}];y+=46;
        [self button:[NSString stringWithFormat:@"Joystick speed: %d",WPOrders::Shared().joystickSetting(true)] y:y action:^{int value=WPOrders::Shared().joystickSetting(true);RASaveJoystickSetting(true,value>=12?1:value+1);}];y+=46;
        [self button:@"Zoom in" y:y action:^{WPOrders::Shared().stepZoom(1);}];y+=46;
        [self button:@"Zoom out" y:y action:^{WPOrders::Shared().stepZoom(-1);}];y+=46;
        [self button:state.remastered?@"Artwork: Remastered":@"Artwork: Classic" y:y action:^{WPOrders::Shared().enqueue(WPOrders::ToggleArtwork);self.fingerprint=nil;}];y+=46;
        UILabel* help=[[UILabel alloc] initWithFrame:CGRectMake(12,y,width-24,90)];help.text=@"Red Alert uses its own save files and cheat preferences. Infantry and vehicle rally points persist for the current scenario. Hold and drag the joystick to reposition it. Workshop changes apply when starting a new game.";help.numberOfLines=0;help.textColor=UIColor.lightGrayColor;help.font=[UIFont systemFontOfSize:13];[self.content addSubview:help];y+=100;
    }
    if(self.tabs.selectedSegmentIndex==3 && cheat.available) {
        int index=0;CGFloat column=(width-28)/2;
        for(UIView* child in self.content.subviews)if([child isKindOfClass:UIButton.class]){
            child.frame=CGRectMake(10+(index%2)*(column+8),(index/2)*64,column,58);
            UIButton* button=(UIButton*)child;button.titleLabel.numberOfLines=2;button.titleLabel.textAlignment=NSTextAlignmentCenter;++index;
        }y=((index+1)/2)*64;
    }
    self.content.contentSize=CGSizeMake(width,y+8);
}
@end

static void RAInstallCommandDeck() {
    static dispatch_once_t once;dispatch_once(&once,^{
        NSTimer* timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer*){
            static WPRAToolbar* panel;static WPRAJoystick* joystick;
            SDL_Window* sdl=SDL_GetKeyboardFocus();SDL_SysWMinfo info;SDL_VERSION(&info.version);
            if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !sdl || !(SDL_GetWindowFlags(sdl)&SDL_WINDOW_SHOWN) || !SDL_GetWindowWMInfo(sdl,&info)) {panel.hidden=YES;joystick.hidden=YES;WPOrders::Shared().setStick(0,0);return;}
            UIWindow* window=info.info.uikit.window;if(!window){panel.hidden=YES;joystick.hidden=YES;WPOrders::Shared().setStick(0,0);return;}
            if(!panel){panel=[[WPRAToolbar alloc] initWithFrame:CGRectZero];
                WPLaptop::SetEnabled([NSUserDefaults.standardUserDefaults boolForKey:@"Wireproof.RedAlert.LaptopMode"]);
                WPLaptop::SetAlwaysPortrait([NSUserDefaults.standardUserDefaults boolForKey:@"Wireproof.RedAlert.PortraitDeckAlways"]);
                if(@available(iOS 27.1,*)) {
                    UIHingeInteraction* hinge=[[UIHingeInteraction alloc] initWithUpdateHandler:^(UIHingeInteraction*,UIHingeInteractionUpdate* update){RAHasPartialHinge=update.hinge && update.hinge.status==UIHingeStatusPartiallyOpen;}];[window addInteraction:hinge];
                }
            }
            if(panel.superview!=window)[window addSubview:panel];[panel refresh];
            if(!joystick)joystick=[[WPRAJoystick alloc] initWithFrame:CGRectMake(0,0,96,96)];
            if(joystick.superview!=window)[window addSubview:joystick];
            [joystick refreshInWindow:window];
            joystick.hidden=panel.hidden || panel.expanded;
        }];[[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}

void RA_SaveDeckPreferences(bool laptop,bool portrait) {
    [NSUserDefaults.standardUserDefaults setBool:laptop forKey:@"Wireproof.RedAlert.LaptopMode"];
    [NSUserDefaults.standardUserDefaults setBool:portrait forKey:@"Wireproof.RedAlert.PortraitDeckAlways"];
}

void RA_EnsureCommandDeck() {
    dispatch_async(dispatch_get_main_queue(), ^{RAInstallCommandDeck();});
}
