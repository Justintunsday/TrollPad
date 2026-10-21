#import "TPVerticalRuntime.h"
#import "TPVerticalGeometry.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <sys/sysctl.h>
#include <string.h>
#include <math.h>

static CGRect (*TPOriginalSceneFrame)(id, SEL, NSInteger, id, NSInteger, id);
static CGRect (*TPOriginalHostFrame)(id, SEL, NSInteger, id, CGRect);
static BOOL TPRuntimeInstalled;
static double TPDividerRatio = 0.5;

@interface NSObject (TPVerticalTransaction)
- (instancetype)initWithApplicationSceneHandle:(id)handle;
- (BOOL)requestTransitionWithBuilder:(void (^)(id request))builder;
- (id)applicationContext;
- (void)setEntity:(id)entity forLayoutRole:(NSInteger)role;
- (void)setRequestedSpaceConfiguration:(NSInteger)configuration;
@end

static id TPObject(id object, const char *name) {
    SEL selector = sel_registerName(name);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}

static BOOL TPSplitPair(id layout, NSInteger role) {
    if (role != 1 && role != 2) return NO;
    SEL split = sel_registerName("isSplitConfiguration");
    SEL item = sel_registerName("itemForLayoutRole:");
    if (![layout respondsToSelector:split] || ![layout respondsToSelector:item]) return NO;
    if (!((BOOL (*)(id, SEL))objc_msgSend)(layout, split)) return NO;
    id items = TPObject(layout, "allItems");
    if (![items isKindOfClass:[NSArray class]] || [items count] != 2) return NO;
    return ((id (*)(id, SEL, NSInteger))objc_msgSend)(layout, item, 1) != nil &&
           ((id (*)(id, SEL, NSInteger))objc_msgSend)(layout, item, 2) != nil;
}

static UIWindowScene *TPMainScene(void) {
    id workspace = TPObject((id)objc_getClass("SBMainWorkspace"), "sharedInstanceIfExists");
    id scene = TPObject(workspace, "mainWindowScene");
    return [scene isKindOfClass:[UIWindowScene class]] ? scene : nil;
}

static BOOL TPFrame(CGRect viewport, NSInteger role, CGRect *result) {
    if (viewport.size.height <= viewport.size.width) return NO;
    TPVerticalLayout layout;
    TPRect rect = {viewport.origin.x, viewport.origin.y, viewport.size.width, viewport.size.height};
    if (!TPComputeVerticalLayout(rect, rect.y + rect.height * TPDividerRatio, 2, 151, 1, &layout)) return NO;
    TPRect pane = role == 1 ? layout.upper : layout.lower;
    *result = CGRectMake(pane.x, pane.y, pane.width, pane.height);
    return YES;
}

static CGRect TPSceneFrame(id self, SEL cmd, NSInteger role, id layout, NSInteger orientation, id scene) {
    CGRect original = TPOriginalSceneFrame(self, cmd, role, layout, orientation, scene);
    if (![NSThread isMainThread] || orientation != UIInterfaceOrientationPortrait || !TPSplitPair(layout, role)) return original;
    if (![scene isKindOfClass:[UIWindowScene class]] || [(UIWindowScene *)scene screen] != UIScreen.mainScreen) return original;
    CGRect result;
    return TPFrame([(UIWindowScene *)scene coordinateSpace].bounds, role, &result) ? result : original;
}

static CGRect TPHostFrame(id self, SEL cmd, NSInteger role, id layout, CGRect bounds) {
    CGRect original = TPOriginalHostFrame(self, cmd, role, layout, bounds);
    if (![NSThread isMainThread] || object_getClass(self) != objc_getClass("SBSplitViewRootSwitcherModifier") || !TPSplitPair(layout, role)) return original;
    UIWindowScene *scene = TPMainScene();
    if (!scene || scene.screen != UIScreen.mainScreen || scene.interfaceOrientation != UIInterfaceOrientationPortrait) return original;
    CGRect viewport = scene.coordinateSpace.bounds;
    if (!isfinite(bounds.size.width) || !isfinite(bounds.size.height) ||
        fabs(bounds.size.width - viewport.size.width) > 0.5 || fabs(bounds.size.height - viewport.size.height) > 0.5) return original;
    CGRect result;
    return TPFrame(bounds, role, &result) ? result : original;
}

static BOOL TPEncoding(Class cls, SEL selector, const char *expected) {
    Method method = class_getInstanceMethod(cls, selector);
    return method && method_getTypeEncoding(method) && strcmp(method_getTypeEncoding(method), expected) == 0;
}

// Research entry point only. No gesture calls this until the transaction has
// been verified on device. All entities wrap existing live scene handles.
@interface TPVerticalResearch : NSObject
+ (double)dividerRatio;
+ (BOOL)requestRatio:(double)ratio primaryHandle:(id)primary secondaryHandle:(id)secondary;
@end

