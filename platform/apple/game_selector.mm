#import <UIKit/UIKit.h>
#include <cstdlib>
#include <cstring>
#include <dlfcn.h>

@interface WPGameSelectionController : UIViewController
@property(nonatomic, copy) void (^selection)(BOOL redAlert);
@property(nonatomic, strong) UIStackView *cards;
@property(nonatomic, strong) NSLayoutConstraint *contentWidth;
@end

@implementation WPGameSelectionController

- (UIButton *)cardWithTitle:(NSString *)title subtitle:(NSString *)subtitle color:(UIColor *)color action:(SEL)action
{
    UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
    card.backgroundColor = color;
    card.layer.cornerRadius = 18;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.28].CGColor;
    card.titleLabel.numberOfLines = 2;
    card.titleLabel.textAlignment = NSTextAlignmentCenter;
    card.titleLabel.font = [UIFont systemFontOfSize:27 weight:UIFontWeightHeavy];
    [card setTitle:[NSString stringWithFormat:@"%@\n%@", title, subtitle] forState:UIControlStateNormal];
    [card addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.055 green:0.075 blue:0.085 alpha:1];

    UILabel *heading = [[UILabel alloc] init];
    heading.text = @"COMMAND & CONQUER";
    heading.textColor = [UIColor colorWithRed:0.85 green:0.78 blue:0.52 alpha:1];
    heading.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBlack];
    heading.textAlignment = NSTextAlignmentCenter;
    heading.adjustsFontSizeToFitWidth = YES;

    UILabel *prompt = [[UILabel alloc] init];
    prompt.text = @"Choose a game";
    prompt.textColor = [UIColor colorWithWhite:0.83 alpha:1];
    prompt.font = [UIFont systemFontOfSize:19 weight:UIFontWeightMedium];
    prompt.textAlignment = NSTextAlignmentCenter;

    UIButton *dawn = [self cardWithTitle:@"TIBERIAN DAWN" subtitle:@"GDI  •  NOD"
                                color:[UIColor colorWithRed:0.19 green:0.27 blue:0.19 alpha:1]
                               action:@selector(chooseDawn)];
    UIButton *alert = [self cardWithTitle:@"RED ALERT" subtitle:@"ALLIES  •  SOVIETS"
                                 color:[UIColor colorWithRed:0.31 green:0.13 blue:0.13 alpha:1]
                                action:@selector(chooseAlert)];
    UIStackView *cards = [[UIStackView alloc] initWithArrangedSubviews:@[dawn, alert]];
    cards.axis = UIScreen.mainScreen.bounds.size.width > 700 ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    cards.distribution = UIStackViewDistributionFillEqually;
    cards.spacing = 16;
    self.cards = cards;

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:@[heading, prompt, cards]];
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 15;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];
    self.contentWidth = [content.widthAnchor constraintEqualToConstant:MIN(900, UIScreen.mainScreen.bounds.size.width * 0.86)];
    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerXAnchor],
        [content.centerYAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.centerYAnchor],
        [content.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:24],
        [content.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-24],
        self.contentWidth,
        [cards.heightAnchor constraintEqualToConstant:230]
    ]];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    self.cards.axis = size.width > 700 ? UILayoutConstraintAxisHorizontal : UILayoutConstraintAxisVertical;
    self.contentWidth.constant = MIN(900, size.width * 0.86);
}

- (void)chooseDawn { if (self.selection) self.selection(NO); }
- (void)chooseAlert { if (self.selection) self.selection(YES); }

@end

// SDL's UIKit delegate calls SDL_main on the main thread after launching the
// application. Pump a nested run loop only while this initial choice is shown.
extern "C" bool WireproofChooseAndRunGame(int argc, char **argv, int *result)
{
    __block NSInteger choice = -1;
#if TARGET_OS_SIMULATOR
    // Automated simulator smoke checks can enter either engine without a
    // synthetic touch injector. Physical builds always show the chooser.
    const char *testGame = std::getenv("WIREPROOF_TEST_GAME");
    if (testGame && std::strcmp(testGame, "redalert") == 0) choice = 1;
    if (testGame && std::strcmp(testGame, "tiberian") == 0) choice = 0;
#endif
    UIWindowScene *gameScene = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]
            && scene.activationState == UISceneActivationStateForegroundActive) {
            gameScene = (UIWindowScene *)scene;
            break;
        }
    }
    if (!gameScene) {
        NSLog(@"Game selection requires an active iOS window scene");
        *result = EXIT_FAILURE;
        return true;
    }
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:gameScene];
    window.frame = gameScene.coordinateSpace.bounds;
    window.windowLevel = UIWindowLevelNormal + 1;
    WPGameSelectionController *controller = [[WPGameSelectionController alloc] init];
    controller.selection = ^(BOOL redAlert) { choice = redAlert ? 1 : 0; };
    window.rootViewController = controller;
    [window makeKeyAndVisible];
    while (choice < 0) {
        [[NSRunLoop mainRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    window.hidden = YES;
    if (choice == 0) return false;

    NSURL *frameworks = NSBundle.mainBundle.privateFrameworksURL;
    if (!frameworks) frameworks = [NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Frameworks" isDirectory:YES];
    NSURL *libraryURL = [frameworks URLByAppendingPathComponent:@"RedAlertEngine.dylib"];
    void *library = dlopen(libraryURL.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    if (!library) {
        NSLog(@"Red Alert engine could not load: %s", dlerror());
        *result = EXIT_FAILURE;
        return true;
    }
    typedef int (*RunEngine)(int, char **);
    RunEngine run = reinterpret_cast<RunEngine>(dlsym(library, "WireproofRedAlertRun"));
    if (!run) {
        NSLog(@"Red Alert engine entry is missing: %s", dlerror());
        dlclose(library);
        *result = EXIT_FAILURE;
        return true;
    }
    NSLog(@"Starting bundled Red Alert engine from %@", libraryURL.path);
    *result = run(argc, argv);
    NSLog(@"Bundled Red Alert engine returned %d", *result);
    dlclose(library);
    return true;
}
