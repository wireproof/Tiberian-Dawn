#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "common/wireproof_orders.h"
#include "common/wireproof_camera.h"
#include "common/wireproof_cheats.h"
#include "common/wireproof_laptop.h"
#include "common/remastered_art.h"
#include "third_party/SDL2/include/SDL.h"
#include "third_party/SDL2/include/SDL_syswm.h"

// Hinge capability identifies Duo; window aspect ratio alone also matches iPads.
// Keep the positive observation during temporary hierarchy transitions (nil hinge).
static BOOL WPHasHinge=NO;
static BOOL WPHingePartiallyOpen=NO;
static void WPObserveHinge(UIView *view) {
    if (@available(iOS 27.1, *)) {
        UIHingeInteraction *interaction=[[UIHingeInteraction alloc] initWithUpdateHandler:^(UIHingeInteraction *sender, UIHingeInteractionUpdate *update) {
            if(update.hinge)WPHasHinge=YES;
            WPHingePartiallyOpen=update.hinge && update.hinge.status==UIHingeStatusPartiallyOpen;
        }];
        [view addInteraction:interaction];
    }
}
static void WPRefreshLaptopPosture(UIWindow *window) {
    CGSize size=window.bounds.size;
    UIEdgeInsets safe=window.safeAreaInsets;
    const bool cover=WPCamera::CoverDisplay(size.width,size.height,safe.left,safe.top,safe.right,safe.bottom);
    WPLaptop::SetFoldedPortrait(WPHingePartiallyOpen && !cover && size.height>size.width*1.05);
}

// Copy actual decoded MOUSE.SHP frames, using the active game palette.
static UIImage *WPAttackIcon, *WPMoveIcon;
void WP_Publish_Order_Icon(int kind, const unsigned char* rgba, int width, int height) {
    NSData *data=[NSData dataWithBytes:rgba length:width*height*4];
    dispatch_async(dispatch_get_main_queue(), ^{
        CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
        CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
        CGImageRef image=CGImageCreate(width,height,8,32,width*4,space,
            kCGBitmapByteOrderDefault|kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);
        UIImage *icon=[UIImage imageWithCGImage:image scale:1 orientation:UIImageOrientationUp];
        if (kind==0) WPAttackIcon=icon; else WPMoveIcon=icon;
        CGImageRelease(image); CGColorSpaceRelease(space); CGDataProviderRelease(provider);
    });
}

// Independent normalized positions for each display and orientation. Keep the
// old shared preference as the initial value for profiles not yet customized.
@interface WPControlPositionStore : NSObject
@property(nonatomic,copy) NSString *base;
@property(nonatomic,copy) NSString *profile;
@property(nonatomic,copy) NSString *pending;
@property(nonatomic) CFTimeInterval since;
- (CGPoint)update:(CGPoint)position window:(UIWindow*)window;
- (void)save:(CGPoint)position;
@end
@implementation WPControlPositionStore
- (CGPoint)update:(CGPoint)position window:(UIWindow*)window {
    if(!window)return position;
    CGSize size=window.bounds.size;UIEdgeInsets inset=window.safeAreaInsets;
    BOOL cover=WPCamera::CoverDisplay(size.width,size.height,inset.left,inset.top,inset.right,inset.bottom);
    NSString *key=[NSString stringWithFormat:@"%@.%@.%@",self.base,cover?@"Cover":@"Inner",size.width>size.height?@"Landscape":@"Portrait"];
    if(![key isEqualToString:self.pending]) {self.pending=key;self.since=CACurrentMediaTime();}
    if(![key isEqualToString:self.profile] && (!self.profile || CACurrentMediaTime()-self.since>=0.25)) {
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        if(self.profile)[defaults setObject:@[@(position.x),@(position.y)] forKey:self.profile];
        NSArray *saved=[defaults arrayForKey:key]?:[defaults arrayForKey:self.base];
        position=[self.base hasSuffix:@"JoystickPosition"]?CGPointMake(.15,.75):CGPointMake(0,1);
        if(saved.count==2)position=CGPointMake(MIN(1,MAX(0,[saved[0] doubleValue])),MIN(1,MAX(0,[saved[1] doubleValue])));
        self.profile=key;
    }
    return position;
}
- (void)save:(CGPoint)position {
    if(self.profile && [self.profile isEqualToString:self.pending])
        [NSUserDefaults.standardUserDefaults setObject:@[@(position.x),@(position.y)] forKey:self.profile];
}
@end

// Separate touch joystick: drag the outer ring to reposition; drag its center
// to scroll. Double tap toggles a compact persistent map-drag mode.
@interface WPMapJoystick : UIView
@property(nonatomic,strong) UIView *thumb;
@property(nonatomic,strong) UIImageView *hand;
@property(nonatomic) CGPoint position;
@property(nonatomic,strong) WPControlPositionStore *positionStore;
@property(nonatomic) BOOL repositioning;
- (void)refresh;
@end
@implementation WPMapJoystick
- (CGRect)movementRect {
    CGRect safe=CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
    if(WPLaptop::Active())safe.size.height=MAX(1,MIN(safe.size.height,self.window.bounds.size.height*.5-safe.origin.y-8));
    return safe;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.10 alpha:.90];
        self.layer.borderWidth=2;self.layer.borderColor=UIColor.grayColor.CGColor;
        self.thumb=[UIView new];self.thumb.backgroundColor=UIColor.systemBlueColor;self.thumb.layer.cornerRadius=22;self.thumb.userInteractionEnabled=NO;[self addSubview:self.thumb];
        self.hand=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"hand.draw.fill"]];self.hand.tintColor=UIColor.systemBlueColor;self.hand.contentMode=UIViewContentModeScaleAspectFit;[self addSubview:self.hand];
        self.positionStore=[WPControlPositionStore new];self.positionStore.base=@"Wireproof.JoystickPosition";
        self.position=CGPointMake(.15,.75);
        NSArray* saved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"Wireproof.JoystickPosition"];
        if(saved.count==2)self.position=CGPointMake([saved[0] doubleValue],[saved[1] doubleValue]);
        UITapGestureRecognizer* tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleMode:)];tap.numberOfTapsRequired=2;[self addGestureRecognizer:tap];
        UIPanGestureRecognizer* pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];pan.maximumNumberOfTouches=1;[self addGestureRecognizer:pan];
    }return self;
}
- (void)toggleMode:(UITapGestureRecognizer*)tap {
    WPOrders::Shared().setMapDrag(!WPOrders::Shared().mapDrag());[self refresh];
}
- (void)refresh {
    self.position=[self.positionStore update:self.position window:self.window];
    self.hidden=!WPOrders::Shared().snapshot().active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if(self.hidden){WPOrders::Shared().setStick(0,0);return;}
    BOOL compact=WPOrders::Shared().mapDrag();
    CGRect safe=[self movementRect];
    CGFloat size=MIN(compact?56:144*WPOrders::Shared().joystickSetting(false)/4.0,MIN(safe.size.width,safe.size.height));
    self.frame=CGRectMake(safe.origin.x+self.position.x*MAX(0,safe.size.width-size),safe.origin.y+self.position.y*MAX(0,safe.size.height-size),size,size);
    self.layer.cornerRadius=size/2;self.thumb.hidden=compact;self.hand.hidden=!compact;
    self.hand.frame=CGRectInset(self.bounds,14,14);self.thumb.bounds=CGRectMake(0,0,44,44);
    if(WPOrders::Shared().stick().intensity<=0)self.thumb.center=CGPointMake(size/2,size/2);
    self.accessibilityLabel=compact?@"Map drag mode. Drag this button to reposition. Double tap to restore selection.":@"Map joystick. Drag center to scroll, outer ring to reposition. Double tap for one-finger map dragging.";
}
- (void)drag:(UIPanGestureRecognizer*)pan {
    CGPoint p=[pan locationInView:self];CGFloat size=self.bounds.size.width;
    if(pan.state==UIGestureRecognizerStateBegan) {
        CGPoint delta=[pan translationInView:self];
        self.repositioning=WPOrders::Shared().mapDrag() || hypot(p.x-delta.x-size/2,p.y-delta.y-size/2)>size/2-20;
    }
    if(self.repositioning) {
        WPOrders::Shared().setStick(0,0);
        CGRect safe=[self movementRect];
        CGPoint delta=[pan translationInView:self.superview];CGFloat dx=MAX(0,safe.size.width-size),dy=MAX(0,safe.size.height-size);
        self.position=CGPointMake(dx?MIN(1,MAX(0,(self.frame.origin.x+delta.x-safe.origin.x)/dx)):0,dy?MIN(1,MAX(0,(self.frame.origin.y+delta.y-safe.origin.y)/dy)):0);
        [pan setTranslation:CGPointZero inView:self.superview];[self refresh];
    } else {
        CGFloat radius=MAX(1,size/2-28);CGFloat x=(p.x-size/2)/radius,y=(p.y-size/2)/radius;CGFloat length=hypot(x,y);
        if(length>1){x/=length;y/=length;}WPOrders::Shared().setStick(x,y);
        self.thumb.center=CGPointMake(size/2+x*radius,size/2+y*radius);
    }
    if(pan.state==UIGestureRecognizerStateEnded || pan.state==UIGestureRecognizerStateCancelled || pan.state==UIGestureRecognizerStateFailed) {
        WPOrders::Shared().setStick(0,0);[self refresh];
        if(!WPLaptop::Active())[self.positionStore save:self.position];
    }
}
- (void)didMoveToWindow { [super didMoveToWindow];if(!self.window)WPOrders::Shared().setStick(0,0); }
@end

