//
//  GoNativeAppConfig.m
//  MedianIOS
//
//  Local implementation replacing the GoNativeCore pod.
//  Reads configuration from the bundled appConfig.json file.
//

#import "GoNativeAppConfig.h"
#import <WebKit/WebKit.h>
#import <sys/utsname.h>

// ─── Notification constant definitions ────────────────────────────────────────
NSString * const kGoNativeAppConfigNotificationUserAgentReady      = @"co.median.ios.AppConfig.userAgentReady";
NSString * const kGoNativeCoreDeviceDidShake                       = @"co.median.ios.deviceDidShake";
NSString * const kLEANAppConfigNotificationProcessedMenu           = @"co.median.ios.AppConfig.processedMenu";
NSString * const kLEANAppConfigNotificationProcessedSegmented      = @"co.median.ios.AppConfig.processedSegmented";
NSString * const kLEANAppConfigNotificationProcessedTabNavigation  = @"co.median.ios.AppConfig.processedTabNavigation";
NSString * const kLEANAppConfigNotificationProcessedNavigationTitles = @"co.median.ios.AppConfig.processedNavigationTitles";
NSString * const kLEANAppConfigNotificationProcessedNavigationLevels = @"co.median.ios.AppConfig.processedNavigationLevels";
NSString * const kLEANAppConfigNotificationProcessedWebViewPools   = @"co.median.ios.AppConfig.processedWebViewPools";
NSString * const kLEANAppConfigNotificationAppTrackingStatusChanged= @"co.median.ios.AppConfig.appTrackingStatusChanged";
NSString * const MEDIAN_KEYBOARD_EVENT_LISTENER                    = @"keyboardEvent";

// ─── RegexEnabled ─────────────────────────────────────────────────────────────
@implementation RegexEnabled
@end

// ─── ActionSelection ──────────────────────────────────────────────────────────
@implementation ActionSelection
@end

// ─── GoNativeAppConfig ────────────────────────────────────────────────────────
@interface GoNativeAppConfig ()
@property (nonatomic, strong) NSDictionary *rawConfig;
@property (nonatomic, strong) NSArray      *userAgentRegexes;   // [{regex, userAgent}]
@end

@implementation GoNativeAppConfig

// ── Singleton ─────────────────────────────────────────────────────────────────
+ (instancetype)sharedAppConfig {
    static GoNativeAppConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GoNativeAppConfig alloc] init];
    });
    return instance;
}

+ (instancetype)shared {
    return [self sharedAppConfig];
}

// ── Initialisation ────────────────────────────────────────────────────────────
- (instancetype)init {
    self = [super init];
    if (self) {
        [self loadConfig];
        [self buildUserAgent];
    }
    return self;
}

// ── Config loading ────────────────────────────────────────────────────────────
- (void)loadConfig {
    NSURL *configURL = [[NSBundle mainBundle] URLForResource:@"appConfig" withExtension:@"json"];
    if (!configURL) {
        NSLog(@"GoNativeAppConfig: appConfig.json not found in bundle.");
        [self applyDefaults];
        return;
    }

    NSError *error;
    NSData *data = [NSData dataWithContentsOfURL:configURL options:0 error:&error];
    if (!data) {
        NSLog(@"GoNativeAppConfig: could not read appConfig.json – %@", error);
        [self applyDefaults];
        return;
    }

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![json isKindOfClass:[NSDictionary class]]) {
        NSLog(@"GoNativeAppConfig: invalid JSON – %@", error);
        [self applyDefaults];
        return;
    }

    self.rawConfig = json;
    [self parseConfig:json];
}

- (void)applyDefaults {
    self.appName               = @"App";
    self.injectMedianJS        = YES;
    self.useWKWebView          = YES;
    self.userAgentReady        = NO;
    self.pullToRefresh         = YES;
    self.iosShowOfflinePage    = YES;
    self.iosConnectionOfflineTime = @10;
    self.maxWindows            = 5;
    self.menuAnimationDuration = @0.15;
    self.interactiveDelay      = @0.2;
    self.hideWebviewAlpha      = @0.5;
    self.iosTheme              = @"default";
    self.iosDarkMode           = @"auto";
    self.iosStatusBarStyle     = @"auto";
    self.showNavigationBar     = NO;
    self.listeners             = @{};
    self.contextMenuEnabled    = NO;
    self.contextMenuLinkActions= @[@"copyLink", @"openExternal"];
    self.sidebarMenuIcon       = @"fas fa-bars";
    self.enableWindowOpen      = YES;
    self.transparentNavBar     = YES;
}

