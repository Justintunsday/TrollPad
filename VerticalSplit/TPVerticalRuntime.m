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
#include <stdlib.h>

static CGRect (*TPOriginalSceneFrame)(id, SEL, NSInteger, id, NSInteger, id);
static CGRect (*TPOriginalHostFrame)(id, SEL, NSInteger, id, CGRect);
static BOOL TPRuntimeInstalled;
static BOOL TPDividerEnabled;
static double TPDividerRatio = 0.5;
static BOOL TPPreviewEnabled;
static BOOL TPBuildingPeekLayout;
static id (*TPOriginalLayoutState)(id, SEL, id);
static CGRect (*TPOriginalPeekFrame)(id, SEL, NSInteger, id, CGRect);
static Ivar TPPeekConfigurationIvar, TPSpaceConfigurationIvar, TPPeekingLayoutIvar;



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

static BOOL TPSinglePrimary(id layout, NSInteger role) {
    if (role != 1) return NO;
    id items = TPObject(layout, "allItems");
    return [items isKindOfClass:[NSArray class]] && [items count] == 1;
}

static NSInteger TPInteger(id object, const char *name) {
    return ((NSInteger (*)(id, SEL))objc_msgSend)(object, sel_registerName(name));
}

static BOOL TPIsPeekScene(id layout, NSInteger role) {
    if (!TPPreviewEnabled || !TPSinglePrimary(layout, role)) return NO;
    if (TPBuildingPeekLayout) return YES;
    id coordinator = TPObject((id)objc_getClass("SBMainSwitcherControllerCoordinator"), "sharedInstanceIfExists");
    id state = TPObject(coordinator, "layoutState");
    // Values observed in the native portrait second-App picker on 20B101.
    return state && TPInteger(state, "peekConfiguration") == 2 &&
           TPInteger(state, "spaceConfiguration") == 4 &&
           [TPObject(state, "appLayout") isEqual:layout];
}

static BOOL TPFrame(CGRect viewport, NSInteger role, CGRect *result) {
    if (viewport.size.height <= viewport.size.width) return NO;
    TPVerticalLayout layout;
    TPRect rect = {viewport.origin.x, viewport.origin.y, viewport.size.width, viewport.size.height};
    double step = UIScreen.mainScreen.scale == 2 ? 0.5 : 1.0;
    if (!TPComputeAlignedVerticalLayout(rect, rect.y + rect.height * TPDividerRatio, 2, 151, 1, step, &layout)) return NO;
    TPRect pane = role == 1 ? layout.upper : layout.lower;
    *result = CGRectMake(pane.x, pane.y, pane.width, pane.height);
    return YES;
}

static CGRect TPSceneFrame(id self, SEL cmd, NSInteger role, id layout, NSInteger orientation, id scene) {
    CGRect original = TPOriginalSceneFrame(self, cmd, role, layout, orientation, scene);
    if (![NSThread isMainThread] || orientation != UIInterfaceOrientationPortrait ||
        (!TPSplitPair(layout, role) && !TPIsPeekScene(layout, role))) return original;
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

static id TPLayoutState(id self, SEL cmd, id context) {
    if (![NSThread isMainThread]) return TPOriginalLayoutState(self, cmd, context);
    BOOL previous = TPBuildingPeekLayout;
    TPBuildingPeekLayout = TPInteger(context, "requestedPeekConfiguration") == 2 &&
                           TPInteger(context, "requestedSpaceConfiguration") == 4;
    @try { return TPOriginalLayoutState(self, cmd, context); }
    @finally { TPBuildingPeekLayout = previous; }
}

static NSInteger TPIvarInteger(id object, Ivar ivar) {
    NSInteger value;
    memcpy(&value, (const char *)(__bridge const void *)object + ivar_getOffset(ivar), sizeof(value));
    return value;
}

static CGRect TPPeekFrame(id self, SEL cmd, NSInteger role, id layout, CGRect bounds) {
    CGRect original = TPOriginalPeekFrame(self, cmd, role, layout, bounds);
    if (![NSThread isMainThread] || !TPSinglePrimary(layout, role) ||
        object_getClass(self) != objc_getClass("SBPeekSplitViewRoutingSwitcherModifier") ||
        TPIvarInteger(self, TPPeekConfigurationIvar) != 2 ||
        TPIvarInteger(self, TPSpaceConfigurationIvar) != 4 ||
        ![object_getIvar(self, TPPeekingLayoutIvar) isEqual:layout]) return original;
    UIWindowScene *scene = TPMainScene();
    if (!scene || scene.screen != UIScreen.mainScreen || scene.interfaceOrientation != UIInterfaceOrientationPortrait) return original;
    CGRect viewport = scene.coordinateSpace.bounds;
    if (!isfinite(bounds.size.width) || !isfinite(bounds.size.height) ||
        fabs(bounds.size.width - viewport.size.width) > 0.5 || fabs(bounds.size.height - viewport.size.height) > 0.5) return original;
    CGRect result;
    return TPFrame(bounds, 1, &result) ? result : original;
}

static BOOL TPOwnMethod(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) if (method_getName(methods[i]) == selector) found = YES;
    free(methods);
    return found;
}

