//
//  GNBridge.h
//  MedianIOS
//
//  Stub replacing the GNBridge / GNController types that were provided by
//  the GoNativeCore pod.  Plugin-based controllers are not available without
//  the pod; affected callers fall back to their native implementations.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

// ─── GNController protocol ────────────────────────────────────────────────────
/// Minimal protocol for plugin-managed view controllers.
/// Without the GoNativeCore pod, no controllers are available.
@protocol GNController <NSObject>
- (void)triggerEvent:(NSString *)eventName;
@end

// ─── GNBridge ─────────────────────────────────────────────────────────────────
/// Stub bridge – always returns nil/NO/empty so that callers
/// fall back to native UIKit implementations.
@interface GNBridge : NSObject

/// Always returns nil; native fallback paths are used.
- (nullable id<GNController>)getControllerForKey:(NSString *)key
                                          runner:(nullable id)runner;

/// No-op stub for plugin lifecycle events.
- (void)runnerDidLoad:(nullable id)runner;
- (void)runnerWillAppear:(nullable id)runner;
- (void)runnerWillDisappear:(nullable id)runner;
- (void)hideWebViewWithRunner:(nullable id)runner;
- (void)switchToWebView:(nullable UIView *)webView withRunner:(nullable id)runner;
- (void)runner:(nullable id)runner willTransitionToSize:(CGSize)size
    withTransitionCoordinator:(nullable id<UIViewControllerTransitionCoordinator>)coordinator;

/// Returns an empty array; no query items are added.
- (NSArray *)getInitialUrlQueryItems;

/// Always returns YES – allow navigation; stub does not intercept.
- (BOOL)runner:(nullable id)runner
    shouldLoadRequestWithURL:(nullable NSURL *)url
                    withData:(nullable NSDictionary *)data;

/// Always returns NO – stub does not handle downloads.
- (BOOL)webView:(nullable WKWebView *)webView
    shouldDownloadUrl:(nullable NSURL *)url;

/// No-op stubs for WKNavigationDelegate-style callbacks.
- (void)webView:(nullable WKWebView *)webView handleURL:(nullable NSURL *)url;
- (void)webView:(nullable WKWebView *)webView
    didFinishNavigation:(nullable WKNavigation *)navigation
             withRunner:(nullable id)runner;

/// No-op: loads no user scripts.
- (void)loadUserScriptsForContentController:(nullable WKUserContentController *)controller;

/// No-op: stub for push notification registration.
- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;

@end

NS_ASSUME_NONNULL_END
