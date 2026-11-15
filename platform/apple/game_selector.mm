#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>

static UIImage *WPReferenceCrop(UIImage *source, CGRect pixels)
{
    if (!source.CGImage) return nil;
    CGImageRef crop=CGImageCreateWithImageInRect(source.CGImage,pixels);
    if (!crop) return nil;
    UIImage *result=[UIImage imageWithCGImage:crop scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(crop);
    return result;
}

@interface WPArtButton : UIButton
@property(nonatomic,strong) UIImageView *art;
@property(nonatomic,strong) UILabel *caption;
@end
@implementation WPArtButton
- (instancetype)initWithFrame:(CGRect)frame
{
    if((self=[super initWithFrame:frame])) {
        self.art=[[UIImageView alloc] init];self.art.contentMode=UIViewContentModeScaleAspectFit;
        self.art.userInteractionEnabled=NO;[self addSubview:self.art];
        self.caption=[[UILabel alloc] init];self.caption.font=[UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        self.caption.textColor=UIColor.whiteColor;self.caption.textAlignment=NSTextAlignmentCenter;
        self.caption.adjustsFontForContentSizeCategory=YES;self.caption.userInteractionEnabled=NO;
        [self addSubview:self.caption];
        self.accessibilityTraits=UIAccessibilityTraitButton;
    }
    return self;
}
- (void)layoutSubviews
{
    [super layoutSubviews];
    if(self.caption.text.length) {
        self.art.frame=CGRectMake(0,4,self.bounds.size.width,30);
        self.caption.frame=CGRectMake(0,36,self.bounds.size.width,24);
    } else {self.art.frame=self.bounds;self.caption.frame=CGRectZero;}
}
- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    self.alpha=highlighted?.65:1;
    self.backgroundColor=highlighted?[UIColor colorWithWhite:1 alpha:.13]:UIColor.clearColor;
}
@end

@interface WPLauncherSheetController : UIViewController
@property(nonatomic,copy) NSString *body;
@end
@implementation WPLauncherSheetController
- (void)viewDidLoad
{
    [super viewDidLoad];self.view.backgroundColor=UIColor.systemBackgroundColor;
    UITextView *text=[[UITextView alloc] initWithFrame:self.view.bounds];
    text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
    text.editable=NO;text.selectable=YES;text.text=self.body;
    text.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];text.adjustsFontForContentSizeCategory=YES;
    text.textContainerInset=UIEdgeInsetsMake(20,16,24,16);
    text.accessibilityIdentifier=@"game-library-sheet-content";
    [self.view addSubview:text];
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSheet)];
}
- (void)closeSheet {[self dismissViewControllerAnimated:YES completion:nil];}
@end

@interface WPGameSelectionController : UIViewController
@property(nonatomic,copy) void (^selection)(BOOL redAlert);
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIImageView *landscapeArt;
@property(nonatomic,strong) UIImageView *headerArt;
@property(nonatomic,strong) UILabel *prompt;
@property(nonatomic,strong) UILabel *notice;
@property(nonatomic,strong) WPArtButton *dawn;
@property(nonatomic,strong) WPArtButton *alert;
@property(nonatomic,strong) NSArray<WPArtButton*> *footerButtons;
@property(nonatomic,strong) UIImage *reference;
@property(nonatomic,strong) UIImage *dawnCrop;
@property(nonatomic,strong) UIImage *alertCrop;
@property(nonatomic) BOOL selecting;
- (void)prepareWithNotice:(NSString *)notice;
@end

