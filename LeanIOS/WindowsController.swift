//
//  WindowsController.swift
//  GonativeIO
//
//  Created by Hunaid Hassan on 14.06.21.
//  Copyright © 2021 GoNative.io LLC. All rights reserved.
//

import Foundation
import UIKit

@objc class WindowsController: NSObject {
    private static let defaultMaxWindows = 5

    @objc class public func windowCountChanged() {
        let maxWindows = UserDefaults.standard.integer(forKey: "maxWindows")
        let configuredMaxWindows = maxWindows > 0 ? maxWindows : defaultMaxWindows

        guard LEANWebViewController.currentWindows > configuredMaxWindows else {
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController as? LEANRootViewController,
              let navigationController = rootViewController.contentViewController as? UINavigationController else {
            return
        }

        var viewControllers = navigationController.viewControllers
        let removeTillIndex = LEANWebViewController.currentWindows - configuredMaxWindows
        if removeTillIndex > 0 && removeTillIndex < viewControllers.count {
            viewControllers.removeSubrange(1...removeTillIndex)
            navigationController.viewControllers = viewControllers
        }
    }
}
