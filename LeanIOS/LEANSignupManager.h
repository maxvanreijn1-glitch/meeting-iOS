//
//  LEANSignupManager.h
//  LeanIOS
//
//  Manages the signup flow — validation helpers, profile-picker integration,
//  and post-signup state synchronisation.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted when the signup flow completes successfully.
extern NSString * const kLEANSignupManagerDidCompleteNotification;
/// Posted when signup validation fails. The notification's userInfo contains
/// @"errors" → NSArray<NSString *> of human-readable messages.
extern NSString * const kLEANSignupManagerValidationFailedNotification;

@interface LEANSignupManager : NSObject

/// Singleton accessor.
+ (instancetype)sharedManager;

/// Validate a signup form dictionary keyed on field names.
/// Returns YES when all required fields pass validation.
/// Posts kLEANSignupManagerValidationFailedNotification if there are errors.
- (BOOL)validateFields:(NSDictionary<NSString *, NSString *> *)fields;

/// Call after successful signup to sync login state and profile picker.
- (void)didCompleteSignup;

/// Returns YES when a signup URL is configured in appConfig.
- (BOOL)isSignupEnabled;

/// Returns the configured signup URL (or nil).
- (nullable NSURL *)signupURL;

@end

NS_ASSUME_NONNULL_END