@interface WPOrdersPanel : UIView
@property(nonatomic) NSInteger laptopPage; // 0 hidden, 1 cheats, 2 options
@property(nonatomic) BOOL laptopVertical;
@property(nonatomic) BOOL wasEmbedded;
@property(nonatomic) NSInteger layoutOrientation;
@property(nonatomic) CGSize lastWindowSize;
@property(nonatomic,strong) UISegmentedControl *tabs;
@property(nonatomic,strong) UIStackView *gamePage;
@property(nonatomic,strong) UIStackView *panelHeader;
@property(nonatomic,strong) NSArray *groupControls;
@property(nonatomic,strong) NSArray *cheatRows;
@property(nonatomic) NSInteger arrangement;
@property(nonatomic,strong) UIStackView *numberGrid;
@property(nonatomic,strong) UIStackView *modeGrid;
@property(nonatomic,strong) UIStackView *optionsPage;
@property(nonatomic,strong) UIButton *artworkButton;
@property(nonatomic,strong) UIButton *laptopButton;
@property(nonatomic,strong) UIStackView *cheatStack;
@property(nonatomic,strong) UIButton *cheatButton;
@property(nonatomic,strong) UILabel *cheatStatus;
@property(nonatomic,strong) UISwitch *invincibleSwitch;
@property(nonatomic,strong) UISwitch *instantSwitch;
@property(nonatomic,strong) UISwitch *weaponsSwitch;
@property(nonatomic,strong) UISwitch *anywhereSwitch;
@property(nonatomic,strong) UISwitch *unlockSwitch;
@property(nonatomic,strong) UISwitch *healthSwitch;
@property(nonatomic,strong) UISwitch *freeSwitch;
@property(nonatomic,strong) UISwitch *shroudSwitch;
@property(nonatomic,strong) NSArray<UISlider*> *speedSliders;
@property(nonatomic,strong) NSArray<UIStackView*> *speedButtons;
@property(nonatomic,strong) NSArray<UILabel*> *speedLabels;
@property(nonatomic) BOOL cheatsOpen;
@property(nonatomic,strong) NSArray<UISlider*> *joystickSliders;
@property(nonatomic,strong) NSArray<UILabel*> *joystickLabels;
@property(nonatomic,strong) UISlider *zoomSlider;
@property(nonatomic,strong) UILabel *zoomLabel;
@property(nonatomic,strong) UIButton *zoomMinus;
@property(nonatomic,strong) UIButton *zoomPlus;
@property(nonatomic,strong) UIStackView *stack;
@property(nonatomic,strong) UIScrollView *body;
@property(nonatomic,strong) UIButton *toggle;
@property(nonatomic,strong) UISlider *uiScaleSlider;
@property(nonatomic,strong) UILabel *uiScaleLabel;
@property(nonatomic,copy) NSString *uiScaleProfile;
@property(nonatomic,copy) NSString *pendingUIScaleProfile;
@property(nonatomic) CFTimeInterval uiScaleSince;
@property(nonatomic,copy) NSString *zoomProfile;
@property(nonatomic,copy) NSString *pendingZoomProfile;
@property(nonatomic) CFTimeInterval zoomProfileSince;
@property(nonatomic,strong) UISegmentedControl *page;
@property(nonatomic,strong) NSArray<UIButton*> *orderButtons;
@property(nonatomic,strong) NSArray<UIButton*> *groupButtons;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL configured;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic) CGPoint position;
@property(nonatomic) CGPoint laptopPosition;
@property(nonatomic,strong) WPControlPositionStore *positionStore;
@end
@implementation WPOrdersPanel
- (UIButton*)button:(NSString*)title tag:(NSInteger)tag {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal]; b.tag=tag;
    b.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    b.titleLabel.adjustsFontSizeToFitWidth=YES; b.titleLabel.minimumScaleFactor=0.75; b.titleLabel.numberOfLines=2; b.titleLabel.textAlignment=NSTextAlignmentCenter;
    b.tintColor=UIColor.whiteColor; b.backgroundColor=[UIColor colorWithWhite:0.18 alpha:0.96];
    b.layer.cornerRadius=9; b.accessibilityLabel=title;
    [b.heightAnchor constraintEqualToConstant:44].active=YES;
    [b.widthAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;
    [b addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIView*)row:(NSArray<UIView*>*)items {
    UIScrollView *scroll=[UIScrollView new]; scroll.showsHorizontalScrollIndicator=YES;
    UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:items];
    row.axis=UILayoutConstraintAxisHorizontal; row.spacing=6; row.translatesAutoresizingMaskIntoConstraints=NO;
    [scroll addSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [row.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [row.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
        [scroll.heightAnchor constraintEqualToConstant:46]]]; return scroll;
}
- (UIView*)gridRow:(NSArray<UIView*>*)items {
    UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:items];
    row.axis=UILayoutConstraintAxisHorizontal; row.spacing=6;
    row.distribution=UIStackViewDistributionFillEqually;
    return row;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        WPObserveHinge(self);
        self.backgroundColor=[UIColor colorWithWhite:0.05 alpha:0.92]; self.layer.cornerRadius=12;
        self.toggle=[self button:@"Cheats & Options ▸" tag:100];
        self.bubble=[UIButton buttonWithType:UIButtonTypeSystem];
        [self.bubble setImage:[UIImage systemImageNamed:@"slider.horizontal.3"] forState:UIControlStateNormal];
        self.bubble.tintColor=UIColor.whiteColor;
        self.bubble.accessibilityLabel=@"Tap for Cheats and Options. Drag to reposition.";
        self.bubble.tag=100;
        [self.bubble addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *handle in @[self.toggle,self.bubble]) {
            UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
            pan.maximumNumberOfTouches=1;[handle addGestureRecognizer:pan];
        }
        self.positionStore=[WPControlPositionStore new];self.positionStore.base=@"Wireproof.OrdersPosition";
        self.position=CGPointMake(0,1);
        NSArray *saved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"Wireproof.OrdersPosition"];
        if(saved.count==2)self.position=CGPointMake([saved[0] doubleValue],[saved[1] doubleValue]);
        self.laptopPosition=CGPointMake(.08,.08);
        NSArray *laptopSaved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"Wireproof.OrdersPosition.Laptop"];
        if(laptopSaved.count==2)self.laptopPosition=CGPointMake(MIN(1,MAX(0,[laptopSaved[0] doubleValue])),
                                                               MIN(1,MAX(0,[laptopSaved[1] doubleValue])));
        NSMutableArray *orders=[NSMutableArray array];
        NSArray *names=@[@"Stop",@"Guard",@"Scatter",@"Force Attack",@"Force Move",@"Cancel"];
        for (NSInteger i=0;i<names.count;i++) [orders addObject:[self button:names[i] tag:i]];
        [orders addObject:[self button:@"Infantry rally" tag:WPOrders::RallyInfantry]];
        [orders addObject:[self button:@"Vehicle rally" tag:WPOrders::RallyVehicles]];
        [orders addObject:[self button:@"Clear rallies" tag:WPOrders::ClearRallies]];
        self.orderButtons=orders;
        NSMutableArray *groups=[NSMutableArray array];
        for (NSInteger i=0;i<9;i++) {
            UIButton *b=[self button:[NSString stringWithFormat:@"%ld",(long)((i+1)%10)] tag:200+i];
            b.accessibilityLabel=[NSString stringWithFormat:@"Control group %ld",(long)((i+1)%10)];
            b.accessibilityHint=@"Tap to select. Hold to replace with current selection, or clear when nothing is selected.";
            UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(groupHeld:)];
            hold.minimumPressDuration=0.5;hold.cancelsTouchesInView=YES;[b addGestureRecognizer:hold];
            [groups addObject:b];
        }
        self.groupButtons=groups;
        self.page=[[UISegmentedControl alloc] initWithItems:@[@"Orders",@"Groups"]];
        self.page.selectedSegmentIndex=0;
        [self.page addTarget:self action:@selector(pageChanged:) forControlEvents:UIControlEventValueChanged];
        [self.page.heightAnchor constraintEqualToConstant:32].active=YES;
        NSNumber *savedZoom=[[NSUserDefaults standardUserDefaults] objectForKey:@"Wireproof.ZoomQuarters"];
        if (savedZoom) WPOrders::Shared().setZoomQuarters(savedZoom.intValue);
        self.zoomLabel=[UILabel new]; self.zoomLabel.textColor=UIColor.whiteColor;
        self.zoomLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
        self.zoomLabel.textAlignment=NSTextAlignmentCenter;
        [self.zoomLabel.heightAnchor constraintEqualToConstant:24].active=YES;
        self.zoomSlider=[UISlider new]; self.zoomSlider.minimumValue=2; self.zoomSlider.maximumValue=12;
        self.zoomSlider.value=WPOrders::Shared().zoomQuarters();
        self.zoomSlider.accessibilityLabel=@"Battlefield zoom";
        [self.zoomSlider addTarget:self action:@selector(zoomChanged:) forControlEvents:UIControlEventValueChanged];
        self.zoomMinus=[self button:@"−" tag:400]; self.zoomPlus=[self button:@"+" tag:401];
        self.zoomMinus.accessibilityLabel=@"Zoom out by 0.25"; self.zoomPlus.accessibilityLabel=@"Zoom in by 0.25";
        [self.zoomMinus.widthAnchor constraintEqualToConstant:44].active=YES;
        [self.zoomPlus.widthAnchor constraintEqualToConstant:44].active=YES;
        UIStackView *zoomRow=[[UIStackView alloc] initWithArrangedSubviews:@[self.zoomMinus,self.zoomLabel,self.zoomPlus]];
        zoomRow.axis=UILayoutConstraintAxisHorizontal; zoomRow.spacing=8;
        self.cheatButton=[self button:@"Cheats" tag:500];
        self.cheatStatus=[UILabel new];self.cheatStatus.textColor=UIColor.whiteColor;
        self.cheatStatus.font=[UIFont systemFontOfSize:12];self.cheatStatus.numberOfLines=3;
        self.invincibleSwitch=[UISwitch new];self.invincibleSwitch.tag=0;
        self.shroudSwitch=[UISwitch new];self.shroudSwitch.tag=1;
        NSMutableArray *cheatRows=[NSMutableArray arrayWithObject:self.cheatStatus];
        [cheatRows addObject:[self gridRow:@[[self button:@"+$1,000" tag:510],[self button:@"+$10,000" tag:511]]]];
        [cheatRows addObject:[self gridRow:@[[self button:@"+100 power" tag:512],[self button:@"+1,000 power" tag:513]]]];
        self.instantSwitch=[UISwitch new];self.instantSwitch.tag=2;
        self.freeSwitch=[UISwitch new];self.freeSwitch.tag=3;
        self.weaponsSwitch=[UISwitch new];self.weaponsSwitch.tag=4;
        self.anywhereSwitch=[UISwitch new];self.anywhereSwitch.tag=5;
        self.unlockSwitch=[UISwitch new];self.unlockSwitch.tag=6;
        self.healthSwitch=[UISwitch new];self.healthSwitch.tag=7;
        NSArray *switchNames=@[@"Invincibility",@"Shroud",@"Instant Build",@"Zero Cost",@"Instant Weapons",@"Build Anywhere",@"Unlock GDI + Nod",@"Damaged building health"];
        NSArray *switches=@[self.invincibleSwitch,self.shroudSwitch,self.instantSwitch,self.freeSwitch,self.weaponsSwitch,self.anywhereSwitch,self.unlockSwitch,self.healthSwitch];
        for(int i=0;i<8;++i) {
            UILabel *label=[UILabel new];label.text=switchNames[i];label.font=[UIFont systemFontOfSize:13];label.numberOfLines=2;label.textColor=UIColor.whiteColor;
            UISwitch *control=switches[i];control.accessibilityLabel=switchNames[i];
            [control addTarget:self action:@selector(cheatSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[label,control]];
            row.axis=UILayoutConstraintAxisHorizontal;row.alignment=UIStackViewAlignmentCenter;
            [row.heightAnchor constraintEqualToConstant:44].active=YES;[cheatRows addObject:row];
        }
        NSMutableArray *speedSliders=[NSMutableArray array],*speedLabels=[NSMutableArray array],*speedButtons=[NSMutableArray array];
        for(int i=0;i<3;++i) {
            UILabel *label=[UILabel new];label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:13];
            UISlider *slider=[UISlider new];slider.minimumValue=1;slider.maximumValue=12;slider.value=4;slider.tag=i;
            slider.accessibilityLabel=@[@"Infantry speed",@"Vehicle speed",@"Aircraft speed"][i];
            [slider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
            [slider.heightAnchor constraintEqualToConstant:44].active=YES;
            label.textAlignment=NSTextAlignmentCenter;label.numberOfLines=2;
            UIButton *minus=[self button:@"−" tag:800+i*2],*plus=[self button:@"+" tag:801+i*2];
            [minus.widthAnchor constraintEqualToConstant:44].active=YES;[plus.widthAnchor constraintEqualToConstant:44].active=YES;
            UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[minus,label,plus]];row.spacing=8;row.alignment=UIStackViewAlignmentCenter;
            [speedButtons addObject:row];[speedLabels addObject:label];[speedSliders addObject:slider];[cheatRows addObject:row];
        }
        self.speedSliders=speedSliders;self.speedLabels=speedLabels;self.speedButtons=speedButtons;
        UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:11];help.textColor=UIColor.lightGrayColor;
        help.text=@"Player only • Single player\nShroud on restores the earlier explored area and current unit sight. Toggles and speed are saved between missions and app launches.";
        [cheatRows addObject:help];
        self.cheatRows=cheatRows;
        NSMutableArray *cheatColumns=[NSMutableArray new];
        for(NSUInteger start=0;start<cheatRows.count;) {
            NSUInteger count=start==0?3:start==3?4:cheatRows.count-start;
            UIStackView *column=[[UIStackView alloc] initWithArrangedSubviews:[cheatRows subarrayWithRange:NSMakeRange(start,count)]];
            column.axis=UILayoutConstraintAxisVertical;column.spacing=6;[cheatColumns addObject:column];start+=count;
        }
        self.cheatStack=[[UIStackView alloc] initWithArrangedSubviews:cheatColumns];self.cheatStack.spacing=8;
        NSMutableArray *stickRows=[NSMutableArray new], *stickSliders=[NSMutableArray new], *stickLabels=[NSMutableArray new];
        for(int i=0;i<2;i++) {
            NSString *key=i?@"Wireproof.JoystickSpeed":@"Wireproof.JoystickSize";
            NSNumber *saved=[[NSUserDefaults standardUserDefaults] objectForKey:key];
            if(saved)WPOrders::Shared().setJoystickSetting(i,saved.intValue);
            UILabel *label=[UILabel new];label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:14];label.textAlignment=NSTextAlignmentCenter;
            UISlider *slider=[UISlider new];slider.minimumValue=i?1:2;slider.maximumValue=i?12:8;slider.tag=i;
            slider.accessibilityLabel=i?@"Joystick speed":@"Joystick size";
            [slider addTarget:self action:@selector(joystickChanged:) forControlEvents:UIControlEventValueChanged];
            UIButton *minus=[self button:@"−" tag:600+i*2], *plus=[self button:@"+" tag:601+i*2];
            [minus.widthAnchor constraintEqualToConstant:44].active=YES;[plus.widthAnchor constraintEqualToConstant:44].active=YES;
            UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[minus,label,plus]];row.spacing=8;
            label.numberOfLines=2;row.alignment=UIStackViewAlignmentCenter;[stickRows addObject:row];[stickSliders addObject:slider];[stickLabels addObject:label];
        }
        self.joystickSliders=stickSliders;self.joystickLabels=stickLabels;
        UIStackView *stickControls=[[UIStackView alloc] initWithArrangedSubviews:stickRows];stickControls.axis=UILayoutConstraintAxisVertical;stickControls.spacing=6;
        UIStackView *zoomControls=[[UIStackView alloc] initWithArrangedSubviews:@[zoomRow]];zoomControls.axis=UILayoutConstraintAxisVertical;zoomControls.spacing=6;
        UIStackView *sizeControls=[[UIStackView alloc] initWithArrangedSubviews:@[stickRows[0]]];sizeControls.axis=UILayoutConstraintAxisVertical;sizeControls.spacing=6;
        UIStackView *speedControls=[[UIStackView alloc] initWithArrangedSubviews:@[stickRows[1]]];speedControls.axis=UILayoutConstraintAxisVertical;speedControls.spacing=6;
        self.uiScaleLabel=[UILabel new];self.uiScaleLabel.textColor=UIColor.whiteColor;self.uiScaleLabel.font=[UIFont systemFontOfSize:14];
        self.uiScaleSlider=[UISlider new];self.uiScaleSlider.minimumValue=75;self.uiScaleSlider.maximumValue=150;
        self.uiScaleSlider.accessibilityLabel=@"UI size";
        [self.uiScaleSlider addTarget:self action:@selector(uiScaleChanged:) forControlEvents:UIControlEventValueChanged];
        UIStackView *uiButtons=[[UIStackView alloc] initWithArrangedSubviews:@[[self button:@"−" tag:700],self.uiScaleLabel,[self button:@"+" tag:701]]];uiButtons.spacing=8;uiButtons.alignment=UIStackViewAlignmentCenter;self.uiScaleLabel.textAlignment=NSTextAlignmentCenter;
        [uiButtons.arrangedSubviews.firstObject.widthAnchor constraintEqualToConstant:44].active=YES;[uiButtons.arrangedSubviews.lastObject.widthAnchor constraintEqualToConstant:44].active=YES;
        UIStackView *uiControls=[[UIStackView alloc] initWithArrangedSubviews:@[uiButtons,[self button:@"Reset UI size" tag:702]]];uiControls.axis=UILayoutConstraintAxisVertical;uiControls.spacing=6;
        self.artworkButton=[self button:@"Graphics: Original" tag:900];
        self.laptopButton=[self button:@"Laptop deck: Off" tag:901];
        UIStackView *displayControls=[[UIStackView alloc] initWithArrangedSubviews:@[self.artworkButton,self.laptopButton]];
        displayControls.axis=UILayoutConstraintAxisVertical;displayControls.spacing=6;
        self.optionsPage=[[UIStackView alloc] initWithArrangedSubviews:@[zoomControls,uiControls,sizeControls,speedControls,displayControls]];self.optionsPage.spacing=8;
        self.groupControls=groups;
        self.numberGrid=[[UIStackView alloc] initWithArrangedSubviews:@[[self gridRow:[groups subarrayWithRange:NSMakeRange(0,5)]],[self gridRow:[groups subarrayWithRange:NSMakeRange(5,4)]]]];
        self.numberGrid.spacing=6;self.numberGrid.distribution=UIStackViewDistributionFillEqually;
        UIStackView *groupColumn=[[UIStackView alloc] initWithArrangedSubviews:@[
            self.numberGrid]];
        groupColumn.axis=UILayoutConstraintAxisVertical;groupColumn.spacing=6;
        UIStackView *orderColumn=[[UIStackView alloc] initWithArrangedSubviews:@[
            [self gridRow:@[orders[0],orders[1]]],[self gridRow:@[orders[2],orders[5]]],[self gridRow:@[orders[3],orders[4]]]]];
        orderColumn.axis=UILayoutConstraintAxisVertical;orderColumn.spacing=6;
        self.gamePage=[[UIStackView alloc] initWithArrangedSubviews:@[groupColumn,orderColumn]];self.gamePage.spacing=8;
        self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"Cheats",@"Options"]];self.tabs.selectedSegmentIndex=0;
        // Explicit contrast on the dark floating panel, independent of system appearance.
        for (UISegmentedControl *control in @[self.page,self.tabs]) {
            control.selectedSegmentTintColor=UIColor.whiteColor;
            [control setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor} forState:UIControlStateNormal];
            [control setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor} forState:UIControlStateSelected];
        }
        [self.tabs.heightAnchor constraintEqualToConstant:36].active=YES;
        [self.tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
        self.panelHeader=[[UIStackView alloc] initWithArrangedSubviews:@[self.toggle,self.tabs]];self.panelHeader.spacing=6;self.panelHeader.alignment=UIStackViewAlignmentFill;
        self.stack=[[UIStackView alloc] initWithArrangedSubviews:@[self.panelHeader,self.gamePage,self.cheatStack,self.optionsPage]];
        self.stack.axis=UILayoutConstraintAxisVertical; self.stack.spacing=6;
        self.stack.translatesAutoresizingMaskIntoConstraints=YES;
        self.body=[UIScrollView new]; self.body.alwaysBounceVertical=NO;
        [self.body addSubview:self.stack]; [self addSubview:self.body];

        [self addSubview:self.bubble];
    } return self;
}
- (void)drag:(UIPanGestureRecognizer*)pan {
    CGRect safe=[self availableRect];
    CGPoint delta=[pan translationInView:self.superview];
    CGFloat dx=MAX(0,safe.size.width-self.bounds.size.width);
    CGFloat dy=MAX(0,safe.size.height-self.bounds.size.height);
    CGPoint position=CGPointMake(dx?MIN(1,MAX(0,(self.frame.origin.x+delta.x-safe.origin.x)/dx)):0,
                                 dy?MIN(1,MAX(0,(self.frame.origin.y+delta.y-safe.origin.y)/dy)):0);
    if(WPLaptop::Active())self.laptopPosition=position;else self.position=position;
    [pan setTranslation:CGPointZero inView:self.superview];[self refresh];
    if(pan.state==UIGestureRecognizerStateEnded) {
        if(WPLaptop::Active())
            [NSUserDefaults.standardUserDefaults setObject:@[@(self.laptopPosition.x),@(self.laptopPosition.y)]
                                              forKey:@"Wireproof.OrdersPosition.Laptop"];
        else [self.positionStore save:self.position];
    }
}
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (!self.window) {WPOrders::Shared().hold_pan(false);WPOrders::Shared().setStick(0,0);}
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidHideNotification object:nil];
    if (self.window) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardClosed:)
        name:UIKeyboardDidHideNotification object:nil];
}
- (void)dealloc { WPOrders::Shared().setStick(0,0);WPOrders::Shared().hold_pan(false); [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)keyboardClosed:(NSNotification*)notification {
    // Keyboard animations may replace/reorder the window's root content. Keep
    // our overlay above it and clear any cancelled drag from the transition.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.window) return;
        [self.layer removeAllAnimations];
        for (UIView *handle in @[self.toggle,self.bubble]) {
            [handle.layer removeAllAnimations];
            for (UIGestureRecognizer *gesture in handle.gestureRecognizers) {
                gesture.enabled=NO; gesture.enabled=YES;
            }
            handle.userInteractionEnabled=YES;
        }
        self.userInteractionEnabled=YES;
        [self refresh];
        [self.superview bringSubviewToFront:self];
    });
}
- (CGRect)availableRect {
    return CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
}
- (void)cheatSwitchChanged:(UISwitch*)control {
    if(control.tag==0)WPCheats::Shared().invincible(control.on);
    else if(control.tag==1)WPCheats::Shared().reveal(!control.on);
    else if(control.tag==2)WPCheats::Shared().instant(control.on);
    else if(control.tag==3)WPCheats::Shared().free(control.on);
    else if(control.tag==4)WPCheats::Shared().weapons(control.on);
    else if(control.tag==5)WPCheats::Shared().anywhere(control.on);
    else if(control.tag==6)WPCheats::Shared().unlock(control.on);
    else WPCheats::Shared().damagedHealth(control.on);
    [self refresh];
}
- (void)speedChanged:(UISlider*)slider {
    WPCheats::Shared().speed((int)slider.tag,(int)lroundf(slider.value));[self refresh];
}
- (void)tabChanged:(UISegmentedControl*)tabs { self.body.contentOffset=CGPointZero;[self refresh]; }
- (void)joystickChanged:(UISlider*)slider {
    WPOrders::Shared().setJoystickSetting(slider.tag,(int)lroundf(slider.value));
    [[NSUserDefaults standardUserDefaults] setInteger:WPOrders::Shared().joystickSetting(slider.tag) forKey:[NSString stringWithFormat:@"Wireproof.Joystick.%@.%@",self.zoomProfile.pathExtension?:@"Standard",slider.tag?@"Speed":@"Size"]];
    [self refresh];
}
- (void)groupHeld:(UILongPressGestureRecognizer*)gesture {
    if(gesture.state!=UIGestureRecognizerStateBegan)return;
    if(WPOrders::Shared().enqueue(WPOrders::Assign,(int)gesture.view.tag-200)) {
        UISelectionFeedbackGenerator *feedback=[UISelectionFeedbackGenerator new];[feedback selectionChanged];
    }
}
- (void)uiScaleChanged:(UISlider*)slider {
    WPOrders::Shared().setUIScale((int)lroundf(slider.value/5)*5);
    if(self.uiScaleProfile)[NSUserDefaults.standardUserDefaults setInteger:WPOrders::Shared().uiScale() forKey:self.uiScaleProfile];
    [self refresh];
}
- (void)saveZoom {
    int quarters=WPOrders::Shared().zoomQuarters();
    [[NSUserDefaults standardUserDefaults] setInteger:quarters forKey:self.zoomProfile?:@"Wireproof.ZoomQuarters"];
    self.zoomSlider.value=quarters;
    [self refresh];
}
- (void)zoomChanged:(UISlider*)slider {
    WPOrders::Shared().setZoomQuarters((int)lroundf(slider.value));
    [self saveZoom];
}
- (void)pressed:(UIButton*)button {
    if(button.tag==900 || button.tag==901) {
        WPOrders::Shared().enqueue(button.tag==900?WPOrders::ToggleArtwork:WPOrders::ToggleLaptop);
        return;
    }
    if(button.tag>=800 && button.tag<=805){UISlider *value=self.speedSliders[(button.tag-800)/2];value.value+=(button.tag%2?1:-1);[self speedChanged:value];return;}
    if(button.tag>=700 && button.tag<=702){self.uiScaleSlider.value=button.tag==702?100:WPOrders::Shared().uiScale()+(button.tag==700?-5:5);[self uiScaleChanged:self.uiScaleSlider];return;}
    if(button.tag>=600 && button.tag<=603) {
        UISlider *slider=self.joystickSliders[(button.tag-600)/2];slider.value=WPOrders::Shared().joystickSetting(slider.tag)+(button.tag%2?1:-1);[self joystickChanged:slider];return;
    }
    if(button.tag==500){self.cheatsOpen=!self.cheatsOpen;[self refresh];return;}
    if(button.tag>=510&&button.tag<=513){
        if(button.tag<512)WPCheats::Shared().addMoney(button.tag==510?1000:10000);
        else WPCheats::Shared().addPower(button.tag==512?100:1000);
        return;
    }
    if (button.tag==400 || button.tag==401) {
        WPOrders::Shared().stepZoom(button.tag==400?-1:1); [self saveZoom]; return;
    }
    if (button.tag==100) { self.expanded=!self.expanded; [self refresh]; return; }
    if (button.tag>=200) {
        WPOrders::Shared().enqueue(WPOrders::Recall,(int)button.tag-200);
    } else WPOrders::Shared().enqueue((WPOrders::Kind)button.tag);
}
- (void)refresh {
    self.position=[self.positionStore update:self.position window:self.window];
    if(self.window) {
        CGSize size=self.window.bounds.size;
        UIEdgeInsets insets=self.window.safeAreaInsets;
        BOOL cover=WPCamera::CoverDisplay(size.width,size.height,insets.left,insets.top,insets.right,insets.bottom);
        NSString *legacy=cover?@"Wireproof.Zoom.Cover":@"Wireproof.Zoom.Inner";
        NSString *profile=WPHasHinge?legacy:@"Wireproof.Zoom.Standard";
        NSString *scaleProfile=[NSString stringWithFormat:@"Wireproof.UIScale.%@.%@",WPHasHinge?(cover?@"Cover":@"Inner"):@"Standard",size.width>size.height?@"Landscape":@"Portrait"];
        if(![scaleProfile isEqualToString:self.pendingUIScaleProfile]){self.pendingUIScaleProfile=scaleProfile;self.uiScaleSince=CACurrentMediaTime();}
        if(![scaleProfile isEqualToString:self.uiScaleProfile] && (!self.uiScaleProfile || CACurrentMediaTime()-self.uiScaleSince>=0.25)){
            NSNumber *saved=[NSUserDefaults.standardUserDefaults objectForKey:scaleProfile];
            WPOrders::Shared().setUIScale(saved?saved.intValue:100);self.uiScaleProfile=scaleProfile;
        }
        self.uiScaleSlider.value=WPOrders::Shared().uiScale();
        self.uiScaleLabel.text=[NSString stringWithFormat:@"UI size %d%%",WPOrders::Shared().uiScale()];
        self.uiScaleSlider.accessibilityValue=self.uiScaleLabel.text;
        if(![profile isEqualToString:self.pendingZoomProfile]) {
            self.pendingZoomProfile=profile;self.zoomProfileSince=CACurrentMediaTime();
        }
        // Fold/rotation geometry settles over multiple callbacks. Never save a
        // transient intermediate frame into the other display's preferences.
        if(![profile isEqualToString:self.zoomProfile] && (!self.zoomProfile || CACurrentMediaTime()-self.zoomProfileSince>=0.25)) {
            NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
            if(self.zoomProfile)[defaults setInteger:WPOrders::Shared().zoomQuarters() forKey:self.zoomProfile];
            NSNumber *saved=[defaults objectForKey:profile]?:[defaults objectForKey:legacy]?:[defaults objectForKey:@"Wireproof.ZoomQuarters"];
            WPOrders::Shared().setZoomQuarters(saved?saved.intValue:6);
            for(int i=0;i<2;i++) {
                NSString *component=i?@"Speed":@"Size";
                if(self.zoomProfile)[defaults setInteger:WPOrders::Shared().joystickSetting(i) forKey:[NSString stringWithFormat:@"Wireproof.Joystick.%@.%@",self.zoomProfile.pathExtension,component]];
                NSString *key=[NSString stringWithFormat:@"Wireproof.Joystick.%@.%@",profile.pathExtension,component];
                NSNumber *value=[defaults objectForKey:key]?:[defaults objectForKey:i?@"Wireproof.JoystickSpeed":@"Wireproof.JoystickSize"];
                WPOrders::Shared().setJoystickSetting(i,value?value.intValue:4);
                [defaults setInteger:WPOrders::Shared().joystickSetting(i) forKey:key];
            }
            self.zoomProfile=profile;
        }
    }
    // Pinch updates the shared zoom on the SDL thread; persist the settled profile.
    if(self.zoomProfile && [self.zoomProfile isEqual:self.pendingZoomProfile])
        [NSUserDefaults.standardUserDefaults setInteger:WPOrders::Shared().zoomQuarters() forKey:self.zoomProfile];
    auto s=WPOrders::Shared().snapshot();
    [self.artworkButton setTitle:s.remastered?@"Graphics: Remastered":@"Graphics: Original" forState:UIControlStateNormal];
    [self.laptopButton setTitle:WPLaptop::Enabled().load()?@"Laptop deck: On":@"Laptop deck: Off" forState:UIControlStateNormal];
    auto cheats=WPCheats::Shared().snapshot();
    self.gamePage.hidden=YES;
    BOOL embedded=WPLaptop::Active() && self.laptopPage>0;
    if(self.wasEmbedded && !embedded)self.expanded=NO;
    self.wasEmbedded=embedded;
    NSInteger selected=embedded?self.laptopPage-1:self.tabs.selectedSegmentIndex;
    self.cheatStack.hidden=selected!=0;
    self.optionsPage.hidden=selected!=1;
    self.cheatStack.userInteractionEnabled=cheats.available;
    self.cheatStatus.text=[NSString stringWithFormat:@"Credits: %d\nPower: %d / %d",cheats.money,cheats.power,cheats.drain];
    self.weaponsSwitch.on=cheats.weapons;self.anywhereSwitch.on=cheats.anywhere;self.unlockSwitch.on=cheats.unlock;self.healthSwitch.on=cheats.damagedHealth;
    self.instantSwitch.on=cheats.instant;self.freeSwitch.on=cheats.free;
    self.invincibleSwitch.on=cheats.invincible;self.shroudSwitch.on=!cheats.reveal;
    int speeds[]={cheats.infantry,cheats.vehicles,cheats.aircraft};
    for(int i=0;i<3;++i){self.speedSliders[i].value=speeds[i];self.speedLabels[i].text=[NSString stringWithFormat:@"%@: %.2f×",@[@"Infantry",@"Vehicles",@"Aircraft"][i],speeds[i]/4.0];}

    int quarters=WPOrders::Shared().zoomQuarters();
    for(int i=0;i<2;i++){int value=WPOrders::Shared().joystickSetting(i);self.joystickSliders[i].value=value;self.joystickLabels[i].text=[NSString stringWithFormat:@"Joystick %@ %.2f×",i?@"speed":@"size",value/4.0];}
    NSString *zoomTitle=WPHasHinge?([self.zoomProfile hasSuffix:@"Cover"]?@"Cover zoom":@"Inner zoom"):@"Zoom";
    self.zoomLabel.text=[NSString stringWithFormat:@"%@ %.2f×",zoomTitle,quarters/4.0];
    self.zoomSlider.value=quarters; self.zoomSlider.accessibilityValue=self.zoomLabel.text;
    self.zoomMinus.enabled=quarters>2; self.zoomPlus.enabled=quarters<12;
    self.hidden=!s.active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || (WPLaptop::Active() && !embedded);
    if (self.hidden) {WPOrders::Shared().hold_pan(false);WPOrders::Shared().setStick(0,0);}
    if(self.window) {
        NSInteger orientation=self.window.windowScene.interfaceOrientation;
        if(!orientation)orientation=self.window.bounds.size.width>self.window.bounds.size.height?UIInterfaceOrientationLandscapeLeft:UIInterfaceOrientationPortrait;
        CGSize size=self.window.bounds.size;
        BOOL resized=self.lastWindowSize.width>0 && (fabs(size.width-self.lastWindowSize.width)>0.5 || fabs(size.height-self.lastWindowSize.height)>0.5);
        if(!embedded && ((self.layoutOrientation && self.layoutOrientation!=orientation) || resized))self.expanded=NO;
        self.lastWindowSize=size;
        self.layoutOrientation=orientation;
    }
    if (!self.configured && self.window) { self.expanded=NO; self.configured=YES; }
    if(embedded)self.expanded=YES;
    NSString *title=[NSString stringWithFormat:@"Cheats & Options %@",self.expanded?@"▾":@"▸"];
    [self.toggle setTitle:title forState:UIControlStateNormal];
    self.panelHeader.hidden=embedded;
    self.body.hidden=!self.expanded; self.stack.hidden=!self.expanded; self.bubble.hidden=self.expanded || embedded;
    BOOL panHeld=WPOrders::Shared().panHeld();
    self.bubble.tintColor=panHeld?UIColor.systemBlueColor:(s.force?UIColor.systemOrangeColor:UIColor.whiteColor);
    [self.bubble setImage:[UIImage systemImageNamed:panHeld?@"hand.draw.fill":@"slider.horizontal.3"] forState:UIControlStateNormal];
    self.layer.cornerRadius=self.expanded?12:28;
    CGRect safe=[self availableRect];
    BOOL landscape=self.window.bounds.size.width>self.window.bounds.size.height && !(embedded && self.laptopVertical);
    if(self.arrangement!=(landscape?2:1)) {
        self.arrangement=landscape?2:1;
        for(UIStackView *page in @[self.gamePage,self.cheatStack])for(UIView *v in [page.arrangedSubviews copy]){[page removeArrangedSubview:v];[v removeFromSuperview];}
        NSArray *o=self.orderButtons;
        if(landscape) {
            [self.gamePage addArrangedSubview:[self gridRow:self.groupControls]];
            [self.gamePage addArrangedSubview:[self gridRow:@[o[0],o[1],o[2],o[5],o[3],o[4]]]];
            UIStackView *switchGrid=[[UIStackView alloc] initWithArrangedSubviews:@[
                [self gridRow:@[self.cheatRows[3],self.cheatRows[4]]],
                [self gridRow:@[self.cheatRows[5],self.cheatRows[6]]],
                [self gridRow:@[self.cheatRows[7],self.cheatRows[8]]],[self gridRow:@[self.cheatRows[9],self.cheatRows[10]]]]];
            switchGrid.axis=UILayoutConstraintAxisVertical;switchGrid.spacing=6;
            UIStackView *resources=[[UIStackView alloc] initWithArrangedSubviews:@[self.cheatRows[1],self.cheatRows[2]]];
            resources.axis=UILayoutConstraintAxisVertical;resources.spacing=6;
            UIStackView *top=[[UIStackView alloc] initWithArrangedSubviews:@[switchGrid,self.cheatStatus,resources]];
            top.axis=UILayoutConstraintAxisHorizontal;top.spacing=12;top.alignment=UIStackViewAlignmentCenter;
            [switchGrid.widthAnchor constraintEqualToAnchor:resources.widthAnchor].active=YES;
            [self.cheatStatus setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
            [self.cheatStack addArrangedSubview:top];
            [self.cheatStack addArrangedSubview:[self gridRow:self.speedButtons]];
        } else {
            UIStackView *left=[[UIStackView alloc] initWithArrangedSubviews:[self.groupControls subarrayWithRange:NSMakeRange(0,5)]],*right=[[UIStackView alloc] initWithArrangedSubviews:[self.groupControls subarrayWithRange:NSMakeRange(5,4)]];left.axis=right.axis=UILayoutConstraintAxisVertical;left.spacing=right.spacing=6;
            UIStackView *numbers=(UIStackView*)[self gridRow:@[left,right]];numbers.alignment=UIStackViewAlignmentTop;[self.gamePage addArrangedSubview:numbers];
            for(NSArray *row in @[@[o[0],o[1]],@[o[2],o[5]],@[o[3],o[4]]])[self.gamePage addArrangedSubview:[self gridRow:row]];
            for(UIView *v in self.cheatRows)[self.cheatStack addArrangedSubview:v];
        }
        [self.gamePage addArrangedSubview:[self gridRow:@[o[6],o[7],o[8]]]];
    }
    self.panelHeader.axis=landscape?UILayoutConstraintAxisHorizontal:UILayoutConstraintAxisVertical;
    self.panelHeader.distribution=landscape?UIStackViewDistributionFillEqually:UIStackViewDistributionFill;
    self.panelHeader.alignment=landscape?UIStackViewAlignmentCenter:UIStackViewAlignmentFill;
    for(UIStackView *page in @[self.gamePage,self.cheatStack]){page.axis=UILayoutConstraintAxisVertical;page.distribution=UIStackViewDistributionFill;page.alignment=UIStackViewAlignmentFill;}
    const BOOL wideOptions=landscape && safe.size.width>=800;
    self.optionsPage.axis=wideOptions?UILayoutConstraintAxisHorizontal:UILayoutConstraintAxisVertical;
    self.optionsPage.distribution=wideOptions?UIStackViewDistributionFillEqually:UIStackViewDistributionFill;
    self.optionsPage.alignment=wideOptions?UIStackViewAlignmentTop:UIStackViewAlignmentFill;
    const CGFloat uiScale=1.0; // Floating controls have their own fixed touch-target size.
    CGFloat width=embedded?MAX(56,self.window.bounds.size.width-2*safe.origin.x):
        self.expanded?MIN(landscape?(selected==1?1000:820):256,MAX(56,safe.size.width/uiScale)):56;
    CGFloat height=56;
    __block CGFloat contentHeight=56;
    if (self.expanded) {
        CGSize fit=[self.stack systemLayoutSizeFittingSize:CGSizeMake(width-12,0)
            withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        contentHeight=fit.height;
        height=MIN(safe.size.height/uiScale,fit.height+12);
    }
    if(embedded)height=MAX(60,self.window.bounds.size.height*.5-MAX(70,self.window.safeAreaInsets.bottom+62)-114);
    CGPoint position=WPLaptop::Active()?self.laptopPosition:self.position;
    CGFloat x=safe.origin.x+position.x*MAX(0,safe.size.width-width*uiScale);
    CGFloat y=safe.origin.y+position.y*MAX(0,safe.size.height-height*uiScale);
    if(embedded){x=safe.origin.x;y=ceil(self.window.bounds.size.height*.5)+114;}
    [UIView performWithoutAnimation:^{
        self.bounds=CGRectMake(0,0,width,height);
        self.transform=CGAffineTransformMakeScale(uiScale,uiScale);
        self.center=CGPointMake(x+width*uiScale/2,y+height*uiScale/2);
        self.bubble.frame=self.bounds;
        if (self.expanded) {
            self.body.frame=CGRectInset(self.bounds,6,6);
            self.stack.frame=CGRectMake(0,0,width-12,contentHeight);
            self.body.contentSize=CGSizeMake(width-12,contentHeight);
        }
        [self layoutIfNeeded];
    }];
    for (UIButton *b in self.orderButtons) {
        UIImage *icon=b.tag==WPOrders::Attack?WPAttackIcon:b.tag==WPOrders::Move?WPMoveIcon:nil;
        if (icon && b.currentImage!=icon) {
            [b setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
            b.imageView.layer.magnificationFilter=kCAFilterNearest;
            b.imageEdgeInsets=UIEdgeInsetsMake(0,0,0,6);
        }
        b.enabled=b.tag==WPOrders::Cancel || b.tag>=WPOrders::RallyInfantry || s.selected>0;
        b.alpha=b.enabled?1:0.4;
        b.backgroundColor=((b.tag==WPOrders::Attack && s.force==1)||(b.tag==WPOrders::Move && s.force==2))?UIColor.systemBlueColor:[UIColor colorWithWhite:0.18 alpha:0.96];
    }

}
@end

// Game commands live in their own movable panel. Cheats and display options
// remain in WPOrdersPanel, so opening either panel never hides the other.
@interface WPGameToolbar : UIView
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UIButton *header;
@property(nonatomic,strong) UIButton *orientationButton;
@property(nonatomic,strong) UIScrollView *body;
@property(nonatomic,strong) NSArray<UIButton*> *commands;
@property(nonatomic,strong) NSArray<UIButton*> *groups;
@property(nonatomic,strong) WPControlPositionStore *positionStore;
@property(nonatomic) CGPoint position;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL vertical;
@property(nonatomic) NSInteger builtOrientation;
@end
@implementation WPGameToolbar
- (UIButton*)button:(NSString*)title tag:(NSInteger)tag {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=tag;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    b.titleLabel.adjustsFontSizeToFitWidth=YES;b.titleLabel.minimumScaleFactor=.72;
    b.titleLabel.numberOfLines=2;b.titleLabel.textAlignment=NSTextAlignmentCenter;
    b.tintColor=UIColor.whiteColor;b.backgroundColor=[UIColor colorWithWhite:.18 alpha:.97];
    b.layer.cornerRadius=8;b.accessibilityLabel=title;
    [b addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];return b;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.05 alpha:.94];self.layer.cornerRadius=12;
        self.positionStore=[WPControlPositionStore new];self.positionStore.base=@"Wireproof.GameToolbarPosition";
        NSUserDefaults *defaults=NSUserDefaults.standardUserDefaults;
        if(![defaults arrayForKey:self.positionStore.base])
            [defaults setObject:@[@0,@.72] forKey:self.positionStore.base];
        self.position=CGPointMake(0,.72);
        self.vertical=[defaults objectForKey:@"Wireproof.GameToolbarVertical"]?[defaults boolForKey:@"Wireproof.GameToolbarVertical"]:YES;
        self.bubble=[self button:@"" tag:1002];
        [self.bubble setImage:[UIImage systemImageNamed:@"gamecontroller.fill"] forState:UIControlStateNormal];
        self.bubble.accessibilityLabel=@"Game commands. Tap to open; drag to move.";
        self.header=[self button:@"Game ▾" tag:1001];
        self.orientationButton=[self button:@"↔" tag:1000];
        self.orientationButton.accessibilityLabel=@"Switch Game toolbar orientation";
        self.body=[UIScrollView new];self.body.showsVerticalScrollIndicator=YES;
        [self addSubview:self.body];[self addSubview:self.header];
        [self addSubview:self.orientationButton];[self addSubview:self.bubble];
        NSMutableArray *commands=[NSMutableArray array];
        NSArray *titles=@[@"Stop",@"Guard",@"Scatter",@"Force Attack",@"Force Move",@"Cancel",@"Infantry rally",@"Vehicle rally",@"Clear rallies"];
        NSInteger kinds[]={WPOrders::Stop,WPOrders::Guard,WPOrders::Scatter,WPOrders::Attack,WPOrders::Move,WPOrders::Cancel,WPOrders::RallyInfantry,WPOrders::RallyVehicles,WPOrders::ClearRallies};
        for(NSInteger i=0;i<titles.count;++i)[commands addObject:[self button:titles[i] tag:kinds[i]]];
        self.commands=commands;
        NSMutableArray *groups=[NSMutableArray array];
        for(NSInteger i=0;i<9;++i){UIButton *b=[self button:[NSString stringWithFormat:@"%ld",(long)(i+1)] tag:200+i];
            b.accessibilityLabel=[NSString stringWithFormat:@"Control group %ld",(long)(i+1)];
            b.accessibilityHint=@"Tap to recall; hold to assign selected units.";
            UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(groupHeld:)];
            hold.minimumPressDuration=.5;hold.cancelsTouchesInView=YES;[b addGestureRecognizer:hold];[groups addObject:b];}
        self.groups=groups;
        for(UIView *handle in @[self.bubble,self.header]){UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];[handle addGestureRecognizer:pan];}
    }return self;
}
- (void)pressed:(UIButton*)button {
    if(button.tag==1000){self.vertical=!self.vertical;[NSUserDefaults.standardUserDefaults setBool:self.vertical forKey:@"Wireproof.GameToolbarVertical"];self.builtOrientation=0;[self refresh];return;}
    if(button.tag==1001||button.tag==1002){self.expanded=!self.expanded;[self refresh];return;}
    if(button.tag>=200){WPOrders::Shared().enqueue(WPOrders::Recall,(int)button.tag-200);return;}
    WPOrders::Shared().enqueue((WPOrders::Kind)button.tag);
}
- (void)groupHeld:(UILongPressGestureRecognizer*)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan && WPOrders::Shared().enqueue(WPOrders::Assign,(int)gesture.view.tag-200))
        [[UISelectionFeedbackGenerator new] selectionChanged];
}
- (void)drag:(UIPanGestureRecognizer*)pan {
    if(!self.window)return;
    CGRect safe=CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
    CGPoint delta=[pan translationInView:self.superview];
    CGFloat dx=MAX(0,safe.size.width-self.bounds.size.width),dy=MAX(0,safe.size.height-self.bounds.size.height);
    self.position=CGPointMake(dx?MIN(1,MAX(0,(self.frame.origin.x+delta.x-safe.origin.x)/dx)):0,
                              dy?MIN(1,MAX(0,(self.frame.origin.y+delta.y-safe.origin.y)/dy)):0);
    [pan setTranslation:CGPointZero inView:self.superview];[self refresh];
    if(pan.state==UIGestureRecognizerStateEnded||pan.state==UIGestureRecognizerStateCancelled)
        [self.positionStore save:self.position];
}
- (void)addRow:(NSArray<UIButton*>*)buttons y:(CGFloat*)cursor width:(CGFloat)width buttonWidth:(CGFloat)buttonWidth {
    const CGFloat rowWidth=MAX(width,buttons.count*buttonWidth+MAX(0,(NSInteger)buttons.count-1)*6);
    UIScrollView *scroll=[[UIScrollView alloc] initWithFrame:CGRectMake(0,*cursor,width,44)];
    scroll.tag=1100;
    scroll.showsHorizontalScrollIndicator=rowWidth>width;scroll.contentSize=CGSizeMake(rowWidth,44);
    UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:buttons];
    row.axis=UILayoutConstraintAxisHorizontal;row.spacing=6;row.distribution=UIStackViewDistributionFillEqually;
    row.frame=CGRectMake(0,0,rowWidth,44);[scroll addSubview:row];[self.body addSubview:scroll];
    *cursor+=50;
}
- (void)rebuildRows:(CGFloat)width {
    for(UIView *v in [self.body.subviews copy])if(v.tag==1100)[v removeFromSuperview];
    CGFloat y=0;
    if(self.vertical){
        for(int i=0;i<9;i+=3)[self addRow:[self.groups subarrayWithRange:NSMakeRange(i,3)] y:&y width:width buttonWidth:64];
        for(int i=0;i<6;i+=2)[self addRow:[self.commands subarrayWithRange:NSMakeRange(i,2)] y:&y width:width buttonWidth:104];
        for(int i=6;i<9;++i)[self addRow:@[self.commands[i]] y:&y width:width buttonWidth:width];
    }else{
        [self addRow:self.groups y:&y width:width buttonWidth:48];
        [self addRow:[self.commands subarrayWithRange:NSMakeRange(0,6)] y:&y width:width buttonWidth:98];
        [self addRow:[self.commands subarrayWithRange:NSMakeRange(6,3)] y:&y width:width buttonWidth:120];
    }
    self.body.contentSize=CGSizeMake(width,y);
}
- (void)refresh {
    if(!self.window)return;
    self.position=[self.positionStore update:self.position window:self.window];
    WPOrders::Snapshot s=WPOrders::Shared().snapshot();
    self.hidden=!s.active||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if(self.hidden)return;
    CGRect safe=CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
    CGFloat width=self.expanded?MIN(safe.size.width,self.vertical?228:660):56;
    CGFloat contentHeight=self.vertical?450:150;
    CGFloat height=self.expanded?MIN(safe.size.height,50+contentHeight+8):56;
    if(self.expanded && (self.builtOrientation!=(self.vertical?1:2)||fabs(self.body.bounds.size.width-(width-16))>1)){
        [self rebuildRows:width-16];self.builtOrientation=self.vertical?1:2;
    }
    self.bounds=CGRectMake(0,0,width,height);
    self.frame=CGRectMake(safe.origin.x+self.position.x*MAX(0,safe.size.width-width),
                          safe.origin.y+self.position.y*MAX(0,safe.size.height-height),width,height);
    self.bubble.hidden=self.expanded;self.header.hidden=!self.expanded;self.orientationButton.hidden=!self.expanded;self.body.hidden=!self.expanded;
    self.bubble.frame=self.bounds;
    self.header.frame=CGRectMake(8,6,width-64,44);self.orientationButton.frame=CGRectMake(width-52,6,44,44);
    self.body.frame=CGRectMake(8,56,width-16,MAX(0,height-62));
    [self.orientationButton setTitle:self.vertical?@"↔":@"↕" forState:UIControlStateNormal];
    NSString *title=s.force==1?@"Force Attack: tap target":s.force==2?@"Force Move: tap target":s.rally==1?@"Infantry rally: tap map":s.rally==2?@"Vehicle rally: tap map":[NSString stringWithFormat:@"Game · %d selected",s.selected];
    [self.header setTitle:title forState:UIControlStateNormal];
    for(UIButton *button in self.commands){BOOL needsSelection=button.tag<=WPOrders::Move;
        button.enabled=!needsSelection||s.selected>0;
        button.alpha=button.enabled?1:.45;
        button.backgroundColor=((button.tag==WPOrders::Attack&&s.force==1)||(button.tag==WPOrders::Move&&s.force==2))?UIColor.systemBlueColor:[UIColor colorWithWhite:.18 alpha:.97];
        UIImage *icon=button.tag==WPOrders::Attack?WPAttackIcon:button.tag==WPOrders::Move?WPMoveIcon:nil;
        if(icon&&button.currentImage!=icon)[button setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    }
}
@end

// Build cameos come from the packaged remaster atlas. The TSV is indexed once;
// UIKit only decodes images for buildables currently shown in the deck.
static UIImage *WPBuildCameo(NSString *asset) {
    static NSDictionary<NSString*,NSArray<NSString*>*> *index;
    static NSCache<NSString*,UIImage*> *cache;
    static NSString *root;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        root=[NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"RemasteredArt"];
        NSString *manifest=[NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"frames.tsv"]
                                                   encoding:NSUTF8StringEncoding error:nil];
        NSMutableDictionary *entries=[NSMutableDictionary new];
        [manifest enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            if(![line hasPrefix:@"TD_UI\tICON."])return;
            NSArray<NSString*> *parts=[line componentsSeparatedByString:@"\t"];
            if(parts.count>=11 && [parts[2] isEqualToString:@"0"])
                entries[parts[1]]=@[parts[6],parts[7],parts[8],parts[9],parts[10]];
        }];
        index=[entries copy];cache=[NSCache new];cache.countLimit=80;
    });
    NSString *key=[@"ICON." stringByAppendingString:asset.uppercaseString];
    UIImage *cached=[cache objectForKey:key];if(cached)return cached;
    NSArray<NSString*> *entry=index[key];if(!entry)return nil;
    UIImage *page=[UIImage imageWithContentsOfFile:[root stringByAppendingPathComponent:entry[0]]];
    if(!page.CGImage)return nil;
    CGRect rect=CGRectMake(entry[1].integerValue,entry[2].integerValue,entry[3].integerValue,entry[4].integerValue);
    if(CGRectGetMaxX(rect)>CGImageGetWidth(page.CGImage)||CGRectGetMaxY(rect)>CGImageGetHeight(page.CGImage))return nil;
    CGImageRef crop=CGImageCreateWithImageInRect(page.CGImage,rect);
    UIImage *image=crop?[UIImage imageWithCGImage:crop]:nil;
    if(crop)CGImageRelease(crop);
    if(image)[cache setObject:image forKey:key];
    return image;
}

