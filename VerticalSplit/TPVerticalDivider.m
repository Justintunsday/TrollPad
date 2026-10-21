#import "TPVerticalRuntime.h"
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@protocol TPDividerActions <NSObject>
- (void)adjustRatioBy:(double)delta;
@end

@interface TPVerticalGrabber : UIView
@property(nonatomic, weak) id<TPDividerActions> actions;
@end
@implementation TPVerticalGrabber
- (void)accessibilityIncrement { [self.actions adjustRatioBy:0.05]; }
- (void)accessibilityDecrement { [self.actions adjustRatioBy:-0.05]; }
@end

@interface TPVerticalDividerWindow : UIWindow
@property(nonatomic, weak) UIView *grabber;
@end
@implementation TPVerticalDividerWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || !self.grabber || self.grabber.hidden) return NO;
    CGRect hitArea = [self.grabber convertRect:self.grabber.bounds toView:self];
    return CGRectContainsPoint(hitArea, point);
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return [self pointInside:point withEvent:event] ? [super hitTest:point withEvent:event] : nil;
}
@end

@interface TPVerticalDividerController : NSObject <TPDividerActions> {
    CGRect _viewport;
    TPVerticalLayout _layout;
    double _previewY;
}
@property(nonatomic, strong) TPVerticalDividerWindow *window;
@property(nonatomic, strong) TPVerticalGrabber *grabber;
@property(nonatomic, strong) UIPanGestureRecognizer *pan;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL tracking;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL keyboardVisible;
@end

@implementation TPVerticalDividerController
- (instancetype)init {
    if ((self = [super init])) {
        NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
        [center addObserver:self selector:@selector(keyboardShown:) name:UIKeyboardWillShowNotification object:nil];
        [center addObserver:self selector:@selector(keyboardHidden:) name:UIKeyboardDidHideNotification object:nil];
        self.timer = [NSTimer timerWithTimeInterval:0.25 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        [self refresh];
    }
    return self;
}
- (void)keyboardShown:(NSNotification *)notification { self.keyboardVisible = YES; [self refresh]; }
- (void)keyboardHidden:(NSNotification *)notification { self.keyboardVisible = NO; [self refresh]; }

- (void)createWindowForScene:(UIWindowScene *)scene {
    self.window.hidden = YES;
    self.window = [[TPVerticalDividerWindow alloc] initWithWindowScene:scene];
    self.window.frame = scene.coordinateSpace.bounds;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.opaque = NO;
    self.window.windowLevel = UIWindowLevelStatusBar + 1;
    UIViewController *root = [UIViewController new];
    root.view = [[UIView alloc] initWithFrame:self.window.bounds];
    root.view.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = root;
    self.grabber = [[TPVerticalGrabber alloc] initWithFrame:CGRectMake(0, 0, 96, 36)];
    self.grabber.backgroundColor = UIColor.clearColor;
    self.grabber.actions = self;
    self.grabber.isAccessibilityElement = YES;
    self.grabber.accessibilityTraits = UIAccessibilityTraitAdjustable;
    self.grabber.accessibilityLabel = @"分屏分隔条";
    self.grabber.accessibilityHint = @"上下拖动，松手调整两边大小";
    UIView *pill = [[UIView alloc] initWithFrame:CGRectMake(8, 13, 80, 10)];
    pill.backgroundColor = UIColor.darkGrayColor;
    pill.layer.cornerRadius = 5;
    pill.layer.shadowColor = UIColor.blackColor.CGColor;
    pill.layer.shadowOpacity = 0.2;
    pill.layer.shadowRadius = 2;
    pill.layer.shadowOffset = CGSizeMake(0, 1);
    pill.userInteractionEnabled = NO;
    [self.grabber addSubview:pill];
    self.pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    self.pan.minimumNumberOfTouches = 1;
    self.pan.maximumNumberOfTouches = 1;
    [self.grabber addGestureRecognizer:self.pan];
    [root.view addSubview:self.grabber];
    self.window.grabber = self.grabber;
    // Never make this window key. Only the 96x36 grabber accepts hit tests.
}

- (void)positionGrabberAtY:(double)y {
    self.grabber.center = CGPointMake(_viewport.size.width / 2, y - _viewport.origin.y);
}

- (void)refresh {
    TPVerticalLayout layout;
    UIWindowScene *scene = TPVerticalWindowScene();
    BOOL valid = scene && !self.keyboardVisible && TPCopyActiveVerticalLayout(&layout);
    if (!valid) {
        self.window.hidden = YES;
        if (self.tracking) { self.tracking = NO; self.pan.enabled = NO; self.pan.enabled = YES; }
        return;
    }
    CGRect viewport = scene.coordinateSpace.bounds;
    if (self.tracking && !CGRectEqualToRect(viewport, _viewport)) {
        self.tracking = NO; self.pan.enabled = NO; self.pan.enabled = YES;
    }
    _viewport = viewport;
    _layout = layout;
    if (!self.window || self.window.windowScene != scene) [self createWindowForScene:scene];
    self.window.frame = viewport;
    self.window.hidden = NO;
    if (!self.tracking) [self positionGrabberAtY:layout.dividerY];
    self.grabber.accessibilityValue = [NSString stringWithFormat:@"上方约 %.0f%%", 100 * layout.upper.height / (layout.upper.height + layout.lower.height)];
}

- (BOOL)commitRatio:(double)ratio {
    if (self.busy || self.keyboardVisible || !isfinite(ratio)) return NO;
    BOOL accepted = TPResizeVerticalSplit(ratio);
    if (accepted) {
        self.busy = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.busy = NO;
            [self refresh];
        });
    }
    return accepted;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        TPVerticalLayout current;
        if (self.busy || !TPCopyActiveVerticalLayout(&current)) { gesture.enabled = NO; gesture.enabled = YES; return; }
        self.tracking = YES;
        _previewY = current.dividerY;
    }
    if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStateChanged || gesture.state == UIGestureRecognizerStateEnded) {
        if (!self.tracking) return;
        CGPoint translation = [gesture translationInView:self.window];
        TPRect viewport = {_viewport.origin.x, _viewport.origin.y, _viewport.size.width, _viewport.size.height};
        TPVerticalLayout preview;
        double step = self.window.screen.scale == 2 ? 0.5 : 1.0;
        if (TPComputeAlignedVerticalLayout(viewport, _previewY + translation.y, 2, 151, 1, step, &preview)) {
            _previewY = preview.dividerY;
            [self positionGrabberAtY:_previewY];
        }
        [gesture setTranslation:CGPointZero inView:self.window];
        if (gesture.state == UIGestureRecognizerStateEnded) {
            self.tracking = NO;
            [self commitRatio:(_previewY - _viewport.origin.y) / _viewport.size.height];
            [self refresh];
        }
    } else if (gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        self.tracking = NO;
        [self refresh];
    }
}

- (void)adjustRatioBy:(double)delta {
    TPVerticalLayout current;
    if (!TPCopyActiveVerticalLayout(&current)) return;
    CGRect viewport = TPVerticalWindowScene().coordinateSpace.bounds;
    [self commitRatio:(current.dividerY - viewport.origin.y) / viewport.size.height + delta];
    [self refresh];
}
@end

void TPStartVerticalDivider(void) {
    static TPVerticalDividerController *controller;
    if (!controller) controller = [TPVerticalDividerController new];
}
