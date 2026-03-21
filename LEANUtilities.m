// LEANUtilities.m

#import "LEANUtilities.h"
#import <UIKit/UIKit.h>

@implementation LEANUtilities

+ (UIDeviceOrientation)currentDeviceOrientation {
    return [UIDevice currentDevice].orientation;
}

+ (BOOL)isDevicePortrait {
    return UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation);
}

+ (BOOL)isDeviceLandscape {
    return UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
}

+ (void)performActionBasedOnOrientation:(void (^)(UIDeviceOrientation orientation))action {
    UIDeviceOrientation orientation = [self currentDeviceOrientation];
    if (action) {
        action(orientation);
    }
}

@end