- (void)parseConfig:(NSDictionary *)json {
    NSDictionary *general   = json[@"general"]    ?: @{};
    NSDictionary *nav       = json[@"navigation"] ?: @{};
    NSDictionary *styling   = json[@"styling"]    ?: @{};
    NSDictionary *ctx       = json[@"contextMenu"]?: @{};
    NSDictionary *devTools  = json[@"developmentTools"] ?: @{};
    NSDictionary *perms     = json[@"permissions"] ?: @{};
    
    // ── General ──────────────────────────────────────────────────────────────
    self.appName    = general[@"appName"]  ?: @"App";
    self.publicKey  = general[@"publicKey"]?: @"";
    
    NSString *urlStr = general[@"initialUrl"];
    self.initialURL  = [urlStr isKindOfClass:[NSString class]] ? [NSURL URLWithString:urlStr] : nil;
    self.initialHost = self.initialURL.host;
    
    self.injectMedianJS = [general[@"injectMedianJS"] boolValue];
    self.enableWindowOpen = general[@"enableWindowOpen"] != nil ? [general[@"enableWindowOpen"] boolValue] : YES;
    self.forceSessionCookieExpiry = [general[@"forceSessionCookieExpiry"] unsignedIntegerValue];
    self.replaceStrings = general[@"replaceStrings"] ?: @[];
    self.customHeaders  = general[@"iosCustomHeaders"] ?: @{};
    self.useWKWebView   = YES;
    self.disableEventRecorder = NO;
    self.userAgentRegexes = general[@"userAgentRegexes"] ?: @[];
    
    // ── Navigation ───────────────────────────────────────────────────────────
    self.pullToRefresh         = [nav[@"iosPullToRefresh"] boolValue];
    self.iosShowOfflinePage    = nav[@"iosShowOfflinePage"] != nil ? [nav[@"iosShowOfflinePage"] boolValue] : YES;
    self.iosConnectionOfflineTime = nav[@"iosConnectionOfflineTime"] ?: @10;
    
    id swipeVal = nav[@"swipeGestures"];
    self.swipeGestures = (swipeVal != nil && swipeVal != [NSNull null]) ? [swipeVal boolValue] : YES;
    
    // Max windows
    NSDictionary *maxWin = nav[@"maxWindows"];
    if ([maxWin isKindOfClass:[NSDictionary class]] && [maxWin[@"enabled"] boolValue]) {
        self.maxWindows          = [maxWin[@"numWindows"] integerValue] ?: 5;
        self.maxWindowsAutoClose = [maxWin[@"autoClose"] boolValue];
    } else {
        self.maxWindows          = 0; // 0 means unlimited
        self.maxWindowsAutoClose = NO;
    }
    
    // Sidebar navigation / menus
    NSDictionary *sidebarNav = nav[@"sidebarNavigation"] ?: @{};
    self.menus              = [self parseSidebarMenus:sidebarNav[@"menus"]];
    self.showNavigationMenu = [self.menus count] > 0;
    
    // Segmented control items – some configs embed them in sidebarNavigation
    NSDictionary *segCtrl = sidebarNav[@"segmentedControl"];
    if ([segCtrl isKindOfClass:[NSDictionary class]]) {
        self.segmentedControlItems = segCtrl[@"items"];
    }
    
    // Tab navigation
    NSDictionary *tabNav = nav[@"tabNavigation"] ?: @{};
    [self parseTabNavigation:tabNav];
    
    // Regex internal/external rules (initialised lazily via initializeRegexRules:)
    // Nothing to do at load time.
    
    // Navigation levels
    NSDictionary *navLevels = nav[@"navigationLevels"] ?: @{};
    if ([navLevels[@"active"] boolValue]) {
        self.navStructureLevels = navLevels[@"levels"] ?: @[];
    } else {
        self.navStructureLevels = @[];
    }
    
    // Navigation titles
    NSDictionary *navTitlesDict = nav[@"navigationTitles"] ?: @{};
    if ([navTitlesDict[@"active"] boolValue]) {
        self.navTitles = navTitlesDict[@"titles"] ?: @[];
    } else {
        self.navTitles = @[];
    }
    
    // Redirects
    NSArray *redirectArr = nav[@"redirects"];
    if ([redirectArr isKindOfClass:[NSArray class]]) {
        NSMutableDictionary *rmap = [NSMutableDictionary dictionary];
        for (NSDictionary *entry in redirectArr) {
            NSString *from = entry[@"from"];
            NSString *to   = entry[@"to"];
            if ([from isKindOfClass:[NSString class]] && [to isKindOfClass:[NSString class]]) {
                rmap[from] = to;
            }
        }
        self.redirects = [rmap copy];
    }
    
    // Toolbar
    NSDictionary *toolbar = nav[@"toolbarNavigation"] ?: @{};
    self.showToolbar   = [toolbar[@"enabled"] boolValue];
    self.toolbarEnabled = self.showToolbar;
    self.toolbarItems  = toolbar[@"items"] ?: @[];
    self.toolbarRegexes = [self parseToolbarRegexes:toolbar[@"regexes"]];
    NSString *visByPages = toolbar[@"visibilityByPages"];
    self.toolbarVisibilityByPages =
        [@"specificPages" isEqualToString:visByPages]
            ? LEANToolbarVisibilityByPagesSpecific
            : LEANToolbarVisibilityByPagesAllPages;
    NSString *visByBack = toolbar[@"visibilityByBackButton"];
    self.toolbarVisibilityByBackButton =
        [@"backButtonActive" isEqualToString:visByBack]
            ? LEANToolbarVisibilityByBackButtonActive
            : LEANToolbarVisibilityByBackButtonAlways;
    
    // Action navigation
    NSDictionary *actionCfg = nav[@"actionConfig"] ?: @{};
    self.actions         = [self parseActionsDict:actionCfg[@"actions"]];
    self.actionSelection = [self parseActionSelection:actionCfg[@"actionSelection"]];
    
    // ── Styling ───────────────────────────────────────────────────────────────
    self.iosTheme                 = styling[@"iosTheme"] ?: @"default";
    self.iosDarkMode              = styling[@"iosDarkMode"] ?: @"auto";
    self.iosStatusBarStyle        = styling[@"iosStatusBarStyle"] ?: @"auto";
    self.iosEnableBlurInStatusBar = [styling[@"iosEnableBlurInStatusBar"] boolValue];
    self.iosEnableOverlayInStatusBar = [styling[@"iosEnableOverlayInStatusBar"] boolValue];
    self.disableAnimations        = [styling[@"disableAnimations"] boolValue];
    
    id fvw = styling[@"forceViewportWidth"];
    self.forceViewportWidth = (fvw != nil && fvw != [NSNull null]) ? (NSNumber *)fvw : nil;
    
    id ptz = styling[@"pinchToZoom"];
    self.pinchToZoom = (ptz != nil && ptz != [NSNull null]) ? [ptz boolValue] : YES;
    
    id dynType = styling[@"iosDynamicType"];
    self.dynamicTypeEnabled = (dynType != nil && dynType != [NSNull null]) ? [dynType boolValue] : NO;
    
    self.transparentNavBar  = styling[@"iosTransparentNavBar"] != nil ? [styling[@"iosTransparentNavBar"] boolValue] : YES;
    self.hideNavBarOnScroll = [styling[@"iosHideNavBarOnScroll"] boolValue];
    self.hideTabBarOnScroll = [styling[@"iosHideTabBarOnScroll"] boolValue];
    self.showNavigationBar  = [styling[@"showNavigationBar"] boolValue];
    
    // Navigation title image
    BOOL navTitleImageEnabled = [styling[@"navigationTitleImage"] boolValue];
    self.isNavigationTitleImage = navTitleImageEnabled;
    // navigationTitleIcon is loaded lazily when accessed
    
    // Sidebar font
    NSString *fontName = styling[@"iosSidebarFont"];
    if ([fontName isKindOfClass:[NSString class]] &&
        ![@"Default" isEqualToString:fontName] &&
        fontName.length > 0) {
        self.iosSidebarFont = [UIFont fontWithName:fontName size:[UIFont systemFontSize]];
    }
    
    id delay = styling[@"transitionInteractiveDelayMax"];
    self.interactiveDelay = (delay != nil && delay != [NSNull null]) ? delay : @0.2;
    
    id animDur = styling[@"menuAnimationDuration"];
    self.menuAnimationDuration = (animDur != nil && animDur != [NSNull null]) ? animDur : @0.15;
    
    id alpha = styling[@"hideWebviewAlpha"];
    self.hideWebviewAlpha = (alpha != nil && alpha != [NSNull null]) ? alpha : @0.5;
    
    self.iosAutoHideHomeIndicator = NO;
    self.iosFullScreenWebview     = NO;
    
    // Sidebar icon strings
    self.sidebarMenuIcon = styling[@"sidebarMenuIcon"] ?: @"fas fa-bars";
    
    // ── Context menu ──────────────────────────────────────────────────────────
    self.contextMenuEnabled      = [ctx[@"enabled"] boolValue];
    NSArray *linkActions = ctx[@"linkActions"];
    self.contextMenuLinkActions = [linkActions isKindOfClass:[NSArray class]] ? linkActions : @[@"copyLink", @"openExternal"];
    
    // ── Development tools ──────────────────────────────────────────────────
    self.enableWebConsoleLogs = [devTools[@"enableWebConsoleLogs"] boolValue];
    
    // ── Permissions / string viewport ─────────────────────────────────────────
    self.stringViewport = nil; // determined at runtime by zoom settings
    
    // Custom scripts/CSS – check for files in the bundle
    self.hasCustomCSS     = [[NSBundle mainBundle] pathForResource:@"customCSS" ofType:@"css"] != nil;
    self.hasIosCustomCSS  = [[NSBundle mainBundle] pathForResource:@"iosCustomCSS" ofType:@"css"] != nil;
    self.hasCustomJS      = [[NSBundle mainBundle] pathForResource:@"customJS" ofType:@"js"] != nil;
    self.hasIosCustomJS   = [[NSBundle mainBundle] pathForResource:@"iosCustomJS" ofType:@"js"] != nil;
    
    // Initial zoom from styling
    id initialZoom = styling[@"initialZoom"];
    self.initialWebviewZoom = (initialZoom != nil && initialZoom != [NSNull null]) ? initialZoom : nil;
    
    // Native bridge URLs – compile regex predicates from string patterns
    NSArray *bridgeUrls = general[@"nativeBridgeUrls"];
    if ([bridgeUrls isKindOfClass:[NSArray class]] && bridgeUrls.count > 0) {
        NSMutableArray *compiled = [NSMutableArray array];
        for (id urlPattern in bridgeUrls) {
            if (![urlPattern isKindOfClass:[NSString class]]) continue;
            @try {
                [compiled addObject:[NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlPattern]];
            }
            @catch (NSException *ex) {
                NSLog(@"GoNativeAppConfig: bad nativeBridgeUrl pattern %@ – %@", urlPattern, ex);
            }
        }
        self.nativeBridgeUrls = [compiled copy];
    } else {
        self.nativeBridgeUrls = @[];
    }
    
    // ── Misc defaults ─────────────────────────────────────────────────────────
    self.listeners              = @{};
    self.webviewPools           = @[];
    self.registrationEndpoints  = @[];
    self.showShareButton        = NO;
    self.windowOpenHideNavbar   = NO;
    self.showKeyboardAccessoryView = NO;
    self.useWebpageTitle        = YES;
    self.postLoadJavascript     = nil;
    self.disableDocumentOpenWith = NO;
    self.profilePickerJS        = nil;
    self.keepScreenOn           = NO;
    self.facebookEnabled        = NO;
    
    // ATT tracking
    id attConsent = perms[@"iOSRequestATTConsentOnLoad"];
    self.iOSRequestATTConsentOnLoad = (attConsent != nil && attConsent != [NSNull null]) ? [attConsent boolValue] : NO;
    
    // keepScreenOn
    id kso = general[@"keepScreenOn"];
    self.keepScreenOn = (kso != nil && kso != [NSNull null]) ? [kso boolValue] : NO;
    
    self.configError = nil;
}

