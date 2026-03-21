// NavigationService.swift
// meeting-iOS
//
// Evaluates URL navigation decisions based on the app configuration.

import Foundation

// MARK: - Navigation decision

enum NavigationDecision {
    /// Load the URL normally in the WebView.
    case allow
    /// Open the URL in the system browser (Safari).
    case openExternal
    /// Cancel the navigation entirely.
    case cancel
}

// MARK: - Protocol

protocol NavigationServiceProtocol {
    func decide(for url: URL, isNewWindow: Bool) -> NavigationDecision
}

// MARK: - Implementation

final class NavigationService: NavigationServiceProtocol {

    // MARK: - Dependencies

    private let configService: ConfigService

    // MARK: - Init

    init(configService: ConfigService = .shared) {
        self.configService = configService
    }

    // MARK: - Decision logic

    func decide(for url: URL, isNewWindow: Bool) -> NavigationDecision {
        // Always allow about:blank
        if url.absoluteString == "about:blank" { return .allow }

        // Offline placeholder
        if url.isOfflinePlaceholder { return .allow }

        let scheme = url.scheme?.lowercased() ?? ""

        // Non-http schemes should be handled by the system
        if scheme != "http" && scheme != "https" {
            return .openExternal
        }

        // External links policy: if the host differs from the initial host, open externally
        let initialHost = URL(string: configService.configuration.general.initialUrl)?.host
        if let host = url.host, let iHost = initialHost, host != iHost {
            // Allow subdomains of the initial host
            if !host.hasSuffix(".\(iHost)") && host != iHost {
                return .openExternal
            }
        }

        return .allow
    }
}
