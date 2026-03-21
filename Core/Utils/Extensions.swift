// Extensions.swift
// meeting-iOS
//
// General-purpose Swift extensions used throughout the codebase.

import Foundation
import UIKit
import SwiftUI
import WebKit

// MARK: - URL helpers

extension URL {
    /// Returns true when this URL points to the custom offline placeholder.
    var isOfflinePlaceholder: Bool { absoluteString == "http://offline/" }

    /// Returns true when this URL points to the local cache placeholder.
    var isLocalFilePlaceholder: Bool { absoluteString.hasPrefix("http://localFile/") }

    /// Convenience for building a URL from a raw string, returning nil on failure.
    static func safe(_ string: String?) -> URL? {
        guard let string, !string.isEmpty else { return nil }
        return URL(string: string)
    }
}

// MARK: - Data helpers

extension Data {
    /// Hexadecimal string representation, commonly used for APNs tokens.
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Color helpers

extension Color {
    /// Initialises a Color from a hex string, e.g. `"#1A2B3C"` or `"1A2B3C"`.
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            (r, g, b, a) = (Double((int >> 16) & 0xFF) / 255,
                            Double((int >> 8) & 0xFF) / 255,
                            Double(int & 0xFF) / 255,
                            1)
        case 8:
            (r, g, b, a) = (Double((int >> 24) & 0xFF) / 255,
                            Double((int >> 16) & 0xFF) / 255,
                            Double((int >> 8) & 0xFF) / 255,
                            Double(int & 0xFF) / 255)
        default:
            (r, g, b, a) = (0, 0, 0, 1)
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - View helpers

extension View {
    /// Convenience modifier that applies a navigation title and hides the back-button label.
    func navigationAppTitle(_ title: String) -> some View {
        self
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WKWebView helpers

extension WKWebView {
    /// Evaluates JavaScript and discards the result; logs on error.
    func runJavaScript(_ script: String) {
        evaluateJavaScript(script) { _, error in
            if let error {
                LoggingService.shared.warning("JS evaluation failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UIApplication helpers

extension UIApplication {
    /// The currently active key window.
    var activeKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .keyWindow
    }
}