// ── Sidebar menu parsing ──────────────────────────────────────────────────────
/// Converts the menus array from appConfig.json into a status→items dictionary.
- (NSDictionary *)parseSidebarMenus:(nullable NSArray *)menusArray {
    if (![menusArray isKindOfClass:[NSArray class]]) return @{};

    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSDictionary *menu in menusArray) {
        if (![menu isKindOfClass:[NSDictionary class]]) continue;
        NSString *name = menu[@"name"];
        NSArray  *items = menu[@"items"];
        if (![name isKindOfClass:[NSString class]]) continue;

        NSMutableArray *processed = [NSMutableArray array];
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            NSMutableDictionary *entry = [item mutableCopy];
            if (!entry[@"subLinks"]) entry[@"subLinks"] = @[];
            if (!entry[@"isGrouping"]) entry[@"isGrouping"] = @([(NSArray *)entry[@"subLinks"] count] > 0);
            [processed addObject:[entry copy]];
        }
        result[name] = [processed copy];
    }
    return [result copy];
}

// ── Tab navigation ────────────────────────────────────────────────────────────
- (void)parseTabNavigation:(NSDictionary *)tabNav {
    if (![tabNav[@"active"] boolValue]) {
        self.tabMenus     = nil;
        self.tabMenuIDs   = nil;
        self.tabMenuRegexes = nil;
        return;
    }

    NSArray *tabMenusArr = tabNav[@"tabMenus"] ?: @[];
    NSMutableDictionary *menuMap     = [NSMutableDictionary dictionary];
    NSMutableArray      *menuIDs     = [NSMutableArray array];
    NSMutableArray      *menuRegexes = [NSMutableArray array];

    for (NSDictionary *menu in tabMenusArr) {
        if (![menu isKindOfClass:[NSDictionary class]]) continue;
        NSString *menuID = menu[@"id"] ?: menu[@"name"];
        NSArray  *items  = menu[@"items"];
        if (![menuID isKindOfClass:[NSString class]]) continue;
        menuMap[menuID] = [items isKindOfClass:[NSArray class]] ? items : @[];
    }

    // tabSelectionConfig maps URL regexes to menu IDs
    NSArray *selCfg = tabNav[@"tabSelectionConfig"] ?: @[];
    for (NSDictionary *entry in selCfg) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSString *regex  = entry[@"regex"];
        NSString *menuID = entry[@"id"] ?: entry[@"tabMenu"];
        if (![regex isKindOfClass:[NSString class]]) continue;
        @try {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
            [menuIDs     addObject:menuID ?: @""];
            [menuRegexes addObject:p];
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: bad tabSelectionConfig regex %@ – %@", regex, ex);
        }
    }

    self.tabMenus      = [menuMap copy];
    self.tabMenuIDs    = [menuIDs copy];
    self.tabMenuRegexes= [menuRegexes copy];
}

