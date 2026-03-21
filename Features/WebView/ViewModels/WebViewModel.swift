// WebViewModel.swift
// meeting-iOS
//
// ViewModel for the main WebView screen.
// Manages navigation state, loading state, JS bridge calls, and error handling.

import Foundation
import Combine
import WebKit

// MARK: - Navigation Direction

enum NavigationDirection {
    case back, forward
}

// MARK: - WebViewModel

@MainActor
final class WebViewModel: ObservableObject {

    // MARK: - Published state

    @Published private(set) var currentURL: URL?
    @Published private(set) var pageTitle: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingProgress: Double = 0
    @Published private(set) var canGoBack: Bool = false
    @Published private(set) var canGoForward: Bool = false
    @Published private(set) var isOffline: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showSidebar: Bool = false

    // MARK: - Navigation target

    /// Set by external callers (deep links, notifications) to trigger a navigation.
    @Published var pendingURL: URL?

    // MARK: - Dependencies

    private let configService: ConfigService
    private let networkMonitor: NetworkMonitor
    private let storageService: StorageService

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private weak var webView: WKWebView?
    private var offlineCheckTimer: AnyCancellable?
    private var offlineTimestamp: Date?

    // MARK: - Init

    init(
        configService: ConfigService,
        networkMonitor: NetworkMonitor,
        storageService: StorageService
    ) {
        self.configService = configService
        self.networkMonitor = networkMonitor
        self.storageService = storageService

        setupNetworkObserver()
    }

    // MARK: - WebView binding

    func bind(to webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - Public navigation

    func loadInitialURL() {
        let url = storageService.effectiveInitialURL
        load(url: url)
    }

    func navigate(to url: URL) {
        if let webView {
            webView.load(URLRequest(url: url))
        } else {
            pendingURL = url
        }
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
    }

    // MARK: - JavaScript bridge

    func executeJavaScript(_ script: String) {
        webView?.runJavaScript(script)
    }

    func evaluateJavaScript(_ script: String) async throws -> Any? {
        guard let webView else { return nil }
        return try await webView.evaluateJavaScript(script)
    }

    // MARK: - Navigation callbacks (called by WebViewRepresentable)

    func didStartNavigation(url: URL?) {
        isLoading = true
        loadingProgress = 0
        errorMessage = nil
        currentURL = url
        offlineTimestamp = nil
        offlineCheckTimer?.cancel()
    }

    func didFinishNavigation(url: URL?, title: String?) {
        isLoading = false
        loadingProgress = 1
        currentURL = url
        pageTitle = title ?? configService.appName
        isOffline = false
        errorMessage = nil
        updateNavigationState()
    }

    func didFailNavigation(url: URL?, error: Error) {
        isLoading = false
        let nsError = error as NSError
        // Ignore cancelled loads
        guard nsError.code != NSURLErrorCancelled else { return }

        LoggingService.shared.error("Navigation failed: \(error.localizedDescription)")

        if !networkMonitor.isConnected {
            triggerOfflineFallback()
        } else {
            errorMessage = error.localizedDescription
        }
        updateNavigationState()
    }

    func progressChanged(_ progress: Double) {
        loadingProgress = progress
    }

    func titleChanged(_ title: String?) {
        if let title, !title.isEmpty {
            pageTitle = title
        }
    }

    // MARK: - State sync

    func syncNavigationState() {
        updateNavigationState()
    }

    // MARK: - Private helpers

    private func load(url: URL) {
        var request = URLRequest(url: url)
        configService.customHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        webView?.load(request)
    }

    private func updateNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }

    private func triggerOfflineFallback() {
        if configService.showOfflinePage {
            isOffline = true
            LoggingService.shared.warning("Network offline – showing offline page.")
        }
    }

    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard let self else { return }
                if connected && self.isOffline {
                    // Attempt reload when connection is restored
                    self.isOffline = false
                    self.reload()
                }
            }
            .store(in: &cancellables)
    }
}
