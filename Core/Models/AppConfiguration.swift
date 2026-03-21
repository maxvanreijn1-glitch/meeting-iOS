// AppConfiguration.swift
// meeting-iOS
//
// Codable model for the bundled appConfig.json.

import Foundation
import UIKit

// MARK: - Root

struct AppConfiguration: Codable {
    var general: GeneralConfig
    var navigation: NavigationConfig
    var styling: StylingConfig?
    var contextMenu: ContextMenuConfig?

    enum CodingKeys: String, CodingKey {
        case general, navigation, styling, contextMenu
    }
}

// MARK: - General

struct GeneralConfig: Codable {
    var initialUrl: String
    var appName: String
    var publicKey: String?
    var userAgentAdd: String?
    var iosUserAgentAdd: String?
    var forceUserAgent: String?
    var iosForceUserAgent: String?
    var enableWindowOpen: Bool?
    var injectMedianJS: Bool?
    var forceSessionCookieExpiry: Int?
    var iosCustomHeaders: [String: String]?
    var nativeBridgeUrls: [String]?
    var userAgentRegexes: [UserAgentRegex]?
    var replaceStrings: [[String]]?
    var keepScreenOn: Bool?
    var iosBundleId: String?

    enum CodingKeys: String, CodingKey {
        case initialUrl, appName, publicKey, userAgentAdd, iosUserAgentAdd
        case forceUserAgent, iosForceUserAgent, enableWindowOpen, injectMedianJS
        case forceSessionCookieExpiry, iosCustomHeaders, nativeBridgeUrls
        case userAgentRegexes, replaceStrings, keepScreenOn, iosBundleId
    }
}

struct UserAgentRegex: Codable {
    var regex: String?
    var userAgent: String?
}

// MARK: - Navigation

struct NavigationConfig: Codable {
    var iosPullToRefresh: Bool?
    var iosShowOfflinePage: Bool?
    var iosConnectionOfflineTime: Double?
    var swipeGestures: Bool?
    var maxWindows: Int?
    var maxWindowsAutoClose: Bool?
    var tabNavigation: TabNavigationConfig?
    var toolbarNavigation: ToolbarNavigationConfig?
    var menus: MenuConfig?
    var deepLinkDomains: DeepLinkConfig?
    var showRefreshButton: Bool?
    var iosShowRefreshButton: Bool?

    enum CodingKeys: String, CodingKey {
        case iosPullToRefresh, iosShowOfflinePage, iosConnectionOfflineTime
        case swipeGestures, maxWindows, maxWindowsAutoClose
        case tabNavigation, toolbarNavigation, menus, deepLinkDomains
        case showRefreshButton, iosShowRefreshButton
    }
}

struct TabNavigationConfig: Codable {
    var enabled: Bool?
    var items: [TabItem]?
    var tabSelectionConfig: [TabSelectionRule]?
}

struct TabItem: Codable, Identifiable {
    var id: String { label ?? url ?? UUID().uuidString }
    var label: String?
    var url: String?
    var icon: String?
    var regex: String?
    var enabled: Bool?
    var system: String?
}

struct TabSelectionRule: Codable {
    var regex: String?
    var tab: Int?
}

struct ToolbarNavigationConfig: Codable {
    var enabled: Bool?
    var items: [ToolbarItem]?
    var visibilityByPages: String?
    var visibilityByBackButton: String?
    var regexes: [RegexEnabled]?
}

struct ToolbarItem: Codable, Identifiable {
    var id: String { system ?? label ?? UUID().uuidString }
    var system: String?
    var label: String?
    var icon: String?
    var url: String?
    var enabled: Bool?
    var visibility: String?
}

struct MenuConfig: Codable {
    var items: [MenuItem]?
    var style: String?
}

struct MenuItem: Codable, Identifiable {
    var id: String { label ?? url ?? UUID().uuidString }
    var label: String?
    var url: String?
    var icon: String?
    var subItems: [MenuItem]?
    var isHeader: Bool?
    var enabled: Bool?
}

struct DeepLinkConfig: Codable {
    var domains: [String]?
    var enableAndroidApplinks: Bool?
}

struct RegexEnabled: Codable {
    var regex: String?
    var enabled: Bool?
}

// MARK: - Styling

struct StylingConfig: Codable {
    var theme: String?
    var iosTheme: String?
    var darkMode: String?
    var iosDarkMode: String?
    var statusBarStyle: String?
    var iosStatusBarStyle: String?
    var showNavigationBar: Bool?
    var transparentNavBar: Bool?
    var hideNavBarOnScroll: Bool?
    var hideTabBarOnScroll: Bool?
    var pinchToZoom: Bool?
    var dynamicTypeEnabled: Bool?
    var iosFullScreenWebview: Bool?
    var iosAutoHideHomeIndicator: Bool?
    var iosEnableBlurInStatusBar: Bool?
    var iosEnableOverlayInStatusBar: Bool?
    var forceViewportWidth: Double?

    enum CodingKeys: String, CodingKey {
        case theme, iosTheme, darkMode, iosDarkMode, statusBarStyle, iosStatusBarStyle
        case showNavigationBar, transparentNavBar, hideNavBarOnScroll, hideTabBarOnScroll
        case pinchToZoom, dynamicTypeEnabled, iosFullScreenWebview, iosAutoHideHomeIndicator
        case iosEnableBlurInStatusBar, iosEnableOverlayInStatusBar, forceViewportWidth
    }
}

// MARK: - Context menu

struct ContextMenuConfig: Codable {
    var enabled: Bool?
    var linkActions: [String]?

    enum CodingKeys: String, CodingKey {
        case enabled, linkActions
    }
}