@implementation TPVerticalResearch
+ (double)dividerRatio { return TPDividerRatio; }
+ (BOOL)requestRatio:(double)ratio primaryHandle:(id)primary secondaryHandle:(id)secondary {
    if (!TPRuntimeInstalled || ![NSThread isMainThread] || !isfinite(ratio)) return NO;
    UIWindowScene *scene = TPMainScene();
    if (!scene || scene.interfaceOrientation != UIInterfaceOrientationPortrait) return NO;
    Class handleClass = objc_getClass("SBDeviceApplicationSceneHandle");
    if (![primary isKindOfClass:handleClass] || ![secondary isKindOfClass:handleClass] || primary == secondary) return NO;
    if (!TPEncoding(handleClass, sel_registerName("isEffectivelyForeground"), "B16@0:8") ||
        !TPEncoding(handleClass, sel_registerName("layoutRole"), "q16@0:8")) return NO;
    SEL foreground = sel_registerName("isEffectivelyForeground");
    SEL roleSelector = sel_registerName("layoutRole");
    if (!((BOOL (*)(id, SEL))objc_msgSend)(primary, foreground) ||
        !((BOOL (*)(id, SEL))objc_msgSend)(secondary, foreground) ||
        ((NSInteger (*)(id, SEL))objc_msgSend)(primary, roleSelector) != 1 ||
        ((NSInteger (*)(id, SEL))objc_msgSend)(secondary, roleSelector) != 2) return NO;
    id coordinator = TPObject((id)objc_getClass("SBMainSwitcherControllerCoordinator"), "sharedInstanceIfExists");
    id state = TPObject(coordinator, "layoutState");
    if (!TPSplitPair(TPObject(state, "appLayout"), 1)) return NO;
    Class entityClass = objc_getClass("SBDeviceApplicationSceneEntity");
    Class contextClass = objc_getClass("SBWorkspaceApplicationSceneTransitionContext");
    Class requestClass = objc_getClass("SBMainWorkspaceTransitionRequest");
    Class workspaceClass = objc_getClass("SBMainWorkspace");
    if (!TPEncoding(entityClass, @selector(initWithApplicationSceneHandle:), "@24@0:8@16") ||
        !TPEncoding(contextClass, @selector(setEntity:forLayoutRole:), "v32@0:8@16q24") ||
        !TPEncoding(contextClass, @selector(setRequestedSpaceConfiguration:), "v24@0:8q16") ||
        !TPEncoding(requestClass, @selector(applicationContext), "@16@0:8") ||
        !TPEncoding(workspaceClass, @selector(requestTransitionWithBuilder:), "B24@0:8@?16") ||
        !TPEncoding(object_getClass(state), sel_registerName("spaceConfiguration"), "q16@0:8")) return NO;
    id first = [[entityClass alloc] initWithApplicationSceneHandle:primary];
    id second = [[entityClass alloc] initWithApplicationSceneHandle:secondary];
    if (!first || !second) return NO;
    NSInteger configuration = ((NSInteger (*)(id, SEL))objc_msgSend)(state, sel_registerName("spaceConfiguration"));
    id workspace = TPObject((id)workspaceClass, "sharedInstanceIfExists");
    double previous = TPDividerRatio;
    TPDividerRatio = fmax(1.0 / 3, fmin(ratio, 2.0 / 3));
    // Compiler-generated ARC Block: do not inject a manually constructed Block.
    BOOL accepted = [workspace requestTransitionWithBuilder:^(id request) {
        id context = [request applicationContext];
        [context setEntity:first forLayoutRole:1];
        [context setEntity:second forLayoutRole:2];
        [context setRequestedSpaceConfiguration:configuration];
    }];
    if (!accepted) TPDividerRatio = previous;
    NSLog(@"[TrollPadVertical] Research ratio %.4f transaction accepted=%d", TPDividerRatio, accepted);
    return accepted;
}
@end

void TPStartVerticalRuntime(void) {
    static BOOL attempted;
    if (attempted) return;
    attempted = YES;
    if (!CFPreferencesGetAppBooleanValue(CFSTR("TPVerticalSplitEnabled"), CFSTR("com.apple.springboard"), NULL)) return;
    char build[64] = {0};
    size_t length = sizeof(build);
    if (sysctlbyname("kern.osversion", build, &length, NULL, 0) != 0 || strcmp(build, "20B101") != 0) {
        NSLog(@"[TrollPadVertical] Fixed layout disabled: unverified OS build");
        return;
    }
    Class calculator = objc_getClass("SBDisplayItemLayoutAttributesCalculator");
    Class modifier = objc_getClass("SBSplitViewRootSwitcherModifier");
    SEL sceneSelector = sel_registerName("frameForLayoutRole:inAppLayout:containerOrientation:windowScene:");
    SEL hostSelector = sel_registerName("frameForLayoutRole:inAppLayout:withBounds:");
    const char *sceneTypes = "{CGRect={CGPoint=dd}{CGSize=dd}}48@0:8q16@24q32@40";
    const char *hostTypes = "{CGRect={CGPoint=dd}{CGSize=dd}}64@0:8q16@24{CGRect={CGPoint=dd}{CGSize=dd}}32";
    if (!TPEncoding(calculator, sceneSelector, sceneTypes) || !TPEncoding(modifier, hostSelector, hostTypes)) {
        NSLog(@"[TrollPadVertical] Fixed layout disabled: runtime ABI mismatch");
        return;
    }
    // Add an own method before hooking: never replace the inherited superclass Method.
    Method inherited = class_getInstanceMethod(modifier, hostSelector);
    if (!class_addMethod(modifier, hostSelector, method_getImplementation(inherited), hostTypes)) {
        NSLog(@"[TrollPadVertical] Fixed layout disabled: host already overrides method");
        return;
    }
    MSHookMessageEx(calculator, sceneSelector, (IMP)TPSceneFrame, (IMP *)&TPOriginalSceneFrame);
    MSHookMessageEx(modifier, hostSelector, (IMP)TPHostFrame, (IMP *)&TPOriginalHostFrame);
    TPRuntimeInstalled = YES;
    NSLog(@"[TrollPadVertical] Experimental fixed 50:50 layout installed for 20B101");
}
