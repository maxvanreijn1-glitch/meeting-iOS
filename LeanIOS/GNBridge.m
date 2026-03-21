//
//  GNBridge.m
//  MedianIOS
//
//  Stub implementation of GNBridge.
//

#import "GNBridge.h"

@implementation GNBridge

- (nullable id<GNController>)getControllerForKey:(NSString *)key runner:(nullable id)runner {
    return nil;
}

- (void)runnerDidLoad:(nullable id)runner {}
- (void)runnerWillAppear:(nullable id)runner {}
- (void)runnerWillDisappear:(nullable id)runner {}
- (void)hideWebViewWithRunner:(nullable id)runner {}
- (void)switchToWebView:(nullable UIView *)webView withRunner:(nullable id)runner {}
- (void)runner:(nullable id)runner willTransitionToSize:(CGSize)size
    withTransitionCoordinator:(nullable id<UIViewControllerTransitionCoordinator>)coordinator {}

- (NSArray *)getInitialUrlQueryItems {
    return @[];
}

- (BOOL)runner:(nullable id)runner
    shouldLoadRequestWithURL:(nullable NSURL *)url
                    withData:(nullable NSDictionary *)data {
    return YES;
}

- (BOOL)webView:(nullable WKWebView *)webView shouldDownloadUrl:(nullable NSURL *)url {
    return NO;
}

- (void)webView:(nullable WKWebView *)webView handleURL:(nullable NSURL *)url {}
- (void)webView:(nullable WKWebView *)webView
    didFinishNavigation:(nullable WKNavigation *)navigation
             withRunner:(nullable id)runner {}

- (void)loadUserScriptsForContentController:(nullable WKUserContentController *)controller {}

- (void)application:(UIApplication *)application
    didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {}

@end