@interface WPRadarMap : UIView {
    WPOrders::Radar _radar;
}
- (void)updateRadar:(WPOrders::Radar)radar;
@end
@implementation WPRadarMap
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){
        self.backgroundColor=[UIColor colorWithWhite:.08 alpha:1];
        self.layer.borderWidth=1;self.layer.borderColor=UIColor.lightGrayColor.CGColor;
        self.accessibilityLabel=@"Radar map. Tap to center the battlefield.";
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)]];
    }return self;
}
- (void)updateRadar:(WPOrders::Radar)radar {
    _radar=std::move(radar);[self setNeedsDisplay];
}
- (CGRect)mapRect {
    if(_radar.width<=0||_radar.height<=0)return self.bounds;
    CGFloat scale=MIN(self.bounds.size.width/_radar.width,self.bounds.size.height/_radar.height);
    CGSize size=CGSizeMake(_radar.width*scale,_radar.height*scale);
    return CGRectMake((self.bounds.size.width-size.width)/2,(self.bounds.size.height-size.height)/2,size.width,size.height);
}
- (void)tapped:(UITapGestureRecognizer*)tap {
    if(!_radar.active||_radar.width<=0||_radar.height<=0)return;
    CGRect map=[self mapRect];CGPoint point=[tap locationInView:self];
    if(!CGRectContainsPoint(map,point))return;
    int x=_radar.mapX+MIN(_radar.width-1,MAX(0,int((point.x-map.origin.x)*_radar.width/map.size.width)));
    int y=_radar.mapY+MIN(_radar.height-1,MAX(0,int((point.y-map.origin.y)*_radar.height/map.size.height)));
    WPOrders::Shared().enqueueRadarCenter(x,y);
}
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if(_radar.rgba.size()!=size_t(_radar.width)*_radar.height*4 || _radar.rgba.empty()){
        NSString *message=_radar.existing?@"Radar needs power":@"Build a Communications Center to enable radar";
        [message drawInRect:CGRectInset(self.bounds,12,12) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15],NSForegroundColorAttributeName:UIColor.whiteColor}];
        return;
    }
    NSData *data=[NSData dataWithBytes:_radar.rgba.data() length:_radar.rgba.size()];
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(_radar.width,_radar.height,8,32,_radar.width*4,space,
        kCGBitmapByteOrderDefault|kCGImageAlphaLast,provider,NULL,false,kCGRenderingIntentDefault);
    CGRect map=[self mapRect];[[UIImage imageWithCGImage:image] drawInRect:map];
    CGRect camera=CGRectMake(map.origin.x+map.size.width*_radar.cameraX/_radar.width,
        map.origin.y+map.size.height*_radar.cameraY/_radar.height,
        map.size.width*_radar.cameraWidth/_radar.width,
        map.size.height*_radar.cameraHeight/_radar.height);
    CGContextRef context=UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(context,UIColor.systemYellowColor.CGColor);
    CGContextSetLineWidth(context,2);CGContextStrokeRect(context,camera);
    CGImageRelease(image);CGColorSpaceRelease(space);CGDataProviderRelease(provider);
}
@end

