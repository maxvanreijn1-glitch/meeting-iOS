// AuthenticationService.swift
// meeting-iOS
//
// Modern Swift service that wraps LEANLoginManager and exposes
// Combine-based auth state to the rest of the Swift layer.

import Foundation
import Combine

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case loggedOut
    case loggedIn(status: String)
}

// MARK: - Protocol

protocol AuthenticationServiceProtocol: AnyObject {
    var authState: AuthState { get }
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    func checkLogin()
    func logout()
}

// MARK: - Implementation

final class AuthenticationService: NSObject, AuthenticationServiceProtocol, ObservableObject {

    // MARK: - Singleton

    static let shared = AuthenticationService()

    // MARK: - Published

    @Published private(set) var authState: AuthState = .unknown

    var authStatePublisher: AnyPublisher<AuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private override init() {
        super.init()
        subscribeToLoginManager()
    }

    // MARK: - Public

    func checkLogin() {
        LEANLoginManager.sharedManager()?.checkLogin()
    }

    func logout() {
        LEANLoginManager.sharedManager()?.stopChecking()

        // Clear WKWebView data stores and update state in the completion handler.
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) { [weak self] in
            self?.authState = .loggedOut
        }
    }

    // MARK: - Private helpers

    private func subscribeToLoginManager() {
        // Observe Objective-C notifications from LEANLoginManager.
        NotificationCenter.default.publisher(
            for: Notification.Name(kLEANLoginManagerStatusChangedNotification)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.syncStateFromLoginManager()
        }
        .store(in: &cancellables)

        // Also observe the generic update notification to catch initial state.
        NotificationCenter.default.publisher(
            for: Notification.Name(kLEANLoginManagerNotificationName)
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.syncStateFromLoginManager()
        }
        .store(in: &cancellables)
    }

    private func syncStateFromLoginManager() {
        guard let manager = LEANLoginManager.sharedManager() else {
            authState = .unknown
            return
        }
        if manager.loggedIn {
            let status = manager.loginStatus ?? "loggedIn"
            authState = .loggedIn(status: status)
        } else {
            authState = .loggedOut
        }
    }
}
