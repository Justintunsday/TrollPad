#import "TPNativeAffordance.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <sys/sysctl.h>
#include <string.h>
#include <stdlib.h>

static void (*TPOriginalAffordanceLayout)(id, SEL);

static BOOL TPAffordanceEncoding(Class cls, SEL selector, const char *types, BOOL requireOwn) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method || strcmp(method_getTypeEncoding(method), types) != 0) return NO;
    if (!requireOwn) return YES;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == selector) found = YES;
    }
    free(methods);
    return found;
}

static BOOL TPWantsNoTopAffordance(id self, SEL cmd) {
    return NO;
}

static UIView *TPNoTopAffordanceHit(id self, SEL cmd, CGPoint point, UIWindow *window) {
    // The native route can return a dot even when its enclosing view is hidden.
    return nil;
}

static void TPHideAffordanceAfterLayout(id self, SEL cmd) {
    TPOriginalAffordanceLayout(self, cmd);
    if (![NSThread isMainThread]) return;
    id view = ((id (*)(id, SEL))objc_msgSend)(self, sel_registerName("topAffordanceView"));
    if ([view isKindOfClass:UIView.class]) {
        [view setHidden:YES];
        [view setUserInteractionEnabled:NO];
    }
}

void TPStartNativeAffordanceHiding(void) {
    static BOOL attempted;
    if (attempted) return;
    attempted = YES;
    if (!CFPreferencesGetAppBooleanValue(CFSTR("TPHideNativeAffordanceEnabled"), CFSTR("com.apple.springboard"), NULL)) return;
    char build[64] = {0};
    size_t length = sizeof(build);
    if (sysctlbyname("kern.osversion", build, &length, NULL, 0) != 0 || strcmp(build, "20B101") != 0) return;

    Class cls = objc_getClass("SBMedusaDecoratedDeviceApplicationSceneViewController");
    SEL wants = sel_registerName("_wantsTopAffordance");
    SEL hit = sel_registerName("hitTestToTopAffordance:window:");
    SEL layout = @selector(viewWillLayoutSubviews);
    if (!TPAffordanceEncoding(cls, wants, "B16@0:8", YES) ||
        !TPAffordanceEncoding(cls, hit, "@40@0:8{CGPoint=dd}16@32", YES) ||
        !TPAffordanceEncoding(cls, layout, "v16@0:8", YES) ||
        !TPAffordanceEncoding(cls, sel_registerName("topAffordanceView"), "@16@0:8", NO)) {
        NSLog(@"[TrollPadVertical] Native button hiding disabled: runtime ABI mismatch");
        return;
    }
    MSHookMessageEx(cls, wants, (IMP)TPWantsNoTopAffordance, NULL);
    MSHookMessageEx(cls, hit, (IMP)TPNoTopAffordanceHit, NULL);
    MSHookMessageEx(cls, layout, (IMP)TPHideAffordanceAfterLayout, (IMP *)&TPOriginalAffordanceLayout);
    NSLog(@"[TrollPadVertical] App multitasking buttons and their hit route disabled");
}
