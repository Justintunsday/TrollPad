#import "TPVerticalDiagnostics.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#include <stdlib.h>
#include <string.h>

static NSString *const TPDiagnosticsKey = @"TPVerticalDiagnosticsEnabled";

static NSArray *TPSceneCandidates(void) {
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    NSMutableArray *candidates = [NSMutableArray array];
    NSArray *terms = @[@"SceneLayout", @"SplitView", @"Medusa", @"LayoutState", @"SceneManager"];
    for (unsigned int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (![name hasPrefix:@"SB"]) continue;
        BOOL match = NO;
        for (NSString *term in terms) if ([name containsString:term]) { match = YES; break; }
        if (!match) continue;
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(classes[i], &methodCount);
        NSMutableArray *metadata = [NSMutableArray array];
        for (unsigned int j = 0; j < methodCount; j++) {
            const char *types = method_getTypeEncoding(methods[j]);
            [metadata addObject:@{@"selector": NSStringFromSelector(method_getName(methods[j])),
                                  @"encoding": types ? @(types) : @"?"}];
        }
        free(methods);
        [candidates addObject:@{@"name": name, @"methods": metadata}];
    }
    free(classes);
    return candidates;
}

static NSDictionary *TPDescribeMethod(Class cls, NSString *name) {
    Method method = cls ? class_getInstanceMethod(cls, NSSelectorFromString(name)) : NULL;
    if (!method) return @{@"selector": name, @"present": @NO};
    NSMutableArray *arguments = [NSMutableArray array];
    for (unsigned int i = 0; i < method_getNumberOfArguments(method); i++) {
        char *type = method_copyArgumentType(method, i);
        [arguments addObject:type ? @(type) : @"?"];
        free(type);
    }
    char *returnType = method_copyReturnType(method);
    NSString *resultType = returnType ? @(returnType) : @"?";
    free(returnType);
    const char *encoding = method_getTypeEncoding(method);
    BOOL direct = NO;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(methods[i]) == NSSelectorFromString(name)) direct = YES;
    }
    free(methods);
    // A complete structural comparison against the local compiler's C types.
    // This is diagnostic information only; it cannot establish role semantics,
    // PAC compatibility, scene lifecycle or a safe hook calling convention.
    BOOL layoutShape = arguments.count == 6 &&
        [resultType isEqualToString:@(@encode(CGRect))] &&
        [arguments[0] isEqualToString:@(@encode(id))] &&
        [arguments[1] isEqualToString:@(@encode(SEL))] &&
        [arguments[2] isEqualToString:@(@encode(CGSize))] &&
        [arguments[3] isEqualToString:@(@encode(NSInteger))] &&
        [arguments[4] isEqualToString:@(@encode(NSInteger))] &&
        [arguments[5] isEqualToString:@(@encode(NSUInteger))];
    BOOL calculatorShape = arguments.count == 6 &&
        [resultType isEqualToString:@(@encode(CGRect))] &&
        [arguments[0] isEqualToString:@(@encode(id))] &&
        [arguments[1] isEqualToString:@(@encode(SEL))] &&
        [arguments[2] isEqualToString:@(@encode(NSInteger))] &&
        [arguments[3] isEqualToString:@(@encode(id))] &&
        [arguments[4] isEqualToString:@(@encode(NSInteger))] &&
        [arguments[5] isEqualToString:@(@encode(id))];
    return @{@"selector": name, @"present": @YES, @"directImplementation": @(direct),
             @"encoding": encoding ? @(encoding) : @"?", @"returnType": resultType,
             @"arguments": arguments, @"matchesLocalLegacyShape": @(layoutShape),
             @"matchesLocalIOS16CalculatorShape": @(calculatorShape)};
}

static void TPWriteRuntimeReport(void) {
    NSDictionary *targets = @{
        @"SBMainDisplaySceneLayoutViewController": @[
            @"viewDidLoad", @"_layoutFrameForSize:withRole:inInterfaceOrientation:frameOptions:",
            @"_setSeparatorViewAlpha:", @"_shouldNubViewBeVisibleForLayoutRole:inLayoutState:"],
        @"SBMainSwitcherControllerCoordinator": @[@"_loadContentViewControllerIfNecessaryForWindowScene:"],
        @"SBSwitcherController": @[
            @"frameForItemWithRole:inMainAppLayout:interfaceOrientation:",
            @"sceneEntityFrameForWorkspaceEntity:inLayoutState:", @"layoutState"],
        @"SBDisplayItemLayoutAttributesCalculator": @[
            @"frameForLayoutRole:inAppLayout:containerOrientation:windowScene:"],
        @"SBFluidSwitcherViewController": @[
            @"_frameForItemWithRole:inMainAppLayout:interfaceOrientation:"],
        @"SBMainWorkspace": @[@"isMedusaEnabled"],
        @"SBPlatformController": @[@"medusaCapabilities"],
        @"SBApplication": @[@"isMedusaCapable", @"mainSceneWantsFullscreen"]
    };
    NSMutableArray *classes = [NSMutableArray array];
    for (NSString *name in [[targets allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
        Class cls = objc_getClass(name.UTF8String);
        NSMutableArray *methods = [NSMutableArray array];
        for (NSString *selector in targets[name]) [methods addObject:TPDescribeMethod(cls, selector)];
        const char *image = cls ? class_getImageName(cls) : NULL;
        [classes addObject:@{@"name": name, @"present": @(cls != Nil),
                            @"image": image ? @(image) : @"", @"methods": methods}];
    }
#if defined(__arm64e__)
    NSString *architecture = @"arm64e";
#elif defined(__arm64__)
    NSString *architecture = @"arm64";
#else
    NSString *architecture = @"other";
#endif
    NSDictionary *report = @{
        @"schemaVersion": @2, @"timestamp": @([[NSDate date] timeIntervalSince1970]),
        @"osVersion": NSProcessInfo.processInfo.operatingSystemVersionString,
        @"architecture": architecture, @"layoutHooksInstalled": @NO,
        @"verticalBackendVerified": @NO, @"classes": classes,
        @"sceneCandidates": TPSceneCandidates()
    };
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:&error];
    if (!data) { NSLog(@"[TrollPadVertical] report serialization failed: %@", error); return; }
    NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Logs/TrollPad"];
    BOOL made = [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                        withIntermediateDirectories:YES attributes:nil error:&error];
    NSString *path = [directory stringByAppendingPathComponent:@"vertical-runtime.json"];
    if (!made || ![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        NSLog(@"[TrollPadVertical] report write failed: %@", error);
        return;
    }
    NSLog(@"[TrollPadVertical] read-only runtime report: %@; vertical backend unverified", path);
}

static void TPRefreshDiagnostics(void) {
    CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)TPDiagnosticsKey,
                                                       CFSTR("com.apple.springboard"));
    BOOL enabled = value && CFGetTypeID(value) == CFBooleanGetTypeID() &&
                   CFBooleanGetValue((CFBooleanRef)value);
    if (value) CFRelease(value);
    if (enabled) TPWriteRuntimeReport();
}

static void TPDiagnosticRequest(CFNotificationCenterRef center, void *observer,
                                 CFStringRef name, const void *object, CFDictionaryRef info) {
    (void)center; (void)observer; (void)name; (void)object; (void)info;
    dispatch_async(dispatch_get_main_queue(), ^{ TPRefreshDiagnostics(); });
}

void TPStartVerticalDiagnostics(void) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        TPDiagnosticRequest, CFSTR("com.kdt.trollpad.vertical-diagnostics"), NULL,
        CFNotificationSuspensionBehaviorCoalesce);
    TPRefreshDiagnostics();
}