static void TPStartPeekPreview(void) {
    if (!CFPreferencesGetAppBooleanValue(CFSTR("TPVerticalPeekEnabled"), CFSTR("com.apple.springboard"), NULL)) return;
    Class manager = objc_getClass("SBMainDisplayLayoutStateManager");
    Class modifier = objc_getClass("SBPeekSplitViewRoutingSwitcherModifier");
    Class context = objc_getClass("SBWorkspaceApplicationSceneTransitionContext");
    Class state = objc_getClass("SBMainDisplayLayoutState");
    SEL stateSelector = sel_registerName("_layoutStateForApplicationTransitionContext:");
    SEL frameSelector = sel_registerName("frameForLayoutRole:inAppLayout:withBounds:");
    TPPeekConfigurationIvar = class_getInstanceVariable(modifier, "_peekConfiguration");
    TPSpaceConfigurationIvar = class_getInstanceVariable(modifier, "_spaceConfiguration");
    TPPeekingLayoutIvar = class_getInstanceVariable(modifier, "_peekingAppLayout");
    if (!TPEncoding(manager, stateSelector, "@24@0:8@16") || !TPOwnMethod(manager, stateSelector) ||
        !TPEncoding(modifier, frameSelector, "{CGRect={CGPoint=dd}{CGSize=dd}}64@0:8q16@24{CGRect={CGPoint=dd}{CGSize=dd}}32") ||
        !TPOwnMethod(modifier, frameSelector) ||
        !TPEncoding(context, sel_registerName("requestedPeekConfiguration"), "q16@0:8") ||
        !TPEncoding(context, sel_registerName("requestedSpaceConfiguration"), "q16@0:8") ||
        !TPEncoding(state, sel_registerName("peekConfiguration"), "q16@0:8") ||
        !TPEncoding(state, sel_registerName("spaceConfiguration"), "q16@0:8") ||
        !TPPeekConfigurationIvar || !TPSpaceConfigurationIvar || !TPPeekingLayoutIvar ||
        strcmp(ivar_getTypeEncoding(TPPeekConfigurationIvar), "q") != 0 ||
        strcmp(ivar_getTypeEncoding(TPSpaceConfigurationIvar), "q") != 0 ||
        strcmp(ivar_getTypeEncoding(TPPeekingLayoutIvar), "@\"SBAppLayout\"") != 0) {
        NSLog(@"[TrollPadVertical] Peek preview disabled: runtime ABI mismatch");
        return;
    }
    MSHookMessageEx(manager, stateSelector, (IMP)TPLayoutState, (IMP *)&TPOriginalLayoutState);
    MSHookMessageEx(modifier, frameSelector, (IMP)TPPeekFrame, (IMP *)&TPOriginalPeekFrame);
    TPPreviewEnabled = YES;
}

