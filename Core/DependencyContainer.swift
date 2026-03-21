// DependencyContainer.swift
// meeting-iOS
//
// Lightweight dependency injection container that wires the app's services together.

import Foundation

// MARK: - Container

@MainActor
final class DependencyContainer {

    // MARK: - Singleton

    static let shared = DependencyContainer()

    // MARK: - Services (singletons already)

    let configService: ConfigService = .shared
    let networkMonitor: NetworkMonitor = .shared
    let storageService: StorageService = .shared
    let loggingService: LoggingService = .shared

    // MARK: - Feature dependencies

    lazy var webViewModel: WebViewModel = {
        WebViewModel(
            configService: configService,
            networkMonitor: networkMonitor,
            storageService: storageService
        )
    }()

    // MARK: - Init

    private init() {}
}
