// StorageService.swift
// meeting-iOS
//
// Type-safe wrapper around UserDefaults and Keychain for persistent app state.

import Foundation

// MARK: - Protocol

protocol StorageServiceProtocol: AnyObject {
    var apnsToken: String? { get set }
    var isFirstLaunch: Bool { get }
    func markFirstLaunchIfNeeded()
}

// MARK: - Implementation

final class StorageService: StorageServiceProtocol {

    // MARK: - Singleton

    static let shared = StorageService()

    // MARK: - Keys

    private enum Keys {
        static let hasLaunched = "hasLaunched"
        static let apnsToken = "apnsToken"
        static let initialUrlOverride = "initialUrlOverride"
    }

    // MARK: - Private

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - First launch

    private(set) var isFirstLaunch: Bool = false

    func markFirstLaunchIfNeeded() {
        if defaults.object(forKey: Keys.hasLaunched) == nil {
            defaults.set(true, forKey: Keys.hasLaunched)
            isFirstLaunch = true
            LoggingService.shared.info("First launch detected.")
        } else {
            isFirstLaunch = false
        }
    }

    // MARK: - APNs token

    var apnsToken: String? {
        get { defaults.string(forKey: Keys.apnsToken) }
        set {
            if let token = newValue {
                defaults.set(token, forKey: Keys.apnsToken)
            } else {
                defaults.removeObject(forKey: Keys.apnsToken)
            }
        }
    }

    // MARK: - URL override (from Settings.bundle)

    var initialUrlOverride: String? {
        get { defaults.string(forKey: Keys.initialUrlOverride) }
        set {
            if let value = newValue, !value.isEmpty {
                defaults.set(value, forKey: Keys.initialUrlOverride)
            } else {
                defaults.removeObject(forKey: Keys.initialUrlOverride)
            }
        }
    }

    var effectiveInitialURL: URL {
        if let override = initialUrlOverride,
           !override.isEmpty,
           let url = URL(string: override) {
            return url
        }
        return ConfigService.shared.initialURL
    }
}