// Research entry point: change only the layout proposal. Scene negotiation is
// deliberately left to an observed native App Switcher activation/dismissal.
@interface NSObject (TPVerticalTransactionResearch)
- (instancetype)initWithApplicationSceneHandle:(id)handle;
- (BOOL)requestTransitionWithBuilder:(void (^)(id request))builder;
- (id)applicationContext;
- (void)setEntity:(id)entity forLayoutRole:(NSInteger)role;
- (void)setRequestedSpaceConfiguration:(NSInteger)configuration;
- (void)setAnimationDisabled:(BOOL)disabled;
- (void)_notifySwitcherControllersAppLayoutsDidChange;
@end

@interface TPVerticalResearch : NSObject
+ (double)dividerRatio;
+ (BOOL)prepareDividerRatio:(double)ratio;
+ (BOOL)requestRatio:(double)ratio primaryHandle:(id)primary secondaryHandle:(id)secondary;
@end

@implementation TPVerticalResearch
+ (double)dividerRatio { return TPDividerRatio; }
+ (BOOL)prepareDividerRatio:(double)ratio {
    if (!TPRuntimeInstalled || ![NSThread isMainThread] || !isfinite(ratio)) return NO;
    UIWindowScene *scene = TPMainScene();
    if (!scene || scene.interfaceOrientation != UIInterfaceOrientationPortrait) return NO;
    id coordinator = TPObject((id)objc_getClass("SBMainSwitcherControllerCoordinator"), "sharedInstanceIfExists");
    id state = TPObject(coordinator, "layoutState");
    if (!TPSplitPair(TPObject(state, "appLayout"), 1)) return NO;
    TPDividerRatio = fmax(1.0 / 3, fmin(ratio, 2.0 / 3));
    return YES;
}
+ (BOOL)requestRatio:(double)ratio primaryHandle:(id)primary secondaryHandle:(id)secondary {
    if (!TPDividerEnabled && !CFPreferencesGetAppBooleanValue(CFSTR("TPVerticalResizeResearchEnabled"), CFSTR("com.apple.springboard"), NULL)) return NO;
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
        !TPEncoding(contextClass, @selector(setAnimationDisabled:), "v20@0:8B16") ||
        !TPEncoding(objc_getClass("SBMainSwitcherControllerCoordinator"), @selector(_notifySwitcherControllersAppLayoutsDidChange), "v16@0:8") ||
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
        [context setAnimationDisabled:YES];
        [context setEntity:first forLayoutRole:1];
        [context setEntity:second forLayoutRole:2];
        [context setRequestedSpaceConfiguration:configuration];
    }];
    if (!accepted) TPDividerRatio = previous;
    else [coordinator _notifySwitcherControllersAppLayoutsDidChange];
    NSLog(@"[TrollPadVertical] Research ratio %.4f transaction accepted=%d", TPDividerRatio, accepted);
    return accepted;
}
@end

UIWindowScene *TPVerticalWindowScene(void) {
    return TPRuntimeInstalled && [NSThread isMainThread] ? TPMainScene() : nil;
}

BOOL TPVerticalKeyboardVisible(void) {
    if (!TPRuntimeInstalled || ![NSThread isMainThread]) return YES;
    Class delegateClass = objc_getClass("UIKeyboardSceneDelegate");
    SEL active = sel_registerName("activeKeyboardSceneDelegate");
    SEL showing = sel_registerName("showingKeyboard");
    if (!TPEncoding(object_getClass(delegateClass), active, "@16@0:8") ||
        !TPEncoding(delegateClass, showing, "B16@0:8")) return YES;
    id delegate = ((id (*)(id, SEL))objc_msgSend)((id)delegateClass, active);
    return delegate && ((BOOL (*)(id, SEL))objc_msgSend)(delegate, showing);
}