// ── Toolbar regexes ───────────────────────────────────────────────────────────
- (NSArray *)parseToolbarRegexes:(nullable NSArray *)regexesArr {
    if (![regexesArr isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *entry in regexesArr) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSString *regexStr = entry[@"regex"];
        if (![regexStr isKindOfClass:[NSString class]]) continue;
        @try {
            RegexEnabled *re  = [[RegexEnabled alloc] init];
            re.regex   = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
            re.enabled = entry[@"enabled"] ? [entry[@"enabled"] boolValue] : YES;
            [result addObject:re];
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: bad toolbar regex %@ – %@", regexStr, ex);
        }
    }
    return [result copy];
}

// ── Action parsing ────────────────────────────────────────────────────────────
- (NSDictionary *)parseActionsDict:(nullable NSArray *)actionsArr {
    if (![actionsArr isKindOfClass:[NSArray class]]) return @{};
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (NSDictionary *action in actionsArr) {
        if (![action isKindOfClass:[NSDictionary class]]) continue;
        NSString *ident = action[@"id"];
        if ([ident isKindOfClass:[NSString class]]) {
            result[ident] = action;
        }
    }
    return [result copy];
}

- (NSArray *)parseActionSelection:(nullable NSArray *)selectionArr {
    if (![selectionArr isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *result = [NSMutableArray array];
    for (NSDictionary *entry in selectionArr) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSString *regexStr = entry[@"regex"];
        if (![regexStr isKindOfClass:[NSString class]]) continue;
        @try {
            ActionSelection *sel = [[ActionSelection alloc] init];
            sel.regex      = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
            sel.identifier = entry[@"id"];
            [result addObject:sel];
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: bad actionSelection regex %@ – %@", regexStr, ex);
        }
    }
    return [result copy];
}

// ── User Agent ────────────────────────────────────────────────────────────────
- (void)buildUserAgent {
    NSDictionary *general = self.rawConfig[@"general"] ?: @{};
    NSString *forceUA = general[@"iosForceUserAgent"];
    NSString *addUA   = general[@"iosUserAgentAdd"];

    if ([forceUA isKindOfClass:[NSString class]] && forceUA.length > 0) {
        self.userAgent = forceUA;
        self.userAgentReady = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:kGoNativeAppConfigNotificationUserAgentReady object:self];
        return;
    }

    // Build user agent asynchronously using WKWebView (required to get the real WebKit UA)
    dispatch_async(dispatch_get_main_queue(), ^{
        WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
        WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:cfg];
        [wv evaluateJavaScript:@"navigator.userAgent" completionHandler:^(id result, NSError *error) {
            NSString *base = [result isKindOfClass:[NSString class]] ? result : @"";

            if ([addUA isKindOfClass:[NSString class]] && addUA.length > 0) {
                base = [base stringByAppendingFormat:@" %@", addUA];
            }

            self.userAgent = base;
            self.userAgentReady = YES;
            [[NSNotificationCenter defaultCenter] postNotificationName:kGoNativeAppConfigNotificationUserAgentReady object:self];
        }];
    });
}

