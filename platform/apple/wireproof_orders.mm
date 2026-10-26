#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include "common/wireproof_orders.h"
#include "common/wireproof_cheats.h"
#include "third_party/SDL2/include/SDL.h"
#include "third_party/SDL2/include/SDL_syswm.h"

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

// Separate touch joystick: drag the outer ring to reposition; drag its center
// to scroll. Double tap toggles a compact persistent map-drag mode.
@interface WPMapJoystick : UIView
@property(nonatomic,strong) UIView *thumb;
@property(nonatomic,strong) UIImageView *hand;
@property(nonatomic) CGPoint position;
@property(nonatomic) BOOL repositioning;
- (void)refresh;
@end
@implementation WPMapJoystick
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=[UIColor colorWithWhite:.10 alpha:.90];
        self.layer.borderWidth=2;self.layer.borderColor=UIColor.grayColor.CGColor;
        self.thumb=[UIView new];self.thumb.backgroundColor=UIColor.systemBlueColor;self.thumb.layer.cornerRadius=22;self.thumb.userInteractionEnabled=NO;[self addSubview:self.thumb];
        self.hand=[[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"hand.draw.fill"]];self.hand.tintColor=UIColor.systemBlueColor;self.hand.contentMode=UIViewContentModeScaleAspectFit;[self addSubview:self.hand];
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
    self.hidden=!WPOrders::Shared().snapshot().active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if(self.hidden){WPOrders::Shared().setStick(0,0);return;}
    BOOL compact=WPOrders::Shared().mapDrag();
    CGRect safe=CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
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
        CGRect safe=CGRectInset(self.window.safeAreaLayoutGuide.layoutFrame,8,8);
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
        [[NSUserDefaults standardUserDefaults] setObject:@[@(self.position.x),@(self.position.y)] forKey:@"Wireproof.JoystickPosition"];
    }
}
- (void)didMoveToWindow { [super didMoveToWindow];if(!self.window)WPOrders::Shared().setStick(0,0); }
@end

