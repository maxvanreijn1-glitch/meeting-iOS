//
//  LEANLoginManager.m
//  LeanIOS
//
//  Created by Weiyin He on 2/12/14.
// Copyright (c) 2014 GoNative.io LLC. All rights reserved.
//

#import "LEANLoginManager.h"
#import "LEANUtilities.h"
#import "NSURL+LEANUtilities.h"
#import "LEANUrlInspector.h"
#import <WebKit/WebKit.h>

static const NSTimeInterval kLoginCheckTimeout = 15.0;
static const NSTimeInterval kLoginRetryDelay   = 3.0;
static const NSUInteger     kLoginMaxRetries   = 3;

@interface LEANLoginManager () <NSURLSessionDataDelegate, WKNavigationDelegate>
@property BOOL isChecking;
@property NSURLSession *session;
@property NSURLSessionTask *task;
@property WKWebView *wkWebview;
@property NSUInteger retryCount;
@property NSTimer *timeoutTimer;
@end


@implementation LEANLoginManager

+ (LEANLoginManager *)sharedManager
{
    static LEANLoginManager *sharedManager;
    
    @synchronized(self)
    {
        if (!sharedManager){
            sharedManager = [[LEANLoginManager alloc] init];
            
            sharedManager.loggedIn  = NO;
            sharedManager.retryCount = 0;

            NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
            config.timeoutIntervalForRequest  = kLoginCheckTimeout;
            config.timeoutIntervalForResource = kLoginCheckTimeout * 2;
            sharedManager.session = [NSURLSession sessionWithConfiguration:config
                                                                   delegate:sharedManager
                                                              delegateQueue:nil];
            [sharedManager checkLogin];
        }
        return sharedManager;
    }
}


- (void)statusUpdated
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kLEANLoginManagerNotificationName object:self];
    });
}

- (void)setStatus:(NSString *)newStatus loggedIn:(BOOL)loggedIn
{
    if (!newStatus) {
        newStatus = loggedIn ? @"loggedIn" : @"default";
    }
    
    BOOL changed = NO;
    if (loggedIn != self.loggedIn || ![newStatus isEqualToString:self.loginStatus]) {
        changed = YES;
    }
    
    self.loggedIn    = loggedIn;
    self.loginStatus = newStatus;
    self.retryCount  = 0;
    [self statusUpdated];
    
    if (changed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kLEANLoginManagerStatusChangedNotification object:self];
        });
    }
}

-(void) checkLogin
{
    [self.task cancel];
    self.task = nil;
    [self.wkWebview stopLoading];
    [self cancelTimeoutTimer];
    
    NSURL *url = [GoNativeAppConfig sharedAppConfig].loginDetectionURL;
    if (!url) {
        self.loggedIn = NO;
        [self performSelector:@selector(statusUpdated) withObject:self afterDelay:1.0];
        return;
    }
    
    self.isChecking = YES;
    
    // Start a watchdog timer so a hung request doesn't block login state forever.
    self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:kLoginCheckTimeout
                                                         target:self
                                                       selector:@selector(handleTimeout)
                                                       userInfo:nil
                                                        repeats:NO];

    if ([GoNativeAppConfig sharedAppConfig].useWKWebView) {
        if (!self.wkWebview) {
            WKWebViewConfiguration *config = [[NSClassFromString(@"WKWebViewConfiguration") alloc] init];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            config.processPool = [LEANUtilities wkProcessPool];
#pragma clang diagnostic pop
            self.wkWebview = [[NSClassFromString(@"WKWebView") alloc] initWithFrame:CGRectZero configuration:config];
            self.wkWebview.navigationDelegate = self;
        }
        NSURLRequest *req = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:kLoginCheckTimeout];
        [self.wkWebview loadRequest:req];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
                                                               cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                           timeoutInterval:kLoginCheckTimeout];
        NSString *userAgent = [[NSUserDefaults standardUserDefaults] stringForKey:@"UserAgent"];
        if (userAgent.length) {
            [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        }
        [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
        [request setValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
        
        self.task = [self.session dataTaskWithRequest:request];
        [self.task resume];
    }
}

-(void) checkIfNotAlreadyChecking
{
    if (!self.isChecking) {
        [self checkLogin];
    }
}

- (void)finishedOnUrl:(NSURL*)url
{
    [self cancelTimeoutTimer];
    self.isChecking = NO;

    NSString *urlString = [url absoluteString];
    if (!urlString.length) {
        [self setStatus:@"default" loggedIn:NO];
        return;
    }
    
    // iterate through loginDetectionRegexes
    NSArray *regexes = [GoNativeAppConfig sharedAppConfig].loginDetectRegexes;
    for (NSUInteger i = 0; i < [regexes count]; i++) {
        NSPredicate *predicate = regexes[i];
        if (![predicate isKindOfClass:[NSPredicate class]]) {
            continue;
        }
        BOOL matches = NO;
        @try {
            matches = [predicate evaluateWithObject:urlString];
        }
        @catch (NSException* exception) {
            NSLog(@"LEANLoginManager: Error in login detection regex at index %lu: %@", (unsigned long)i, exception);
        }

        if (matches) {
            id entry = [GoNativeAppConfig sharedAppConfig].loginDetectLocations[i];
            if ([entry isKindOfClass:[NSDictionary class]]) {
                [self setStatus:entry[@"status"] loggedIn:[entry[@"loggedIn"] boolValue]];
            }
            return;
        }
    }

    // No regex matched — treat as logged-out default.
    [self setStatus:@"default" loggedIn:NO];
}

- (void)failedWithError:(NSError*)error
{
    [self cancelTimeoutTimer];
    self.isChecking = NO;

    if (error && error.code == NSURLErrorCancelled) {
        // Deliberate cancellation — do not retry or change login state.
        return;
    }

    NSLog(@"LEANLoginManager: check failed (attempt %lu): %@",
          (unsigned long)(self.retryCount + 1), error.localizedDescription);

    if (self.retryCount < kLoginMaxRetries) {
        self.retryCount++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(kLoginRetryDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            [self checkLogin];
        });
    } else {
        self.retryCount = 0;
        [self setStatus:@"default" loggedIn:NO];
    }
}

- (void)handleTimeout
{
    NSLog(@"LEANLoginManager: login check timed out");
    [self.task cancel];
    self.task = nil;
    [self.wkWebview stopLoading];
    [self failedWithError:[NSError errorWithDomain:NSURLErrorDomain
                                              code:NSURLErrorTimedOut
                                          userInfo:nil]];
}

- (void)cancelTimeoutTimer
{
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
}

- (void)stopChecking
{
    [self cancelTimeoutTimer];
    if (self.task) {
        [self.task cancel];
        self.task = nil;
    }
    
    if (self.wkWebview) {
        [self.wkWebview stopLoading];
    }
    self.isChecking  = NO;
    self.retryCount  = 0;
}

#pragma mark URL Session Delegate
-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error) {
        [self failedWithError:error];
    }
}

-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self cancelTimeoutTimer];
    self.isChecking = NO;
    [self finishedOnUrl:response.URL];
    completionHandler(NSURLSessionResponseCancel);
}

# pragma mark WebView navigation delegate
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self cancelTimeoutTimer];
    self.isChecking = NO;
    [self finishedOnUrl:webView.URL];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self failedWithError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [self failedWithError:error];
}


@end
