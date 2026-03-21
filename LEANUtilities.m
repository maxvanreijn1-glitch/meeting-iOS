// LEANUtilities.m

#import "LEANUtilities.h"
#import <UIKit/UIKit.h>

@implementation LEANUtilities

+ (UIDeviceOrientation)currentDeviceOrientation {
    return [UIDevice currentDevice].orientation;
}

+ (BOOL)isDevicePortrait {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsPortrait(orientation)) {
        return YES;
    }
    // Fall back to active window scene interface orientation when device orientation is unknown
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return UIInterfaceOrientationIsPortrait(((UIWindowScene *)scene).interfaceOrientation);
        }
    }
    return YES; // default to portrait
}

+ (BOOL)isDeviceLandscape {
    UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
    if (UIDeviceOrientationIsLandscape(orientation)) {
        return YES;
    }
    // Fall back to active window scene interface orientation when device orientation is unknown
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] &&
            scene.activationState == UISceneActivationStateForegroundActive) {
            return UIInterfaceOrientationIsLandscape(((UIWindowScene *)scene).interfaceOrientation);
        }
    }
    return NO; // default to not landscape
}

+ (void)performActionBasedOnOrientation:(void (^)(UIDeviceOrientation orientation))action {
    UIDeviceOrientation orientation = [self currentDeviceOrientation];
    if (action) {
        action(orientation);
    }
}

@end