static BOOL TPActiveHandles(id *first, id *second) {
    if (!TPRuntimeInstalled || ![NSThread isMainThread]) return NO;
    UIWindowScene *scene = TPMainScene();
    if (!scene || scene.screen != UIScreen.mainScreen || scene.interfaceOrientation != UIInterfaceOrientationPortrait) return NO;
    id lock = TPObject((id)objc_getClass("SBLockScreenManager"), "sharedInstanceIfExists");
    SEL locked = sel_registerName("isUILocked");
    if (!lock || !TPEncoding(object_getClass(lock), locked, "B16@0:8") ||
        ((BOOL (*)(id, SEL))objc_msgSend)(lock, locked)) return NO;
    id coordinator = TPObject((id)objc_getClass("SBMainSwitcherControllerCoordinator"), "sharedInstanceIfExists");
    SEL visible = sel_registerName("isMainSwitcherVisible");
    SEL handleSelector = sel_registerName("_deviceApplicationSceneHandleForDisplayItem:");
    if (!TPEncoding(object_getClass(coordinator), visible, "B16@0:8") ||
        !TPEncoding(object_getClass(coordinator), handleSelector, "@24@0:8@16") ||
        ((BOOL (*)(id, SEL))objc_msgSend)(coordinator, visible)) return NO;
    id layout = TPObject(TPObject(coordinator, "layoutState"), "appLayout");
    if (!TPSplitPair(layout, 1)) return NO;
    SEL itemSelector = sel_registerName("itemForLayoutRole:");
    id firstItem = ((id (*)(id, SEL, NSInteger))objc_msgSend)(layout, itemSelector, 1);
    id secondItem = ((id (*)(id, SEL, NSInteger))objc_msgSend)(layout, itemSelector, 2);
    id a = ((id (*)(id, SEL, id))objc_msgSend)(coordinator, handleSelector, firstItem);
    id b = ((id (*)(id, SEL, id))objc_msgSend)(coordinator, handleSelector, secondItem);
    SEL foreground = sel_registerName("isEffectivelyForeground");
    if (!a || !b || a == b || !TPEncoding(object_getClass(a), foreground, "B16@0:8") ||
        !TPEncoding(object_getClass(b), foreground, "B16@0:8") ||
        !((BOOL (*)(id, SEL))objc_msgSend)(a, foreground) ||
        !((BOOL (*)(id, SEL))objc_msgSend)(b, foreground)) return NO;
    if (first) *first = a;
    if (second) *second = b;
    return YES;
}

BOOL TPCopyActiveVerticalLayout(TPVerticalLayout *layout) {
    if (!layout || !TPActiveHandles(NULL, NULL)) return NO;
    CGRect bounds = TPMainScene().coordinateSpace.bounds;
    TPRect rect = {bounds.origin.x, bounds.origin.y, bounds.size.width, bounds.size.height};
    double step = UIScreen.mainScreen.scale == 2 ? 0.5 : 1.0;
    return TPComputeAlignedVerticalLayout(rect, rect.y + rect.height * TPDividerRatio, 2, 151, 1, step, layout);
}

BOOL TPResizeVerticalSplit(double ratio) {
    id first, second;
    if (!TPDividerEnabled || !TPActiveHandles(&first, &second)) return NO;
    return [TPVerticalResearch requestRatio:ratio primaryHandle:first secondaryHandle:second];
}

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
    TPStartPeekPreview();
    TPDividerEnabled = CFPreferencesGetAppBooleanValue(CFSTR("TPVerticalDividerEnabled"), CFSTR("com.apple.springboard"), NULL);
    if (TPDividerEnabled && TPEncoding(UIWindow.class, sel_registerName("_usesWindowServerHitTesting"), "B16@0:8")) {
        TPStartVerticalDivider();
    } else if (TPDividerEnabled) {
        NSLog(@"[TrollPadVertical] Divider disabled: window hit-test ABI mismatch");
    }
    NSLog(@"[TrollPadVertical] Experimental vertical layout installed for 20B101");
}
