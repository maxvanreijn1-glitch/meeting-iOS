//
//  LEANAuthViewController.m
//  LeanIOS
//
//  Authentication view controller — presents the web-based login/signup
//  page in a modal sheet and notifies callers when auth state changes.
//

#import "LEANAuthViewController.h"
#import "LEANLoginManager.h"
#import "GoNativeAppConfig.h"

@interface LEANAuthViewController () <WKNavigationDelegate>

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) NSTimer *progressTimer;

@end

@implementation LEANAuthViewController

#pragma mark - Factory

+ (void)presentFromViewController:(UIViewController *)presenter
                         authMode:(LEANAuthMode)mode
                         delegate:(nullable id<LEANAuthViewControllerDelegate>)delegate
{
    LEANAuthViewController *vc = [[LEANAuthViewController alloc] initWithAuthMode:mode
                                                                         delegate:delegate];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [presenter presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Init

- (instancetype)initWithAuthMode:(LEANAuthMode)mode
                        delegate:(nullable id<LEANAuthViewControllerDelegate>)delegate
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _authMode = mode;
        _delegate = delegate;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self setupNavigationBar];
    [self setupWebView];
    [self setupProgressView];
    [self setupSpinner];
    [self loadAuthURL];
    [self observeLoginNotifications];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.webView removeObserver:self forKeyPath:@"estimatedProgress"];
}

#pragma mark - Setup

- (void)setupNavigationBar
{
    NSString *title = (self.authMode == LEANAuthModeSignup) ? @"Sign Up" : @"Log In";
    self.title = title;

    UIBarButtonItem *cancelItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                      target:self
                                                      action:@selector(cancelTapped)];
    self.navigationItem.leftBarButtonItem = cancelItem;
}

- (void)setupWebView
{
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = [WKWebsiteDataStore defaultDataStore];

    self.webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.navigationDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;

    [self.view addSubview:self.webView];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)setupProgressView
{
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressView.trackTintColor = [UIColor clearColor];
    [self.view addSubview:self.progressView];

    [NSLayoutConstraint activateConstraints:@[
        [self.progressView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.progressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.progressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.progressView.heightAnchor constraintEqualToConstant:2.0],
    ]];
}

- (void)setupSpinner
{
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.hidesWhenStopped = YES;
    self.spinner.center = self.view.center;
    self.spinner.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin  | UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleTopMargin   | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];
}

- (void)observeLoginNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(loginStatusChanged:)
                                                 name:kLEANLoginManagerStatusChangedNotification
                                               object:nil];
}

#pragma mark - Auth URL loading

- (void)loadAuthURL
{
    GoNativeAppConfig *appConfig = [GoNativeAppConfig sharedAppConfig];
    NSURL *url = (self.authMode == LEANAuthModeSignup) ? appConfig.signupURL : appConfig.loginURL;

    if (!url) {
        url = appConfig.initialURL;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:url
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:30.0];
    [self.webView loadRequest:request];
}

#pragma mark - Actions

- (void)cancelTapped
{
    [self dismissViewControllerAnimated:YES completion:^{
        if ([self.delegate respondsToSelector:@selector(authViewControllerDidCancel:)]) {
            [self.delegate authViewControllerDidCancel:self];
        }
    }];
}

#pragma mark - Login notification

- (void)loginStatusChanged:(NSNotification *)note
{
    LEANLoginManager *manager = [LEANLoginManager sharedManager];
    if (manager.loggedIn) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dismissViewControllerAnimated:YES completion:^{
                if ([self.delegate respondsToSelector:@selector(authViewControllerDidAuthenticate:)]) {
                    [self.delegate authViewControllerDidAuthenticate:self];
                }
            }];
        });
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        float progress = (float)self.webView.estimatedProgress;
        [self.progressView setProgress:progress animated:YES];
        self.progressView.hidden = (progress >= 1.0f);
    }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self.spinner startAnimating];
    self.progressView.hidden = NO;
    [self.progressView setProgress:0.1f animated:YES];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [self.spinner stopAnimating];
    [self.progressView setProgress:1.0f animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        self.progressView.hidden = YES;
        [self.progressView setProgress:0.0f animated:NO];
    });

    // Trigger a login check whenever navigation finishes inside the auth sheet.
    [[LEANLoginManager sharedManager] checkLogin];
}

- (void)webView:(WKWebView *)webView
didFailProvisionalNavigation:(WKNavigation *)navigation
      withError:(NSError *)error
{
    [self.spinner stopAnimating];
    self.progressView.hidden = YES;
    if (error.code != NSURLErrorCancelled) {
        NSLog(@"LEANAuthViewController: navigation error: %@", error.localizedDescription);
    }
}

- (void)webView:(WKWebView *)webView
didFailNavigation:(WKNavigation *)navigation
      withError:(NSError *)error
{
    [self.spinner stopAnimating];
    self.progressView.hidden = YES;
    if (error.code != NSURLErrorCancelled) {
        NSLog(@"LEANAuthViewController: navigation failed: %@", error.localizedDescription);
    }
}

@end