// The laptop preview keeps the battlefield on the upper half of the inner
// display and makes production and orders reachable from the lower half.
@interface WPLaptopDock : UIView
@property(nonatomic,weak) WPOrdersPanel *optionsPanel;
@property(nonatomic) BOOL verticalMenu;
@property(nonatomic) BOOL lastBuildOpen;
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,strong) UISegmentedControl *mode;
@property(nonatomic,strong) UISegmentedControl *category;
@property(nonatomic,strong) UIButton *layoutButton;
@property(nonatomic,strong) WPRadarMap *radarMap;
@property(nonatomic,strong) UIButton *artworkButton;
@property(nonatomic,strong) UIButton *laptopButton;
@property(nonatomic,strong) UIScrollView *productionStrip;
@property(nonatomic,strong) UIScrollView *groupsStrip;
@property(nonatomic,strong) NSMutableArray<UIButton*> *productionButtons;
@property(nonatomic,strong) NSArray<UIButton*> *commands;
@property(nonatomic,strong) NSArray<UIButton*> *rallies;
@property(nonatomic,strong) NSArray<UIButton*> *groups;
@property(nonatomic,copy) NSArray<NSString*> *productionKeys;
@end
@implementation WPLaptopDock
- (UIButton*)button:(NSString*)title tag:(NSInteger)tag {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];button.tag=tag;
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.titleLabel.adjustsFontSizeToFitWidth=YES;button.titleLabel.minimumScaleFactor=.7;
    button.titleLabel.numberOfLines=2;button.titleLabel.textAlignment=NSTextAlignmentCenter;
    button.tintColor=UIColor.whiteColor;button.backgroundColor=[UIColor colorWithWhite:.19 alpha:1];
    button.layer.cornerRadius=8;button.accessibilityLabel=title;
    [button addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.05 alpha:.98];
        self.lastBuildOpen=WPLaptop::BuildOpen().load();
        self.layer.borderColor=UIColor.darkGrayColor.CGColor;self.layer.borderWidth=1;
        self.heading=[UILabel new];self.heading.textColor=UIColor.whiteColor;
        self.heading.font=[UIFont systemFontOfSize:15 weight:UIFontWeightBold];
        [self addSubview:self.heading];
        self.mode=[[UISegmentedControl alloc] initWithItems:@[@"Build",@"Commands",@"Radar",@"Cheats",@"Options"]];
        self.mode.selectedSegmentIndex=0;[self.mode addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
        self.category=[[UISegmentedControl alloc] initWithItems:@[@"Buildings",@"Infantry",@"Vehicles",@"Powers"]];
        self.category.selectedSegmentIndex=0;[self.category addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
        for(UISegmentedControl *control in @[self.mode,self.category]) {
            control.selectedSegmentTintColor=UIColor.whiteColor;
            [control setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.whiteColor} forState:UIControlStateNormal];
            [control setTitleTextAttributes:@{NSForegroundColorAttributeName:UIColor.blackColor} forState:UIControlStateSelected];
            [self addSubview:control];
        }
        self.artworkButton=[self button:@"Remastered" tag:900];[self addSubview:self.artworkButton];
        self.laptopButton=[self button:@"Laptop On" tag:901];[self addSubview:self.laptopButton];
        self.verticalMenu=[NSUserDefaults.standardUserDefaults boolForKey:@"Wireproof.LaptopVerticalMenu"];
        self.layoutButton=[self button:@"Layout: Horizontal" tag:902];[self addSubview:self.layoutButton];
        self.radarMap=[WPRadarMap new];[self addSubview:self.radarMap];
        self.productionStrip=[UIScrollView new];self.productionStrip.showsHorizontalScrollIndicator=YES;
        [self addSubview:self.productionStrip];self.productionButtons=[NSMutableArray new];
        self.groupsStrip=[UIScrollView new];self.groupsStrip.showsHorizontalScrollIndicator=YES;
        [self addSubview:self.groupsStrip];
        NSMutableArray *commands=[NSMutableArray new];
        NSArray *names=@[@"Stop",@"Guard",@"Scatter",@"Force Attack",@"Force Move",@"Cancel"];
        NSInteger kinds[]={WPOrders::Stop,WPOrders::Guard,WPOrders::Scatter,WPOrders::Attack,WPOrders::Move,WPOrders::Cancel};
        for(int i=0;i<6;++i){UIButton *button=[self button:names[i] tag:kinds[i]];[self addSubview:button];[commands addObject:button];}
        self.commands=commands;
        NSMutableArray *rallies=[NSMutableArray new];
        NSArray *rallyNames=@[@"Infantry rally",@"Vehicle rally",@"Clear rallies"];
        NSInteger rallyKinds[]={WPOrders::RallyInfantry,WPOrders::RallyVehicles,WPOrders::ClearRallies};
        for(int i=0;i<3;++i){UIButton *button=[self button:rallyNames[i] tag:rallyKinds[i]];[self addSubview:button];[rallies addObject:button];}
        self.rallies=rallies;
        NSMutableArray *groups=[NSMutableArray new];
        for(int i=0;i<9;++i){UIButton *button=[self button:[NSString stringWithFormat:@"%d",i+1] tag:200+i];
            UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(holdGroup:)];
            hold.minimumPressDuration=.5;hold.cancelsTouchesInView=YES;[button addGestureRecognizer:hold];
            [self.groupsStrip addSubview:button];[groups addObject:button];}
        self.groups=groups;
    }return self;
}
- (void)pressed:(UIButton*)button {
    if(button.tag==900||button.tag==901){WPOrders::Shared().enqueue(button.tag==900?WPOrders::ToggleArtwork:WPOrders::ToggleLaptop);return;}
    if(button.tag==902){self.verticalMenu=!self.verticalMenu;
        [NSUserDefaults.standardUserDefaults setBool:self.verticalMenu forKey:@"Wireproof.LaptopVerticalMenu"];
        [self refresh];return;}
    if(button.tag>=1000){
        int value=(int)button.tag-1000;
        bool building=false,special=false;
        for(const auto&item:WPOrders::Shared().productionSnapshot())
            if(item.type==value/1000&&item.id==value%1000){building=item.category==0;special=item.category==3;break;}
        if(special)WPOrders::Shared().enqueueSpecial(value%1000);
        else WPOrders::Shared().enqueueProduction(false,value/1000,value%1000,building);
    }else if(button.tag>=200){WPOrders::Shared().enqueue(WPOrders::Recall,(int)button.tag-200);}
    else WPOrders::Shared().enqueue((WPOrders::Kind)button.tag);
}
- (void)holdProduction:(UILongPressGestureRecognizer*)hold {
    if(hold.state!=UIGestureRecognizerStateBegan)return;
    int value=(int)hold.view.tag-1000;
    bool building=false;
    for(const auto&item:WPOrders::Shared().productionSnapshot())
        if(item.type==value/1000&&item.id==value%1000){building=item.category==0;break;}
    if(WPOrders::Shared().enqueueProduction(true,value/1000,value%1000,building))
        [[UISelectionFeedbackGenerator new] selectionChanged];
}
- (void)modeChanged:(UISegmentedControl*)control {
    if(control==self.mode && control.selectedSegmentIndex<=1){
        self.lastBuildOpen=control.selectedSegmentIndex==0;
        WPLaptop::BuildOpen().store(self.lastBuildOpen);
    }
    self.productionKeys=nil;[self refresh];
}
- (void)holdGroup:(UILongPressGestureRecognizer*)hold {
    if(hold.state==UIGestureRecognizerStateBegan && WPOrders::Shared().enqueue(WPOrders::Assign,(int)hold.view.tag-200))
        [[UISelectionFeedbackGenerator new] selectionChanged];
}
- (void)refresh {
    if(!self.window)return;
    WPOrders::Snapshot state=WPOrders::Shared().snapshot();
    self.hidden=!WPLaptop::Active() || !state.active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if(self.hidden)return;
    CGSize size=self.window.bounds.size;CGFloat top=ceil(size.height*.50);
    self.frame=CGRectMake(0,top,size.width,size.height-top);
    CGFloat inset=MAX(10,self.window.safeAreaInsets.left+8);
    CGFloat width=MAX(1,size.width-inset-MAX(10,self.window.safeAreaInsets.right+8));
    self.heading.frame=CGRectMake(inset,8,width,24);
    self.heading.text=state.placing?@"Place building · drag with two fingers to move map":
        state.rally==1?@"Infantry rally · tap battlefield":state.rally==2?@"Vehicle rally · tap battlefield":
        state.force==1?@"Force Attack · tap target":state.force==2?@"Force Move · tap target":
        [NSString stringWithFormat:@"Command deck · %d selected",state.selected];
    BOOL buildOpen=WPLaptop::BuildOpen().load();
    if(buildOpen!=self.lastBuildOpen)self.mode.selectedSegmentIndex=buildOpen?0:1;
    self.lastBuildOpen=buildOpen;
    const NSInteger page=self.mode.selectedSegmentIndex;
    const BOOL buildMode=page==0,commandsMode=page==1;
    if(self.optionsPanel){self.optionsPanel.laptopPage=page==3?1:page==4?2:0;self.optionsPanel.laptopVertical=self.verticalMenu;}
    self.mode.frame=CGRectMake(inset,36,width,32);
    self.category.hidden=!buildMode;
    self.category.frame=CGRectMake(inset,74,width,32);
    self.layoutButton.hidden=page<3;
    self.layoutButton.frame=CGRectMake(inset,74,width,32);
    [self.layoutButton setTitle:self.verticalMenu?@"Layout: Vertical":@"Layout: Horizontal" forState:UIControlStateNormal];
    self.radarMap.hidden=page!=2;
    [self.artworkButton setTitle:state.remastered?@"Remastered On":@"Remastered Off" forState:UIControlStateNormal];
    CGFloat footerY=self.bounds.size.height-MAX(54,self.window.safeAreaInsets.bottom+50);
    CGFloat radarSize=MAX(60,MIN(width,footerY-88));
    self.radarMap.frame=CGRectMake(inset+(width-radarSize)/2,76,radarSize,radarSize);
    if(page==2)[self.radarMap updateRadar:WPOrders::Shared().radarSnapshot()];
    self.artworkButton.frame=CGRectMake(inset,footerY,(width-8)/2,44);
    self.laptopButton.frame=CGRectMake(inset+(width-8)/2+8,footerY,(width-8)/2,44);
    auto all=WPOrders::Shared().productionSnapshot();
    std::vector<WPOrders::Production> items;
    for(const auto&item:all)
        if(buildMode && item.category==self.category.selectedSegmentIndex) items.push_back(item);
    NSMutableArray<NSString*> *keys=[NSMutableArray new];
    for(const auto&item:items)[keys addObject:[NSString stringWithFormat:@"%d:%d:%d",item.type,item.id,buildMode]];
    if(![keys isEqualToArray:self.productionKeys]) {
        for(UIButton *button in self.productionButtons)[button removeFromSuperview];
        [self.productionButtons removeAllObjects];self.productionKeys=keys;
        for(NSUInteger i=0;i<items.size();++i){UIButton *button=[self button:@"" tag:1000+items[i].type*1000+items[i].id];
            button.accessibilityHint=@"Tap to queue. Hold to cancel queued units and refund production.";
            if(buildMode){NSString *asset=[NSString stringWithUTF8String:items[i].asset.c_str()];
                UIImage *cameo=WPBuildCameo(asset?:@"");
                if(cameo)[button setBackgroundImage:cameo forState:UIControlStateNormal];}
            UILabel *badge=[UILabel new];badge.tag=20001;badge.textColor=UIColor.whiteColor;
            badge.backgroundColor=[UIColor colorWithWhite:0 alpha:.78];badge.font=[UIFont systemFontOfSize:11 weight:UIFontWeightBold];
            badge.textAlignment=NSTextAlignmentCenter;badge.adjustsFontSizeToFitWidth=YES;badge.minimumScaleFactor=.7;
            [button addSubview:badge];
            UIProgressView *progress=[UIProgressView new];progress.tag=20002;progress.progressTintColor=UIColor.systemGreenColor;
            progress.trackTintColor=[UIColor colorWithWhite:.2 alpha:.9];[button addSubview:progress];
            if(items[i].category!=3){UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(holdProduction:)];
                hold.minimumPressDuration=.5;hold.cancelsTouchesInView=YES;[button addGestureRecognizer:hold];}
            [self.productionStrip addSubview:button];[self.productionButtons addObject:button];}
    }
    self.productionStrip.hidden=!buildMode;
    self.productionStrip.frame=CGRectMake(inset,114,width,MAX(80,footerY-122));
    for(NSUInteger i=0;i<self.productionButtons.count;++i){UIButton *button=self.productionButtons[i];
        const auto&item=items[i];NSString *name=[NSString stringWithCString:item.name.c_str() encoding:NSISOLatin1StringEncoding]?:@"Unit";
        NSString *title=item.queued?[NSString stringWithFormat:@"%@ ×%d",name,item.queued]:name;
        NSString *status=item.ready?@"READY":item.category==3?@"CHARGING":item.paused?@"ON HOLD":item.progress>0?[NSString stringWithFormat:@"%d%%",MIN(100,item.progress*100/108)]:item.queued>0?@"QUEUED":@"";
        [button setTitle:buildMode&&button.currentBackgroundImage?@"":title forState:UIControlStateNormal];
        button.accessibilityLabel=status.length?[NSString stringWithFormat:@"%@, %@",title,status]:title;
        if(buildMode){CGFloat cell=MIN(158,(width-24)/4);int columns=MAX(2,int((width+8)/(cell+8)));
            button.frame=CGRectMake((i%columns)*(cell+8),(i/columns)*(cell*.75+8),cell,cell*.75);
        }else button.frame=CGRectMake(i*132,0,126,48);
        UILabel *badge=(UILabel*)[button viewWithTag:20001];UIProgressView *progress=(UIProgressView*)[button viewWithTag:20002];
        badge.text=status;badge.hidden=status.length==0;
        badge.frame=CGRectMake(3,button.bounds.size.height-23,button.bounds.size.width-6,18);
        progress.hidden=item.progress<=0||item.ready;progress.progress=MIN(1,item.progress/108.0f);
        progress.frame=CGRectMake(3,button.bounds.size.height-4,button.bounds.size.width-6,3);
    }
    if(buildMode){CGFloat cell=MIN(158,(width-24)/4);int columns=MAX(2,int((width+8)/(cell+8)));
        self.productionStrip.contentSize=CGSizeMake(width,((items.size()+columns-1)/columns)*(cell*.75+8));}
    else self.productionStrip.contentSize=CGSizeMake(MAX(width,self.productionButtons.count*132),52);
    for(UIButton *button in self.commands)button.hidden=!commandsMode;
    for(UIButton *button in self.rallies)button.hidden=!commandsMode;
    self.groupsStrip.hidden=!commandsMode;
    CGFloat buttonWidth=(width-16)/3;
    for(int i=0;i<6;++i){UIButton *button=self.commands[i];
        button.frame=CGRectMake(inset+(i%3)*(buttonWidth+8),140+(i/3)*49,buttonWidth,44);
        button.enabled=i==5 || state.selected>0;button.alpha=button.enabled?1:.45;
        button.backgroundColor=((i==3&&state.force==1)||(i==4&&state.force==2))?UIColor.systemBlueColor:[UIColor colorWithWhite:.19 alpha:1];
    }
    for(int i=0;i<3;++i){UIButton *button=self.rallies[i];
        button.frame=CGRectMake(inset+i*(buttonWidth+8),242,buttonWidth,44);
        button.backgroundColor=((i==0&&state.rally==1)||(i==1&&state.rally==2))?UIColor.systemBlueColor:[UIColor colorWithWhite:.19 alpha:1];
    }
    self.groupsStrip.frame=CGRectMake(inset,296,width,52);
    for(int i=0;i<9;++i)self.groups[i].frame=CGRectMake(i*54,0,48,44);
    self.groupsStrip.contentSize=CGSizeMake(MAX(width,9*54),48);
}
@end

