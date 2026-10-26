#import <UIKit/UIKit.h>
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

@interface WPOrdersPanel : UIView
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
@property(nonatomic) BOOL joystickMode;
@property(nonatomic,strong) UIView *joystickBase;
@property(nonatomic,strong) UIView *joystickThumb;
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
        self.bubble.accessibilityLabel=@"Tap for Orders and Groups. Double tap for map joystick. Drag to reposition. Hold to pan the map with your other finger.";
        UITapGestureRecognizer *single=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openOrders:)];
        UITapGestureRecognizer *doubleTap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleJoystick:)];
        doubleTap.numberOfTapsRequired=2;
        [single requireGestureRecognizerToFail:doubleTap];
        [self.bubble addGestureRecognizer:single];[self.bubble addGestureRecognizer:doubleTap];
        self.joystickBase=[UIView new];self.joystickBase.backgroundColor=[UIColor colorWithWhite:0.12 alpha:0.85];
        self.joystickBase.layer.borderWidth=2;self.joystickBase.layer.borderColor=[UIColor colorWithWhite:0.7 alpha:0.7].CGColor;
        self.joystickBase.accessibilityLabel=@"Map joystick. Drag farther to scroll faster. Double tap to close.";
        self.joystickThumb=[UIView new];self.joystickThumb.userInteractionEnabled=NO;
        self.joystickThumb.backgroundColor=UIColor.systemBlueColor;self.joystickThumb.layer.cornerRadius=22;
        [self.joystickBase addSubview:self.joystickThumb];[self addSubview:self.joystickBase];
        UIPanGestureRecognizer *stickPan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveJoystick:)];
        stickPan.maximumNumberOfTouches=1;[self.joystickBase addGestureRecognizer:stickPan];
        UITapGestureRecognizer *closeStick=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleJoystick:)];
        closeStick.numberOfTapsRequired=2;[self.joystickBase addGestureRecognizer:closeStick];
        self.bubble.tag=100;
        for (UIView *handle in @[self.toggle,self.bubble]) {
            UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
            [handle addGestureRecognizer:pan];
        }
        UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(holdMap:)];
        hold.minimumPressDuration=0.25;
        hold.allowableMovement=10;
        [self.bubble addGestureRecognizer:hold];
        self.position=CGPointMake(0,1);
        NSArray *saved=[[NSUserDefaults standardUserDefaults] arrayForKey:@"Wireproof.OrdersPosition"];
        if (saved.count==2) self.position=CGPointMake([saved[0] doubleValue],[saved[1] doubleValue]);
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
        self.cheatStack=[[UIStackView alloc] initWithArrangedSubviews:cheatRows];
        self.cheatStack.axis=UILayoutConstraintAxisVertical;self.cheatStack.spacing=6;
        self.stack=[[UIStackView alloc] initWithArrangedSubviews:@[
            self.toggle,self.cheatButton,self.cheatStack,self.zoomLabel,zoomRow,
            [self gridRow:[groups subarrayWithRange:NSMakeRange(0,5)]],
            [self gridRow:[groups subarrayWithRange:NSMakeRange(5,4)]],
            [self gridRow:@[modes[0],modes[1]]], [self gridRow:@[modes[2],modes[3]]],
            [self gridRow:@[orders[3],orders[4]]],
            [self gridRow:@[orders[0],orders[1]]], [self gridRow:@[orders[2],orders[5]]]]];
        self.stack.axis=UILayoutConstraintAxisVertical; self.stack.spacing=6;
        self.stack.translatesAutoresizingMaskIntoConstraints=YES;
        self.body=[UIScrollView new]; self.body.alwaysBounceVertical=NO;
        [self.body addSubview:self.stack]; [self addSubview:self.body];

        [self addSubview:self.bubble];
    } return self;
}
- (void)openOrders:(UITapGestureRecognizer*)tap {
    self.expanded=YES;[self refresh];
}
- (void)toggleJoystick:(UITapGestureRecognizer*)tap {
    WPOrders::Shared().setStick(0,0);WPOrders::Shared().hold_pan(false);
    self.joystickMode=!self.joystickMode;self.expanded=NO;[self refresh];
}
- (void)moveJoystick:(UIPanGestureRecognizer*)pan {
    if(pan.state==UIGestureRecognizerStateEnded || pan.state==UIGestureRecognizerStateCancelled || pan.state==UIGestureRecognizerStateFailed) {
        WPOrders::Shared().setStick(0,0);self.joystickThumb.center=CGPointMake(self.bounds.size.width/2,self.bounds.size.height/2);return;
    }
    CGPoint p=[pan locationInView:self.joystickBase];
    CGFloat radius=MAX(1,(self.joystickBase.bounds.size.width-44)/2-6);
    CGFloat x=(p.x-self.joystickBase.bounds.size.width/2)/radius;
    CGFloat y=(p.y-self.joystickBase.bounds.size.height/2)/radius;
    CGFloat length=hypot(x,y);if(length>1){x/=length;y/=length;}
    WPOrders::Shared().setStick(x,y);
    self.joystickThumb.center=CGPointMake(self.joystickBase.bounds.size.width/2+x*radius,self.joystickBase.bounds.size.height/2+y*radius);
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
- (void)holdMap:(UILongPressGestureRecognizer*)hold {
    BOOL held=hold.state==UIGestureRecognizerStateBegan || hold.state==UIGestureRecognizerStateChanged;
    WPOrders::Shared().hold_pan(held);
    [self refresh];
}
- (void)drag:(UIPanGestureRecognizer*)pan {
    CGRect safe=[self availableRect];
    CGPoint delta=[pan translationInView:self.superview];
    CGFloat dx=MAX(0,CGRectGetWidth(safe)-self.bounds.size.width);
    CGFloat dy=MAX(0,CGRectGetHeight(safe)-self.bounds.size.height);
    CGFloat x=MIN(MAX(self.frame.origin.x+delta.x-safe.origin.x,0),dx);
    CGFloat y=MIN(MAX(self.frame.origin.y+delta.y-safe.origin.y,0),dy);
    self.position=CGPointMake(dx>0?x/dx:0,dy>0?y/dy:0);
    [pan setTranslation:CGPointZero inView:self.superview];
    [self refresh];
    if (pan.state==UIGestureRecognizerStateEnded) {
        [[NSUserDefaults standardUserDefaults] setObject:@[@(self.position.x),@(self.position.y)] forKey:@"Wireproof.OrdersPosition"];
    }
}
- (void)pageChanged:(id)sender { [self refresh]; }
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
    self.cheatButton.enabled=cheats.available;
    [self.cheatButton setTitle:self.cheatsOpen?@"Back to orders":@"Cheats" forState:UIControlStateNormal];
    for(UIView *row in self.stack.arrangedSubviews) {
        if(row==self.toggle||row==self.cheatButton)continue;
        row.hidden=row==self.cheatStack?!self.cheatsOpen:self.cheatsOpen;
    }
    self.cheatStack.userInteractionEnabled=cheats.available;
    self.cheatStatus.text=[NSString stringWithFormat:@"Credits: %d\nPower: %d / %d",cheats.money,cheats.power,cheats.drain];
    self.instantSwitch.on=cheats.instant;self.freeSwitch.on=cheats.free;
    self.invincibleSwitch.on=cheats.invincible;self.shroudSwitch.on=!cheats.reveal;
    int speeds[]={cheats.infantry,cheats.vehicles,cheats.aircraft};
    for(int i=0;i<3;++i){self.speedSliders[i].value=speeds[i];self.speedLabels[i].text=[NSString stringWithFormat:@"%@: %.2f×",@[@"Infantry",@"Vehicles",@"Aircraft"][i],speeds[i]/4.0];}

    int quarters=WPOrders::Shared().zoomQuarters();
    self.zoomLabel.text=[NSString stringWithFormat:@"Zoom %.2f×",quarters/4.0];
    self.zoomSlider.value=quarters; self.zoomSlider.accessibilityValue=self.zoomLabel.text;
    self.zoomMinus.enabled=quarters>2; self.zoomPlus.enabled=quarters<12;
    self.hidden=!s.active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive;
    if (self.hidden) {WPOrders::Shared().hold_pan(false);WPOrders::Shared().setStick(0,0);}
    if (!self.configured && self.window) { self.expanded=NO; self.configured=YES; }
    NSString *title=s.force==1?@"Force Attack: tap target • Cancel below":s.force==2?@"Force Move: tap destination • Cancel below":[NSString stringWithFormat:@"Orders & Groups %@ · %d selected",self.expanded?@"▾":@"▸",s.selected];
    [self.toggle setTitle:title forState:UIControlStateNormal];
    self.body.hidden=!self.expanded; self.stack.hidden=!self.expanded; self.bubble.hidden=self.expanded || self.joystickMode;
    self.joystickBase.hidden=!self.joystickMode;
    BOOL panHeld=WPOrders::Shared().panHeld();
    self.bubble.tintColor=panHeld?UIColor.systemBlueColor:(s.force?UIColor.systemOrangeColor:UIColor.whiteColor);
    [self.bubble setImage:[UIImage systemImageNamed:panHeld?@"hand.draw.fill":@"gamecontroller.fill"] forState:UIControlStateNormal];
    self.layer.cornerRadius=self.joystickMode?72:self.expanded?12:28;
    CGRect safe=[self availableRect];
    CGFloat width=self.joystickMode?MIN(144,MIN(safe.size.width,safe.size.height)):self.expanded?MIN(256,MAX(56,safe.size.width)):56;
    CGFloat height=self.joystickMode?width:56;
    __block CGFloat contentHeight=56;
    if (self.expanded) {
        CGSize fit=[self.stack systemLayoutSizeFittingSize:CGSizeMake(width-12,0)
            withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        contentHeight=fit.height;
        height=MIN(safe.size.height,fit.height+12);
    }
    CGFloat x=safe.origin.x+MIN(1,MAX(0,self.position.x))*MAX(0,safe.size.width-width);
    CGFloat y=safe.origin.y+MIN(1,MAX(0,self.position.y))*MAX(0,safe.size.height-height);
    [UIView performWithoutAnimation:^{
        self.frame=CGRectMake(x,y,width,height);
        self.bubble.frame=self.bounds;
        self.joystickBase.frame=self.bounds;self.joystickBase.layer.cornerRadius=width/2;
        self.joystickThumb.bounds=CGRectMake(0,0,44,44);
        if(WPOrders::Shared().stick().intensity<=0)self.joystickThumb.center=CGPointMake(width/2,height/2);
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
            if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive) {
                WPOrders::Shared().publish(false,0); panel.hidden=YES; return;
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
            [panel refresh];
            // The root view can be reordered during keyboard/window changes.
            // Only raise inside this game window; never steal key-window focus.
            if (!panel.hidden) [window bringSubviewToFront:panel];
        }];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    });
}