// ── userAgentForUrl: ──────────────────────────────────────────────────────────
- (nullable NSString *)userAgentForUrl:(nullable NSURL *)url {
    if (!url) return self.userAgent;

    NSString *urlString = url.absoluteString;
    for (NSDictionary *rule in self.userAgentRegexes) {
        NSString *regexStr = rule[@"regex"];
        NSString *ua       = rule[@"userAgent"];
        if (![regexStr isKindOfClass:[NSString class]] || ![ua isKindOfClass:[NSString class]]) continue;
        @try {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
            if ([p evaluateWithObject:urlString]) {
                return ua;
            }
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: bad userAgentRegex %@ – %@", regexStr, ex);
        }
    }
    return self.userAgent;
}

// ── Regex rules ───────────────────────────────────────────────────────────────
- (void)initializeRegexRules:(NSArray * _Nullable * _Nonnull)regexRulesArray {
    NSDictionary *nav = self.rawConfig[@"navigation"] ?: @{};
    NSDictionary *rieConfig = nav[@"regexInternalExternal"] ?: @{};
    NSArray *rules = rieConfig[@"rules"];
    *regexRulesArray = [self compileRegexRules:rules];
}

- (void)setNewRegexRules:(nullable NSArray *)rules
         regexRulesArray:(NSArray * _Nullable * _Nonnull)regexRulesArray {
    *regexRulesArray = [self compileRegexRules:rules];
}

