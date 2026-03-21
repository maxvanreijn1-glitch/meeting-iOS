// ConfigService.swift
// meeting-iOS
//
// Loads and exposes the bundled appConfig.json as a typed Swift model.

import Foundation
import Combine

// MARK: - Protocol

protocol ConfigServiceProtocol {
    var configuration: AppConfiguration { get }
    var initialURL: URL { get }
}

// MARK: - Implementation

final class ConfigService: ConfigServiceProtocol, ObservableObject {

    // MARK: - Singleton

    static let shared = ConfigService()

    // MARK: - Published

    @Published private(set) var configuration: AppConfiguration
    @Published private(set) var configError: Error?

    // MARK: - Init

    private init() {
        do {
            configuration = try Self.load()
        } catch {
            LoggingService.shared.error("Failed to load appConfig.json: \(error)")
            configuration = Self.makeDefault()
        }
    }

    // MARK: - Computed helpers

    var initialURL: URL {
        URL(string: configuration.general.initialUrl) ?? URL(string: "about:blank")!
    }

    var appName: String { configuration.general.appName }

    var pullToRefresh: Bool {
        configuration.navigation.iosPullToRefresh ?? true
    }

    var showOfflinePage: Bool {
        configuration.navigation.iosShowOfflinePage ?? true
    }

    var offlineTimeout: Double {
        configuration.navigation.iosConnectionOfflineTime ?? 10
    }

    var enableWindowOpen: Bool {
        configuration.general.enableWindowOpen ?? true
    }

    var injectMedianJS: Bool {
        configuration.general.injectMedianJS ?? true
    }

    var customHeaders: [String: String] {
        configuration.general.iosCustomHeaders ?? [:]
    }

    var keepScreenOn: Bool {
        configuration.general.keepScreenOn ?? false
    }

    var pinchToZoom: Bool {
        configuration.styling?.pinchToZoom ?? false
    }

    var contextMenuEnabled: Bool {
        configuration.contextMenu?.enabled ?? false
    }

    // MARK: - Private helpers

    private static func load() throws -> AppConfiguration {
        guard let url = Bundle.main.url(forResource: "appConfig", withExtension: "json") else {
            throw ConfigError.fileNotFound
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(AppConfiguration.self, from: data)
    }

    private static func makeDefault() -> AppConfiguration {
        AppConfiguration(
            general: GeneralConfig(
                initialUrl: "about:blank",
                appName: "App",
                publicKey: nil,
                userAgentAdd: nil,
                iosUserAgentAdd: nil,
                forceUserAgent: nil,
                iosForceUserAgent: nil,
                enableWindowOpen: true,
                injectMedianJS: true,
                forceSessionCookieExpiry: 0,
                iosCustomHeaders: nil,
                nativeBridgeUrls: nil,
                userAgentRegexes: nil,
                replaceStrings: nil,
                keepScreenOn: false,
                iosBundleId: nil
            ),
            navigation: NavigationConfig(
                iosPullToRefresh: true,
                iosShowOfflinePage: true,
                iosConnectionOfflineTime: 10,
                swipeGestures: true,
                maxWindows: 5,
                maxWindowsAutoClose: false,
                tabNavigation: nil,
                toolbarNavigation: nil,
                menus: nil,
                deepLinkDomains: nil,
                showRefreshButton: false,
                iosShowRefreshButton: false
            ),
            styling: nil,
            contextMenu: nil
        )
    }
}

// MARK: - Errors

enum ConfigError: LocalizedError {
    case fileNotFound
    case invalidJSON(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "appConfig.json not found in bundle."
        case .invalidJSON(let error):
            return "Invalid appConfig.json: \(error.localizedDescription)"
        }
    }
}
