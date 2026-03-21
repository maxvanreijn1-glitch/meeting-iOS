// AppDelegate.swift
// meeting-iOS
//
// UIApplicationDelegate adapter for lifecycle events not yet available in SwiftUI.

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LoggingService.shared.info("App launched")
        StorageService.shared.markFirstLaunchIfNeeded()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Remote notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        LoggingService.shared.info("APNs token: \(tokenString)")
        StorageService.shared.apnsToken = tokenString
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        LoggingService.shared.error("APNs registration failed: \(error.localizedDescription)")
        StorageService.shared.apnsToken = nil
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        LoggingService.shared.info("Remote notification received")
        completionHandler(.newData)
    }

    // MARK: - Universal links / deep links

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL
        else { return false }

        LoggingService.shared.info("Universal link: \(url.absoluteString)")
        Task { @MainActor in
            DependencyContainer.shared.webViewModel.navigate(to: url)
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let normalized = normalizeCustomScheme(url)
        LoggingService.shared.info("Custom URL scheme: \(normalized?.absoluteString ?? url.absoluteString)")
        if let destination = normalized {
            Task { @MainActor in
                DependencyContainer.shared.webViewModel.navigate(to: destination)
            }
            return true
        }
        return false
    }

    // MARK: - Orientation

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return .allButUpsideDown
    }

    // MARK: - Helpers

    private func normalizeCustomScheme(_ url: URL) -> URL? {
        guard let scheme = url.scheme else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if scheme.hasSuffix(".https") {
            components?.scheme = "https"
        } else if scheme.hasSuffix(".http") {
            components?.scheme = "http"
        } else {
            return nil
        }
        return components?.url
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            Task { @MainActor in
                DependencyContainer.shared.webViewModel.navigate(to: url)
            }
        }
        completionHandler()
    }
}