@implementation WPGameSelectionController
- (void)viewDidLoad
{
    [super viewDidLoad];self.view.backgroundColor=UIColor.blackColor;
    NSString *path=[NSBundle.mainBundle pathForResource:@"selector-reference" ofType:@"png"];
    self.reference=[UIImage imageWithContentsOfFile:path];
    self.scroll=[[UIScrollView alloc] init];self.scroll.alwaysBounceVertical=NO;
    [self.view addSubview:self.scroll];
    self.landscapeArt=[[UIImageView alloc] initWithImage:self.reference];
    self.landscapeArt.contentMode=UIViewContentModeScaleAspectFit;self.landscapeArt.isAccessibilityElement=NO;
    [self.scroll addSubview:self.landscapeArt];
    self.headerArt=[[UIImageView alloc] initWithImage:WPReferenceCrop(self.reference,CGRectMake(450,0,770,235))];
    self.headerArt.contentMode=UIViewContentModeScaleAspectFit;self.headerArt.isAccessibilityElement=NO;
    [self.scroll addSubview:self.headerArt];
    self.dawnCrop=WPReferenceCrop(self.reference,CGRectMake(40,235,795,510));
    self.alertCrop=WPReferenceCrop(self.reference,CGRectMake(835,235,795,510));
    self.dawn=[[WPArtButton alloc] initWithFrame:CGRectZero];
    self.alert=[[WPArtButton alloc] initWithFrame:CGRectZero];
    self.dawn.accessibilityIdentifier=@"game-library-tiberian-dawn";
    self.dawn.accessibilityLabel=@"Play Tiberian Dawn. GDI and Nod.";
    self.alert.accessibilityIdentifier=@"game-library-red-alert";
    self.alert.accessibilityLabel=@"Play Red Alert. Allies and Soviets.";
    [self.dawn addTarget:self action:@selector(chooseDawn) forControlEvents:UIControlEventTouchUpInside];
    [self.alert addTarget:self action:@selector(chooseAlert) forControlEvents:UIControlEventTouchUpInside];
    [self.scroll addSubview:self.dawn];[self.scroll addSubview:self.alert];
    NSArray *titles=@[@"Settings",@"Saves",@"Extras",@"About"];
    NSArray *identifiers=@[@"settings",@"saves",@"extras",@"about"];
    NSMutableArray *buttons=[NSMutableArray array];
    const CGFloat iconX[]={490,702,914,1120};
    for(NSUInteger i=0;i<titles.count;++i) {
        WPArtButton *button=[[WPArtButton alloc] initWithFrame:CGRectZero];
        button.tag=i;button.accessibilityLabel=titles[i];
        button.accessibilityIdentifier=[@"game-library-" stringByAppendingString:identifiers[i]];
        button.art.image=WPReferenceCrop(self.reference,CGRectMake(iconX[i],808,70,60));
        [button addTarget:self action:@selector(openFooter:) forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:button];[buttons addObject:button];
    }
    self.footerButtons=buttons;
    self.prompt=[[UILabel alloc] init];self.prompt.text=@"SELECT A GAME TO PLAY";
    self.prompt.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    self.prompt.adjustsFontForContentSizeCategory=YES;self.prompt.textAlignment=NSTextAlignmentCenter;
    self.prompt.textColor=[UIColor colorWithWhite:.85 alpha:1];[self.scroll addSubview:self.prompt];
    self.notice=[[UILabel alloc] init];self.notice.textColor=[UIColor colorWithRed:1 green:.75 blue:.45 alpha:1];
    self.notice.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];self.notice.numberOfLines=0;
    self.notice.adjustsFontForContentSizeCategory=YES;self.notice.textAlignment=NSTextAlignmentCenter;
    self.notice.accessibilityIdentifier=@"game-library-notice";[self.scroll addSubview:self.notice];
}
- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGRect safe=UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
    self.scroll.frame=safe;
    const CGFloat w=safe.size.width,h=safe.size.height;
    const BOOL landscape=w>h && self.reference!=nil;
    self.landscapeArt.hidden=!landscape;self.headerArt.hidden=landscape;self.prompt.hidden=landscape;
    CGFloat bottom=0;
    if(landscape) {
        // The supplied image is unchanged. Hotspots use its exact pixel space.
        CGFloat reserve=self.notice.text.length?66:0;
        CGFloat scale=MIN(w/1672.0,MAX(1,h-reserve)/941.0);
        CGRect image=CGRectMake((w-1672*scale)/2,MAX(0,(h-reserve-941*scale)/2),1672*scale,941*scale);
        self.landscapeArt.frame=image;
        auto rect=[&](CGFloat x,CGFloat y,CGFloat width,CGFloat height){return CGRectMake(image.origin.x+x*scale,image.origin.y+y*scale,width*scale,height*scale);};
        self.dawn.frame=rect(40,235,795,510);self.alert.frame=rect(835,235,795,510);
        self.dawn.art.image=nil;self.alert.art.image=nil;
        const CGFloat left[]={420,630,840,1050};
        for(NSUInteger i=0;i<4;++i) {
            WPArtButton *b=self.footerButtons[i];b.frame=rect(left[i],795,210,116);
            CGRect f=b.frame;if(f.size.height<44){f.origin.y-=(44-f.size.height)/2;f.size.height=44;b.frame=f;}
            b.art.hidden=YES;b.caption.text=nil;b.layer.borderWidth=0;b.backgroundColor=UIColor.clearColor;
        }
        bottom=CGRectGetMaxY(image);
    } else {
        // Reuse the original framed panels, rather than squashing a wide image
        // into the cover display. Every panel remains one large native button.
        CGFloat width=MIN(560,MAX(1,w-20)),x=(w-width)/2,y=8;
        CGFloat headerHeight=width*235/770;
        self.headerArt.frame=CGRectMake(x,y,width,headerHeight);y+=headerHeight+8;
        self.dawn.art.image=self.dawnCrop;self.alert.art.image=self.alertCrop;
        CGFloat cardHeight=width*510/795;
        self.dawn.frame=CGRectMake(x,y,width,cardHeight);y+=cardHeight+10;
        self.alert.frame=CGRectMake(x,y,width,cardHeight);y+=cardHeight+12;
        self.prompt.frame=CGRectMake(x,y,width,30);y+=38;
        NSArray *titles=@[@"Settings",@"Saves",@"Extras",@"About"];
        CGFloat gap=6,buttonWidth=(width-3*gap)/4;
        for(NSUInteger i=0;i<4;++i) {
            WPArtButton *b=self.footerButtons[i];b.frame=CGRectMake(x+i*(buttonWidth+gap),y,buttonWidth,66);
            b.art.hidden=NO;b.caption.text=titles[i];b.layer.borderWidth=1;
            b.layer.borderColor=[UIColor colorWithWhite:.35 alpha:1].CGColor;b.layer.cornerRadius=5;
            b.backgroundColor=[UIColor colorWithWhite:.09 alpha:1];
        }
        bottom=y+74;
    }
    self.notice.hidden=!self.notice.text.length;
    self.notice.frame=CGRectMake(16,bottom+4,MAX(1,w-32),self.notice.text.length?76:0);
    self.scroll.contentSize=CGSizeMake(w,MAX(h,CGRectGetMaxY(self.notice.frame)+8));
}
- (NSString *)saveInventory
{
    NSURL *documents=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *base=[documents URLByAppendingPathComponent:@"TiberianDawn" isDirectory:YES];
    NSMutableString *text=[NSMutableString stringWithString:@"Read-only save inventory. Select the matching game, then Load Game to play a save. Nothing is changed here.\n\n"];
    NSArray *folders=@[@"vanillatd",@"vanillara"],*names=@[@"TIBERIAN DAWN",@"RED ALERT"];
    NSDateFormatter *date=[[NSDateFormatter alloc] init];date.dateStyle=NSDateFormatterMediumStyle;date.timeStyle=NSDateFormatterShortStyle;
    for(NSUInteger i=0;i<folders.count;++i) {
        [text appendFormat:@"%@\n",names[i]];
        NSURL *directory=[base URLByAppendingPathComponent:folders[i] isDirectory:YES];
        NSError *error=nil;
        NSArray<NSURL*> *files=[NSFileManager.defaultManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:@[NSURLIsRegularFileKey,NSURLContentModificationDateKey] options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        NSUInteger count=0;
        for(NSURL *file in [files sortedArrayUsingComparator:^NSComparisonResult(NSURL *a,NSURL *b){return [a.lastPathComponent localizedStandardCompare:b.lastPathComponent];}]) {
            NSString *name=file.lastPathComponent.uppercaseString;
            if(![name hasPrefix:@"SAVEGAME."]) continue;
            NSNumber *regular=nil;[file getResourceValue:&regular forKey:NSURLIsRegularFileKey error:nil];if(!regular.boolValue)continue;
            NSDate *modified=nil;[file getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
            [text appendFormat:@"%@%@\n",file.lastPathComponent,modified?[@"  ·  " stringByAppendingString:[date stringFromDate:modified]]:@""];++count;
        }
        if(!count) [text appendString:error && error.code!=NSFileReadNoSuchFileError?@"Could not read this game's save folder.\n":@"No saved games found.\n"];
        [text appendString:@"\n"];
    }
    return text;
}
- (void)openFooter:(UIButton *)sender
{
    if(self.selecting || self.presentedViewController) return;
    NSArray *titles=@[@"Settings",@"Saves",@"Extras",@"About"];
    WPLauncherSheetController *sheet=[[WPLauncherSheetController alloc] init];sheet.title=titles[sender.tag];
    switch(sender.tag) {
        case 0:sheet.body=@"GAME SETTINGS\n\nChoose Tiberian Dawn or Red Alert, then use that game's Options menu and command panel for graphics, sound and gameplay settings. Each game keeps its own settings.\n\nLAUNCHER\n\nRotate your device for the full artwork. The cover or portrait display stacks the two game panels. Exit Game returns to this launcher.";break;
        case 1:sheet.body=[self saveInventory];break;
        case 2:sheet.body=@"EXTRAS\n\nCampaigns and skirmish are available inside each game. Red Alert expansion missions appear in its own mission menus when the corresponding data is available.\n\nUse the in-game Mod Workshop to review supported rule presets. No new content is downloaded from this launcher.";break;
        default:sheet.body=[NSString stringWithFormat:@"COMMAND & CONQUER\n\nTiberian Dawn + Red Alert\nVersion %@ (%@)\n\nPrivate Wireproof build. Launcher artwork supplied by Tyson. Game names and artwork remain the property of their respective owners.\n\nBased on the Electronic Arts source release and the Vanilla Conquer project. This is not an official EA release.\n\nEach game maintains its own saves. The Saves sheet is read-only.", [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"unknown",[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]?:@"unknown"];break;
    }
    UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:sheet];
    navigation.modalPresentationStyle=UIModalPresentationPageSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)prepareWithNotice:(NSString *)notice
{
    [self loadViewIfNeeded];self.selecting=NO;self.dawn.enabled=YES;self.alert.enabled=YES;
    self.notice.text=notice?:@"";[self.view setNeedsLayout];
}
- (void)choose:(BOOL)redAlert
{
    if(self.selecting || self.presentedViewController) return;
    self.selecting=YES;self.dawn.enabled=NO;self.alert.enabled=NO;
    if(self.selection)self.selection(redAlert);
}
- (void)chooseDawn {[self choose:NO];}
- (void)chooseAlert {[self choose:YES];}
@end

static UIWindowScene *WPGameScene(void)
{
    UIWindowScene *fallback=nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        if (!fallback) fallback=(UIWindowScene *)scene;
        if (scene.activationState==UISceneActivationStateForegroundActive) return (UIWindowScene *)scene;
    }
    return fallback;
}

// The launcher owns the process lifetime. An engine returns only to this loop,
// never to SDL's application startup, and its image is never unloaded while
// Objective-C classes, event watches or engine caches still reference it.
extern "C" int WireproofRunGameLibrary(int argc, char **argv, int (*runDawn)(int,char **))
{
    typedef int (*RunEngine)(int,char **);
    RunEngine runAlert=nullptr;
    void *library=nullptr;
    UIWindow *window=nil;
    WPGameSelectionController *controller=[[WPGameSelectionController alloc] init];
    NSString *notice=nil;
    bool firstVisit=true;
    for (;;) {
        @autoreleasepool {
            __block NSInteger choice=-1;
            UIWindowScene *scene=WPGameScene();
            if (!scene) {
                NSLog(@"Game library requires a connected window scene");
                return EXIT_FAILURE;
            }
            if (!window || window.windowScene!=scene) {
                window.hidden=YES;
                window=[[UIWindow alloc] initWithWindowScene:scene];
                window.windowLevel=UIWindowLevelNormal+1;
                window.rootViewController=controller;
            }
            window.frame=scene.coordinateSpace.bounds;
            [controller prepareWithNotice:notice];
            notice=nil;
            controller.selection=^(BOOL redAlert) { choice=redAlert?1:0; };
            [window makeKeyAndVisible];
#if TARGET_OS_SIMULATOR
            // One-shot test entry: exits still show the real library.
            if (firstVisit) {
                const char *testGame=std::getenv("WIREPROOF_TEST_GAME");
                if (testGame && std::strcmp(testGame,"redalert")==0) choice=1;
                if (testGame && std::strcmp(testGame,"tiberian")==0) choice=0;
            }
#endif
            firstVisit=false;
            while (choice<0) {
                [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:.025]];
            }
            // Keep the controller from retaining a choice block across sessions.
            controller.selection=nil;
            window.hidden=YES;
            if (choice==1 && !runAlert) {
                NSURL *frameworks=NSBundle.mainBundle.privateFrameworksURL;
                if (!frameworks) frameworks=[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Frameworks" isDirectory:YES];
                NSURL *url=[frameworks URLByAppendingPathComponent:@"RedAlertEngine.dylib"];
                if (!library) library=dlopen(url.fileSystemRepresentation,RTLD_NOW|RTLD_LOCAL);
                if (library) runAlert=reinterpret_cast<RunEngine>(dlsym(library,"WireproofRedAlertRun"));
                if (!runAlert) {
                    const char *error=dlerror();
                    NSLog(@"Red Alert engine unavailable: %s",error?error:"missing entry");
                    notice=@"Red Alert could not start. Your saves are unchanged. Please try Tiberian Dawn or update with the complete build.";
                    continue;
                }
            }
            int result=choice==1?runAlert(argc,argv):runDawn(argc,argv);
            NSLog(@"Game returned to library with result %d",result);
            if (result!=EXIT_SUCCESS) notice=@"The game could not start. Your saves are unchanged. Choose a game to try again.";
        }
    }
}