extern "C" void WP_InstallOrdersPanel(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSTimer *timer=[NSTimer timerWithTimeInterval:0.15 repeats:YES block:^(NSTimer*) {
            static WPOrdersPanel *panel;
            static WPGameToolbar *gameToolbar;
            static WPMapJoystick *joystick;
            static WPLaptopDock *laptopDock;
            if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
                WPOrders::Shared().publish(false,0); panel.hidden=YES;gameToolbar.hidden=YES;joystick.hidden=YES;laptopDock.hidden=YES; return;
            }
            static Uint32 gameWindowID=0;
            SDL_Window *sdl=gameWindowID?SDL_GetWindowFromID(gameWindowID):nullptr;
            if (!sdl) {
                sdl=SDL_GetKeyboardFocus();
                if (sdl) gameWindowID=SDL_GetWindowID(sdl);
            }
            SDL_SysWMinfo info; SDL_VERSION(&info.version);
            if (!sdl || !SDL_GetWindowWMInfo(sdl,&info)) return;
            UIWindow *window=info.info.uikit.window;
            if (!window) return;
            if (!panel || panel.superview!=window) {
                [panel removeFromSuperview]; panel=[WPOrdersPanel new];
                [window addSubview:panel];
            }
            if(!gameToolbar || gameToolbar.superview!=window){[gameToolbar removeFromSuperview];gameToolbar=[WPGameToolbar new];[window addSubview:gameToolbar];}
            if(!joystick || joystick.superview!=window){[joystick removeFromSuperview];joystick=[WPMapJoystick new];[window addSubview:joystick];}
            if(!laptopDock || laptopDock.superview!=window){[laptopDock removeFromSuperview];laptopDock=[WPLaptopDock new];[window addSubview:laptopDock];}
            WPRefreshLaptopPosture(window);
            [joystick refresh];[window bringSubviewToFront:joystick];
            laptopDock.optionsPanel=panel;
            [laptopDock refresh];
            [panel refresh];
            [gameToolbar refresh];
            if(!laptopDock.hidden){gameToolbar.hidden=YES;[window bringSubviewToFront:laptopDock];[window bringSubviewToFront:joystick];}
            // The root view can be reordered during keyboard/window changes.
            // Only raise inside this game window; never steal key-window focus.
            if (!panel.hidden) [window bringSubviewToFront:panel];
            if (!gameToolbar.hidden) [window bringSubviewToFront:gameToolbar];
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