@interface WPOrdersPanel : UIView
@property(nonatomic) NSInteger layoutOrientation;
@property(nonatomic) CGSize lastWindowSize;
@property(nonatomic,strong) UISegmentedControl *tabs;
@property(nonatomic,strong) UIStackView *gamePage;
@property(nonatomic,strong) UIStackView *optionsPage;
@property(nonatomic,strong) UIStackView *cheatStack;
@property(nonatomic,strong) UIButton *cheatButton;
@property(nonatomic,strong) UILabel *cheatStatus;
@property(nonatomic,strong) UISwitch *invincibleSwitch;
@property(nonatomic,strong) UISwitch *instantSwitch;
@property(nonatomic,strong) UISwitch *freeSwitch;
@property(nonatomic,strong) UISwitch *shroudSwitch;
@property(nonatomic,strong) NSArray<UISlider*> *speedSliders;
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
@property(nonatomic,strong) NSArray<UIButton*> *modeButtons;
@property(nonatomic,strong) UIButton *toggle;
@property(nonatomic,strong) UISegmentedControl *groupMode;
@property(nonatomic,strong) UISegmentedControl *page;
@property(nonatomic,strong) NSArray<UIButton*> *orderButtons;
@property(nonatomic,strong) NSArray<UIButton*> *groupButtons;
@property(nonatomic) BOOL expanded;
@property(nonatomic) BOOL configured;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic) CGPoint position;
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
        self.backgroundColor=[UIColor colorWithWhite:0.05 alpha:0.92]; self.layer.cornerRadius=12;
        self.toggle=[self button:@"Orders & Groups ▸" tag:100];
        self.bubble=[UIButton buttonWithType:UIButtonTypeSystem];
        [self.bubble setImage:[UIImage systemImageNamed:@"gamecontroller.fill"] forState:UIControlStateNormal];
        self.bubble.tintColor=UIColor.whiteColor;
        self.bubble.accessibilityLabel=@"Tap for Orders and Groups. Drag to reposition.";
        self.bubble.tag=100;
        [self.bubble addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *handle in @[self.toggle,self.bubble]) {
            UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
            pan.maximumNumberOfTouches=1;[handle addGestureRecognizer:pan];
        }
        self.position=CGPointMake(0,1);
        NSArray *saved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"Wireproof.OrdersPosition"];
        if(saved.count==2)self.position=CGPointMake([saved[0] doubleValue],[saved[1] doubleValue]);
        NSMutableArray *orders=[NSMutableArray array];
        NSArray *names=@[@"Stop",@"Guard",@"Scatter",@"Force Attack",@"Force Move",@"Cancel"];
        for (NSInteger i=0;i<names.count;i++) [orders addObject:[self button:names[i] tag:i]];
        self.orderButtons=orders;
        self.groupMode=[[UISegmentedControl alloc] initWithItems:@[@"Recall",@"Assign",@"Add",@"Center"]];
        self.groupMode.selectedSegmentIndex=0;
        self.groupMode.accessibilityLabel=@"Control group action";
        [self.groupMode.heightAnchor constraintEqualToConstant:36].active=YES;
        NSMutableArray *groups=[NSMutableArray array];
        for (NSInteger i=0;i<9;i++) {
            UIButton *b=[self button:[NSString stringWithFormat:@"%ld",(long)((i+1)%10)] tag:200+i];
            b.accessibilityLabel=[NSString stringWithFormat:@"Control group %ld",(long)((i+1)%10)];
            [groups addObject:b];
        }
        self.groupButtons=groups;
        self.page=[[UISegmentedControl alloc] initWithItems:@[@"Orders",@"Groups"]];
        self.page.selectedSegmentIndex=0;
        [self.page addTarget:self action:@selector(pageChanged:) forControlEvents:UIControlEventValueChanged];
        [self.page.heightAnchor constraintEqualToConstant:32].active=YES;
        NSMutableArray *modes=[NSMutableArray array];
        NSArray *modeNames=@[@"Recall",@"Assign",@"Add",@"Center"];
        for (NSInteger i=0;i<4;i++) [modes addObject:[self button:modeNames[i] tag:300+i]];
        self.modeButtons=modes;
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
        UIStackView *zoomRow=[[UIStackView alloc] initWithArrangedSubviews:@[self.zoomMinus,self.zoomSlider,self.zoomPlus]];
        zoomRow.axis=UILayoutConstraintAxisHorizontal; zoomRow.spacing=8;
        self.cheatButton=[self button:@"Cheats" tag:500];
        self.cheatStatus=[UILabel new];self.cheatStatus.textColor=UIColor.whiteColor;
        self.cheatStatus.font=[UIFont systemFontOfSize:12];self.cheatStatus.numberOfLines=3;
        self.invincibleSwitch=[UISwitch new];self.invincibleSwitch.tag=0;
        self.shroudSwitch=[UISwitch new];self.shroudSwitch.tag=1;
        NSMutableArray *cheatRows=[NSMutableArray arrayWithObject:self.cheatStatus];
        [cheatRows addObject:[self gridRow:@[[self button:@"+$1,000" tag:510],[self button:@"+$10,000" tag:511]]]];
        self.instantSwitch=[UISwitch new];self.instantSwitch.tag=2;
        self.freeSwitch=[UISwitch new];self.freeSwitch.tag=3;
        NSArray *switchNames=@[@"Invincibility",@"Shroud",@"Instant Build",@"Zero Cost"];
        NSArray *switches=@[self.invincibleSwitch,self.shroudSwitch,self.instantSwitch,self.freeSwitch];
        for(int i=0;i<4;++i) {
            UILabel *label=[UILabel new];label.text=switchNames[i];label.textColor=UIColor.whiteColor;
            UISwitch *control=switches[i];control.accessibilityLabel=switchNames[i];
            [control addTarget:self action:@selector(cheatSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[label,control]];
            row.axis=UILayoutConstraintAxisHorizontal;row.alignment=UIStackViewAlignmentCenter;
            [row.heightAnchor constraintEqualToConstant:44].active=YES;[cheatRows addObject:row];
        }
        [cheatRows addObject:[self gridRow:@[[self button:@"+100 power" tag:512],[self button:@"+1,000 power" tag:513]]]];
        NSMutableArray *speedSliders=[NSMutableArray array],*speedLabels=[NSMutableArray array];
        for(int i=0;i<3;++i) {
            UILabel *label=[UILabel new];label.textColor=UIColor.whiteColor;label.font=[UIFont systemFontOfSize:13];
            UISlider *slider=[UISlider new];slider.minimumValue=1;slider.maximumValue=12;slider.value=4;slider.tag=i;
            slider.accessibilityLabel=@[@"Infantry speed",@"Vehicle speed",@"Aircraft speed"][i];
            [slider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
            [slider.heightAnchor constraintEqualToConstant:44].active=YES;
            [speedLabels addObject:label];[speedSliders addObject:slider];[cheatRows addObject:label];[cheatRows addObject:slider];
        }
        self.speedSliders=speedSliders;self.speedLabels=speedLabels;
        UILabel *help=[UILabel new];help.numberOfLines=0;help.font=[UIFont systemFontOfSize:11];help.textColor=UIColor.lightGrayColor;
        help.text=@"Player only • Single player\nShroud on restores the earlier explored area and current unit sight. Toggles/speed reset on mission load.";
        [cheatRows addObject:help];
        NSMutableArray *cheatColumns=[NSMutableArray new];
        for(NSUInteger start=0;start<cheatRows.count;start+=6) {
            UIStackView *column=[[UIStackView alloc] initWithArrangedSubviews:[cheatRows subarrayWithRange:NSMakeRange(start,MIN(6,cheatRows.count-start))]];
            column.axis=UILayoutConstraintAxisVertical;column.spacing=6;[cheatColumns addObject:column];
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
            UIStackView *row=[[UIStackView alloc] initWithArrangedSubviews:@[minus,slider,plus]];row.spacing=8;
            [stickRows addObject:label];[stickRows addObject:row];[stickSliders addObject:slider];[stickLabels addObject:label];
        }
        self.joystickSliders=stickSliders;self.joystickLabels=stickLabels;
        UIStackView *stickControls=[[UIStackView alloc] initWithArrangedSubviews:stickRows];stickControls.axis=UILayoutConstraintAxisVertical;stickControls.spacing=6;
        UIStackView *zoomControls=[[UIStackView alloc] initWithArrangedSubviews:@[self.zoomLabel,zoomRow]];zoomControls.axis=UILayoutConstraintAxisVertical;zoomControls.spacing=6;
        self.optionsPage=[[UIStackView alloc] initWithArrangedSubviews:@[zoomControls,stickControls]];self.optionsPage.spacing=8;
        UIStackView *groupColumn=[[UIStackView alloc] initWithArrangedSubviews:@[
            [self gridRow:[groups subarrayWithRange:NSMakeRange(0,5)]],
            [self gridRow:[groups subarrayWithRange:NSMakeRange(5,4)]],
            [self gridRow:@[modes[0],modes[1]]],[self gridRow:@[modes[2],modes[3]]]]];
        groupColumn.axis=UILayoutConstraintAxisVertical;groupColumn.spacing=6;
        UIStackView *orderColumn=[[UIStackView alloc] initWithArrangedSubviews:@[
            [self gridRow:@[orders[3],orders[4]]],[self gridRow:@[orders[0],orders[1]]],[self gridRow:@[orders[2],orders[5]]]]];
        orderColumn.axis=UILayoutConstraintAxisVertical;orderColumn.spacing=6;
        self.gamePage=[[UIStackView alloc] initWithArrangedSubviews:@[groupColumn,orderColumn]];self.gamePage.spacing=8;
        self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"Game",@"Cheats",@"Options"]];self.tabs.selectedSegmentIndex=0;
        [self.tabs.heightAnchor constraintEqualToConstant:36].active=YES;
        [self.tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
        self.stack=[[UIStackView alloc] initWithArrangedSubviews:@[self.toggle,self.tabs,self.gamePage,self.cheatStack,self.optionsPage]];
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
    self.position=CGPointMake(dx?MIN(1,MAX(0,(self.frame.origin.x+delta.x-safe.origin.x)/dx)):0,
                              dy?MIN(1,MAX(0,(self.frame.origin.y+delta.y-safe.origin.y)/dy)):0);
    [pan setTranslation:CGPointZero inView:self.superview];[self refresh];
    if(pan.state==UIGestureRecognizerStateEnded)
        [[NSUserDefaults standardUserDefaults] setObject:@[@(self.position.x),@(self.position.y)] forKey:@"Wireproof.OrdersPosition"];
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
    else WPCheats::Shared().free(control.on);
    [self refresh];
}
- (void)speedChanged:(UISlider*)slider {
    WPCheats::Shared().speed((int)slider.tag,(int)lroundf(slider.value));[self refresh];
}
- (void)tabChanged:(UISegmentedControl*)tabs { self.body.contentOffset=CGPointZero;[self refresh]; }
- (void)joystickChanged:(UISlider*)slider {
    WPOrders::Shared().setJoystickSetting(slider.tag,(int)lroundf(slider.value));
    [[NSUserDefaults standardUserDefaults] setInteger:WPOrders::Shared().joystickSetting(slider.tag) forKey:slider.tag?@"Wireproof.JoystickSpeed":@"Wireproof.JoystickSize"];
    [self refresh];
}
- (void)saveZoom {
    int quarters=WPOrders::Shared().zoomQuarters();
    [[NSUserDefaults standardUserDefaults] setInteger:quarters forKey:@"Wireproof.ZoomQuarters"];
    self.zoomSlider.value=quarters;
    [self refresh];
}
- (void)zoomChanged:(UISlider*)slider {
    WPOrders::Shared().setZoomQuarters((int)lroundf(slider.value));
    [self saveZoom];
}
- (void)pressed:(UIButton*)button {
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
    if (button.tag>=300) { self.groupMode.selectedSegmentIndex=button.tag-300; [self refresh]; return; }
    if (button.tag>=200) {
        const WPOrders::Kind kinds[]={WPOrders::Recall,WPOrders::Assign,WPOrders::Add,WPOrders::Center};
        WPOrders::Shared().enqueue(kinds[self.groupMode.selectedSegmentIndex],(int)button.tag-200);
        self.groupMode.selectedSegmentIndex=0;
    } else WPOrders::Shared().enqueue((WPOrders::Kind)button.tag);
}
- (void)refresh {
    auto s=WPOrders::Shared().snapshot();
    auto cheats=WPCheats::Shared().snapshot();
    self.gamePage.hidden=self.tabs.selectedSegmentIndex!=0;
    self.cheatStack.hidden=self.tabs.selectedSegmentIndex!=1;
    self.optionsPage.hidden=self.tabs.selectedSegmentIndex!=2;
    self.cheatStack.userInteractionEnabled=cheats.available;
    self.cheatStatus.text=[NSString stringWithFormat:@"Credits: %d\nPower: %d / %d",cheats.money,cheats.power,cheats.drain];
    self.instantSwitch.on=cheats.instant;self.freeSwitch.on=cheats.free;
    self.invincibleSwitch.on=cheats.invincible;self.shroudSwitch.on=!cheats.reveal;
    int speeds[]={cheats.infantry,cheats.vehicles,cheats.aircraft};
    for(int i=0;i<3;++i){self.speedSliders[i].value=speeds[i];self.speedLabels[i].text=[NSString stringWithFormat:@"%@: %.2f×",@[@"Infantry",@"Vehicles",@"Aircraft"][i],speeds[i]/4.0];}

    int quarters=WPOrders::Shared().zoomQuarters();
    for(int i=0;i<2;i++){int value=WPOrders::Shared().joystickSetting(i);self.joystickSliders[i].value=value;self.joystickLabels[i].text=[NSString stringWithFormat:@"Joystick %@ %.2f×",i?@"speed":@"size",value/4.0];}
    self.zoomLabel.text=[NSString stringWithFormat:@"Zoom %.2f×",quarters/4.0];
    self.zoomSlider.value=quarters; self.zoomSlider.accessibilityValue=self.zoomLabel.text;
    self.zoomMinus.enabled=quarters>2; self.zoomPlus.enabled=quarters<12;
    self.hidden=!s.active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if (self.hidden) {WPOrders::Shared().hold_pan(false);WPOrders::Shared().setStick(0,0);}
    if(self.window) {
        NSInteger orientation=self.window.windowScene.interfaceOrientation;
        if(!orientation)orientation=self.window.bounds.size.width>self.window.bounds.size.height?UIInterfaceOrientationLandscapeLeft:UIInterfaceOrientationPortrait;
        CGSize size=self.window.bounds.size;
        BOOL resized=self.lastWindowSize.width>0 && (fabs(size.width-self.lastWindowSize.width)>0.5 || fabs(size.height-self.lastWindowSize.height)>0.5);
        if((self.layoutOrientation && self.layoutOrientation!=orientation) || resized)self.expanded=NO;
        self.lastWindowSize=size;
        self.layoutOrientation=orientation;
    }
    if (!self.configured && self.window) { self.expanded=NO; self.configured=YES; }
    NSString *title=s.force==1?@"Force Attack: tap target • Cancel below":s.force==2?@"Force Move: tap destination • Cancel below":[NSString stringWithFormat:@"Orders & Groups %@ · %d selected",self.expanded?@"▾":@"▸",s.selected];
    [self.toggle setTitle:title forState:UIControlStateNormal];
    self.body.hidden=!self.expanded; self.stack.hidden=!self.expanded; self.bubble.hidden=self.expanded;
    BOOL panHeld=WPOrders::Shared().panHeld();
    self.bubble.tintColor=panHeld?UIColor.systemBlueColor:(s.force?UIColor.systemOrangeColor:UIColor.whiteColor);
    [self.bubble setImage:[UIImage systemImageNamed:panHeld?@"hand.draw.fill":@"gamecontroller.fill"] forState:UIControlStateNormal];
    self.layer.cornerRadius=self.expanded?12:28;
    CGRect safe=[self availableRect];
    BOOL landscape=self.window.bounds.size.width>self.window.bounds.size.height;
    for(UIStackView *page in @[self.gamePage,self.cheatStack,self.optionsPage]) {
        page.axis=landscape?UILayoutConstraintAxisHorizontal:UILayoutConstraintAxisVertical;
        page.distribution=landscape?UIStackViewDistributionFillEqually:UIStackViewDistributionFill;
        page.alignment=landscape?UIStackViewAlignmentTop:UIStackViewAlignmentFill;
    }
    CGFloat width=self.expanded?MIN(landscape?520:256,MAX(56,safe.size.width)):56;
    CGFloat height=56;
    __block CGFloat contentHeight=56;
    if (self.expanded) {
        CGSize fit=[self.stack systemLayoutSizeFittingSize:CGSizeMake(width-12,0)
            withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        contentHeight=fit.height;
        height=MIN(safe.size.height,fit.height+12);
    }
    CGFloat x=safe.origin.x+self.position.x*MAX(0,safe.size.width-width);
    CGFloat y=safe.origin.y+self.position.y*MAX(0,safe.size.height-height);
    [UIView performWithoutAnimation:^{
        self.frame=CGRectMake(x,y,width,height);
        self.bubble.frame=self.bounds;
        if (self.expanded) {
            self.body.frame=CGRectInset(self.bounds,6,6);
            self.stack.frame=CGRectMake(0,0,width-12,contentHeight);
            self.body.contentSize=CGSizeMake(width-12,contentHeight);
        }
        [self layoutIfNeeded];
    }];
    for (UIButton *b in self.modeButtons) {
        b.enabled=b.tag!=301 || s.selected>0;
        b.backgroundColor=(b.tag-300==self.groupMode.selectedSegmentIndex)?UIColor.systemBlueColor:[UIColor colorWithWhite:0.18 alpha:0.96];
    }
    for (UIButton *b in self.orderButtons) {
        UIImage *icon=b.tag==WPOrders::Attack?WPAttackIcon:b.tag==WPOrders::Move?WPMoveIcon:nil;
        if (icon && b.currentImage!=icon) {
            [b setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
            b.imageView.layer.magnificationFilter=kCAFilterNearest;
            b.imageEdgeInsets=UIEdgeInsetsMake(0,0,0,6);
        }
        b.enabled=b.tag==WPOrders::Cancel || s.selected>0;
        b.alpha=b.enabled?1:0.4;
        b.backgroundColor=((b.tag==WPOrders::Attack && s.force==1)||(b.tag==WPOrders::Move && s.force==2))?UIColor.systemBlueColor:[UIColor colorWithWhite:0.18 alpha:0.96];
    }
    [self.groupMode setEnabled:s.selected>0 forSegmentAtIndex:1];
}
@end

extern "C" void WP_InstallOrdersPanel(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSTimer *timer=[NSTimer timerWithTimeInterval:0.15 repeats:YES block:^(NSTimer*) {
            static WPOrdersPanel *panel;
            static WPMapJoystick *joystick;
            if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
                WPOrders::Shared().publish(false,0); panel.hidden=YES;joystick.hidden=YES; return;
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
            if(!joystick || joystick.superview!=window){[joystick removeFromSuperview];joystick=[WPMapJoystick new];[window addSubview:joystick];}
            [joystick refresh];[window bringSubviewToFront:joystick];
            [panel refresh];
            // The root view can be reordered during keyboard/window changes.
            // Only raise inside this game window; never steal key-window focus.
            if (!panel.hidden) [window bringSubviewToFront:panel];
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
