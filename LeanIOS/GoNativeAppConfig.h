//
//  GoNativeAppConfig.h
//  MedianIOS
//
//  Local implementation replacing the GoNativeCore pod dependency.
//  Reads configuration from the bundled appConfig.json file.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// ─── Notification constants ───────────────────────────────────────────────────
extern NSString * const kGoNativeAppConfigNotificationUserAgentReady;
extern NSString * const kGoNativeCoreDeviceDidShake;
extern NSString * const kLEANAppConfigNotificationProcessedMenu;
extern NSString * const kLEANAppConfigNotificationProcessedSegmented;
extern NSString * const kLEANAppConfigNotificationProcessedTabNavigation;
extern NSString * const kLEANAppConfigNotificationProcessedNavigationTitles;
extern NSString * const kLEANAppConfigNotificationProcessedNavigationLevels;
extern NSString * const kLEANAppConfigNotificationProcessedWebViewPools;
extern NSString * const kLEANAppConfigNotificationAppTrackingStatusChanged;
extern NSString * const MEDIAN_KEYBOARD_EVENT_LISTENER;

// ─── Enums ────────────────────────────────────────────────────────────────────
typedef NS_ENUM(NSInteger, LEANToolbarVisibilityByPages) {
    LEANToolbarVisibilityByPagesAllPages = 0,
    LEANToolbarVisibilityByPagesSpecific = 1
};

typedef NS_ENUM(NSInteger, LEANToolbarVisibilityByBackButton) {
    LEANToolbarVisibilityByBackButtonAlways = 0,
    LEANToolbarVisibilityByBackButtonActive = 1
};

// ─── Helper classes ───────────────────────────────────────────────────────────

/// A predicate/enabled pair used for regex-based visibility rules.
@interface RegexEnabled : NSObject
@property (nonatomic, strong, nullable) NSPredicate *regex;
@property (nonatomic, assign) BOOL enabled;
@end

/// Binds a URL-matching regex to an action-menu identifier.
@interface ActionSelection : NSObject
@property (nonatomic, strong, nullable) NSPredicate *regex;
@property (nonatomic, copy, nullable) NSString *identifier;
@end

// ─── Main configuration class ─────────────────────────────────────────────────
@interface GoNativeAppConfig : NSObject

/// Returns the singleton instance, parsing appConfig.json on first call.
+ (instancetype)sharedAppConfig;

/// Swift-compatible alias for sharedAppConfig.
+ (instancetype)shared;

// General
@property (nonatomic, copy, nullable)   NSString     *appName;
@property (nonatomic, strong, nullable) NSURL        *initialURL;
@property (nonatomic, copy, nullable)   NSString     *initialHost;
@property (nonatomic, copy, nullable)   NSString     *publicKey;
@property (nonatomic, assign)           BOOL          injectMedianJS;
@property (nonatomic, assign)           NSUInteger    forceSessionCookieExpiry;
@property (nonatomic, copy, nullable)   NSArray      *replaceStrings;
@property (nonatomic, assign)           BOOL          enableWindowOpen;
@property (nonatomic, copy, nullable)   NSDictionary *customHeaders;
@property (nonatomic, copy, nullable)   NSString     *userAgent;
@property (nonatomic, assign)           BOOL          userAgentReady;
@property (nonatomic, assign)           BOOL          useWKWebView;
@property (nonatomic, assign)           BOOL          disableEventRecorder;
@property (nonatomic, copy, nullable)   NSArray      *webviewPools;
@property (nonatomic, copy, nullable)   NSDictionary *listeners;

// Navigation
@property (nonatomic, assign)           BOOL          pullToRefresh;
@property (nonatomic, assign)           BOOL          iosShowOfflinePage;
@property (nonatomic, strong, nullable) NSNumber     *iosConnectionOfflineTime;
@property (nonatomic, assign)           BOOL          swipeGestures;
@property (nonatomic, assign)           NSInteger     maxWindows;
@property (nonatomic, assign)           BOOL          maxWindowsAutoClose;
@property (nonatomic, copy, nullable)   NSDictionary *menus;
@property (nonatomic, copy, nullable)   NSDictionary *tabMenus;
@property (nonatomic, copy, nullable)   NSArray      *tabMenuIDs;
@property (nonatomic, copy, nullable)   NSArray      *tabMenuRegexes;
@property (nonatomic, copy, nullable)   NSArray      *navStructureLevels;
@property (nonatomic, copy, nullable)   NSArray      *navTitles;
@property (nonatomic, copy, nullable)   NSArray      *segmentedControlItems;
@property (nonatomic, assign)           BOOL          showNavigationMenu;
@property (nonatomic, copy, nullable)   NSDictionary *redirects;

// Toolbar
@property (nonatomic, assign)           BOOL                         toolbarEnabled;
@property (nonatomic, assign)           BOOL                         showToolbar;
@property (nonatomic, copy, nullable)   NSArray                     *toolbarItems;
@property (nonatomic, copy, nullable)   NSArray                     *toolbarRegexes;
@property (nonatomic, assign)           LEANToolbarVisibilityByPages toolbarVisibilityByPages;
@property (nonatomic, assign)           LEANToolbarVisibilityByBackButton toolbarVisibilityByBackButton;

