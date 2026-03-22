//
//  LEANAuthViewController.h
//  LeanIOS
//
//  Authentication view controller — presents the web-based login/signup
//  page in a modal sheet and notifies callers when auth state changes.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LEANAuthMode) {
    LEANAuthModeLogin,
    LEANAuthModeSignup,
};

@class LEANAuthViewController;

@protocol LEANAuthViewControllerDelegate <NSObject>
@optional
/// Called when the user successfully authenticates.
- (void)authViewControllerDidAuthenticate:(LEANAuthViewController *)controller;
/// Called when the user dismisses the sheet without authenticating.
- (void)authViewControllerDidCancel:(LEANAuthViewController *)controller;
@end

@interface LEANAuthViewController : UIViewController

/// The mode (login or signup) to present.
@property (nonatomic, assign) LEANAuthMode authMode;

/// Optional delegate to receive authentication events.
@property (nonatomic, weak, nullable) id<LEANAuthViewControllerDelegate> delegate;

/// Designated initialiser.
- (instancetype)initWithAuthMode:(LEANAuthMode)mode
                        delegate:(nullable id<LEANAuthViewControllerDelegate>)delegate;

/// Present this controller modally from the given view controller.
+ (void)presentFromViewController:(UIViewController *)presenter
                         authMode:(LEANAuthMode)mode
                         delegate:(nullable id<LEANAuthViewControllerDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