- (NSDictionary *)getRegexRuleForURL:(NSString *)urlString rules:(nullable NSArray *)regexRules {
    if (![regexRules isKindOfClass:[NSArray class]]) {
        return @{@"matches": @NO};
    }
    for (NSDictionary *rule in regexRules) {
        NSPredicate *pred = rule[@"predicate"];
        if (![pred isKindOfClass:[NSPredicate class]]) continue;
        @try {
            if ([pred evaluateWithObject:urlString]) {
                return @{@"matches": @YES, @"mode": rule[@"mode"] ?: @"external"};
            }
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: error evaluating regex rule – %@", ex);
        }
    }
    return @{@"matches": @NO};
}

/// Compiles an array of rule dicts (with "regex" and "mode" keys) into dicts
/// that also carry a pre-compiled "predicate" key.
- (NSArray *)compileRegexRules:(nullable NSArray *)rules {
    if (![rules isKindOfClass:[NSArray class]]) return @[];

    NSMutableArray *compiled = [NSMutableArray array];
    for (NSDictionary *rule in rules) {
        if (![rule isKindOfClass:[NSDictionary class]]) continue;
        NSString *regexStr = rule[@"regex"];
        if (![regexStr isKindOfClass:[NSString class]]) continue;
        @try {
            NSPredicate *p = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regexStr];
            NSMutableDictionary *entry = [rule mutableCopy];
            entry[@"predicate"] = p;
            [compiled addObject:[entry copy]];
        }
        @catch (NSException *ex) {
            NSLog(@"GoNativeAppConfig: bad regex rule %@ – %@", regexStr, ex);
        }
    }
    return [compiled copy];
}

@end