// Actions
@property (nonatomic, copy, nullable)   NSArray      *actionSelection;
@property (nonatomic, copy, nullable)   NSDictionary *actions;

// Login detection
@property (nonatomic, strong, nullable) NSURL        *loginDetectionURL;
@property (nonatomic, copy, nullable)   NSArray      *loginDetectRegexes;
@property (nonatomic, copy, nullable)   NSArray      *loginDetectLocations;
@property (nonatomic, strong, nullable) NSURL        *loginURL;
@property (nonatomic, strong, nullable) NSURL        *signupURL;

// User identity
@property (nonatomic, copy, nullable)   NSString     *userIdRegex;

// Styling
@property (nonatomic, copy, nullable)   NSString     *iosTheme;
@property (nonatomic, copy, nullable)   NSString     *iosDarkMode;
@property (nonatomic, copy, nullable)   NSString     *iosStatusBarStyle;
@property (nonatomic, assign)           BOOL          iosEnableBlurInStatusBar;
@property (nonatomic, assign)           BOOL          iosEnableOverlayInStatusBar;
@property (nonatomic, assign)           BOOL          disableAnimations;
@property (nonatomic, strong, nullable) NSNumber     *forceViewportWidth;
@property (nonatomic, assign)           BOOL          pinchToZoom;
@property (nonatomic, assign)           BOOL          dynamicTypeEnabled;
@property (nonatomic, assign)           BOOL          transparentNavBar;
@property (nonatomic, assign)           BOOL          hideNavBarOnScroll;
@property (nonatomic, assign)           BOOL          hideTabBarOnScroll;
@property (nonatomic, assign)           BOOL          showNavigationBar;
@property (nonatomic, assign)           BOOL          isNavigationTitleImage;
@property (nonatomic, strong, nullable) UIImage      *navigationTitleIcon;
@property (nonatomic, strong, nullable) UIFont       *iosSidebarFont;
@property (nonatomic, strong, nullable) NSNumber     *interactiveDelay;
@property (nonatomic, strong, nullable) NSNumber     *menuAnimationDuration;
@property (nonatomic, strong, nullable) NSNumber     *hideWebviewAlpha;
@property (nonatomic, assign)           BOOL          iosAutoHideHomeIndicator;
@property (nonatomic, assign)           BOOL          iosFullScreenWebview;

// Icons / sidebar
@property (nonatomic, strong, nullable) UIImage      *sidebarIcon;
@property (nonatomic, strong, nullable) UIImage      *appIcon;
@property (nonatomic, copy, nullable)   NSString     *sidebarMenuIcon;

// Features
@property (nonatomic, assign)           BOOL          showShareButton;
@property (nonatomic, assign)           BOOL          windowOpenHideNavbar;
@property (nonatomic, assign)           BOOL          showKeyboardAccessoryView;
@property (nonatomic, assign)           BOOL          useWebpageTitle;
@property (nonatomic, copy, nullable)   NSString     *postLoadJavascript;
@property (nonatomic, assign)           BOOL          disableDocumentOpenWith;
@property (nonatomic, assign)           BOOL          enableWebConsoleLogs;
@property (nonatomic, copy, nullable)   NSString     *profilePickerJS;
@property (nonatomic, copy, nullable)   NSString     *stringViewport;
@property (nonatomic, assign)           BOOL          keepScreenOn;
@property (nonatomic, assign)           BOOL          facebookEnabled;
@property (nonatomic, assign)           BOOL          iOSRequestATTConsentOnLoad;
@property (nonatomic, strong, nullable) NSError      *configError;

// Custom scripts / CSS
@property (nonatomic, assign)           BOOL          hasCustomCSS;
@property (nonatomic, assign)           BOOL          hasIosCustomCSS;
@property (nonatomic, assign)           BOOL          hasCustomJS;
@property (nonatomic, assign)           BOOL          hasIosCustomJS;
@property (nonatomic, strong, nullable) NSNumber     *initialWebviewZoom;
@property (nonatomic, copy, nullable)   NSArray      *nativeBridgeUrls;

// Registration
@property (nonatomic, copy, nullable)   NSArray      *registrationEndpoints;

// Context menu
@property (nonatomic, assign)           BOOL          contextMenuEnabled;
@property (nonatomic, copy, nullable)   NSArray      *contextMenuLinkActions;

// ─── Methods ──────────────────────────────────────────────────────────────────

/// Returns a per-URL custom user-agent, or the default one if no rule matches.
- (nullable NSString *)userAgentForUrl:(nullable NSURL *)url;

/// Populates *regexRulesArray with the compiled regex rules from appConfig.json.
- (void)initializeRegexRules:(NSArray * _Nullable * _Nonnull)regexRulesArray;

/// Replaces the current regex rules with a new set supplied at runtime.
- (void)setNewRegexRules:(nullable NSArray *)rules
         regexRulesArray:(NSArray * _Nullable * _Nonnull)regexRulesArray;

/// Evaluates urlString against regexRules; returns a dict with "matches" (BOOL)
/// and "mode" (NSString) keys.
- (NSDictionary *)getRegexRuleForURL:(NSString *)urlString
                               rules:(nullable NSArray *)regexRules;

@end

NS_ASSUME_NONNULL_END
