//
//  LEANSignupManager.m
//  LeanIOS
//
//  Manages the signup flow — validation helpers, profile-picker integration,
//  and post-signup state synchronisation.
//

#import "LEANSignupManager.h"
#import "LEANLoginManager.h"
#import "GoNativeAppConfig.h"

NSString * const kLEANSignupManagerDidCompleteNotification        = @"co.median.ios.SignupManager.didComplete";
NSString * const kLEANSignupManagerValidationFailedNotification   = @"co.median.ios.SignupManager.validationFailed";

// ─── Field-name constants ────────────────────────────────────────────────────

static NSString * const kFieldEmail     = @"email";
static NSString * const kFieldPassword  = @"password";
static NSString * const kFieldFirstName = @"firstName";
static NSString * const kFieldLastName  = @"lastName";

// Minimum acceptable password length.
static const NSUInteger kMinPasswordLength = 8;

@implementation LEANSignupManager

#pragma mark - Singleton

+ (instancetype)sharedManager
{
    static LEANSignupManager *sharedManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[LEANSignupManager alloc] init];
    });
    return sharedManager;
}

#pragma mark - Public API

- (BOOL)isSignupEnabled
{
    return [GoNativeAppConfig sharedAppConfig].signupURL != nil;
}

- (nullable NSURL *)signupURL
{
    return [GoNativeAppConfig sharedAppConfig].signupURL;
}

- (BOOL)validateFields:(NSDictionary<NSString *, NSString *> *)fields
{
    NSMutableArray<NSString *> *errors = [NSMutableArray array];

    // Email
    NSString *email = [fields[kFieldEmail] stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!email.length) {
        [errors addObject:NSLocalizedString(@"Email is required.", nil)];
    } else if (![self isValidEmail:email]) {
        [errors addObject:NSLocalizedString(@"Please enter a valid email address.", nil)];
    }

    // Password
    NSString *password = fields[kFieldPassword];
    if (!password.length) {
        [errors addObject:NSLocalizedString(@"Password is required.", nil)];
    } else if (password.length < kMinPasswordLength) {
        [errors addObject:[NSString stringWithFormat:
                           NSLocalizedString(@"Password must be at least %lu characters.", nil),
                           (unsigned long)kMinPasswordLength]];
    }

    // First name (optional but validated when present)
    NSString *firstName = [fields[kFieldFirstName] stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (firstName.length && firstName.length < 2) {
        [errors addObject:NSLocalizedString(@"First name must be at least 2 characters.", nil)];
    }

    // Last name (optional but validated when present)
    NSString *lastName = [fields[kFieldLastName] stringByTrimmingCharactersInSet:
                           [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (lastName.length && lastName.length < 2) {
        [errors addObject:NSLocalizedString(@"Last name must be at least 2 characters.", nil)];
    }

    if (errors.count) {
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kLEANSignupManagerValidationFailedNotification
                          object:self
                        userInfo:@{@"errors": [errors copy]}];
        return NO;
    }
    return YES;
}

- (void)didCompleteSignup
{
    // Trigger a login check so the rest of the app picks up the new session.
    [[LEANLoginManager sharedManager] checkLogin];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter]
            postNotificationName:kLEANSignupManagerDidCompleteNotification
                          object:self];
    });
}

#pragma mark - Private helpers

/// Basic RFC 5322-compatible email regex check.
- (BOOL)isValidEmail:(NSString *)email
{
    NSString *pattern = @"[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", pattern];
    return [pred evaluateWithObject:email];
}

@end
