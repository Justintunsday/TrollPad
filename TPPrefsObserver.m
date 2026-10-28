#import "TPPrefsObserver.h"

@implementation TPPrefsObserver
- (instancetype)init {
    self = [super init];
    [self observeKey:@"TPAllowLandscapeHomeScreen"];
    [self observeKey:@"TPForceEnableMedusaForLandscapeOnlyApps"];
    [self observeKey:@"TPHideStageManagerResizeCorners"];
    [self observeKey:@"TPUseiPadAppSwitchingAnimation"];
    [self observeKey:@"TPForceiPadSwitcherStyle"];
    [self observeKey:@"TPIsFloatingDockSupported"];
    [self observeKey:@"TPScaleGridSwitcher"];
    // Fetch keys
    [self observeValueForKeyPath:nil ofObject:nil change:nil context:nil];
    return self;
}

- (void)observeKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults addObserver:self
        forKeyPath:key
        options:NSKeyValueObservingOptionNew
        context:NULL];
}

 - (void)observeValueForKeyPath:(NSString *) 
keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    self.allowLandscapeHomeScreen = [defaults boolForKey:@"TPAllowLandscapeHomeScreen"];
    self.forceEnableMedusaForLandscapeOnlyApps = [defaults boolForKey:@"TPForceEnableMedusaForLandscapeOnlyApps"];
    self.hideStageManagerResizeCorners = [defaults boolForKey:@"TPHideStageManagerResizeCorners"];
    self.useiPadAppSwitchingAnimation = [defaults boolForKey:@"TPUseiPadAppSwitchingAnimation"];
    // Preserve TrollPad's existing layout until the user explicitly opts out.
    self.forceiPadSwitcherStyle = [defaults objectForKey:@"TPForceiPadSwitcherStyle"] == nil
        || [defaults boolForKey:@"TPForceiPadSwitcherStyle"];
    self.isFloatingDockSupported = [defaults boolForKey:@"TPIsFloatingDockSupported"];
    self.scaleGridSwitcher = [defaults boolForKey:@"TPScaleGridSwitcher"];
}
@end
