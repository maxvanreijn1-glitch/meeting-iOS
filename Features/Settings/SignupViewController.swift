// SignupViewController.swift
// meeting-iOS
//
// SwiftUI signup screen that wraps the web-based signup URL and
// integrates with LEANSignupManager for client-side validation.

import SwiftUI
import WebKit
import Combine

// MARK: - SignupView

struct SignupView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SignupViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Web-based signup
                SignupWebView(url: viewModel.signupURL, onComplete: viewModel.handleSignupComplete)
                    .ignoresSafeArea(edges: .bottom)

                // Loading overlay
                if viewModel.isLoading {
                    ProgressView()
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Sign Up Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
            .onReceive(viewModel.didCompletePublisher) { _ in
                dismiss()
            }
        }
    }
}

// MARK: - SignupViewModel

@MainActor
final class SignupViewModel: ObservableObject {

    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""

    let didCompletePublisher = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    var signupURL: URL {
        GoNativeAppConfig.shared().signupURL ??
        GoNativeAppConfig.shared().initialURL ??
        URL(string: "about:blank")!
    }

    init() {
        observeSignupNotifications()
    }

    func handleSignupComplete() {
        LEANSignupManager.sharedManager().didCompleteSignup()
    }

    private func observeSignupNotifications() {
        NotificationCenter.default
            .publisher(for: Notification.Name(kLEANSignupManagerDidCompleteNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didCompletePublisher.send()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: Notification.Name(kLEANSignupManagerValidationFailedNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                let errors = note.userInfo?["errors"] as? [String] ?? []
                self?.errorMessage = errors.joined(separator: "\n")
                self?.showError = true
            }
            .store(in: &cancellables)
    }
}

// MARK: - SignupWebView (UIViewRepresentable)

struct SignupWebView: UIViewRepresentable {

    let url: URL
    let onComplete: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 30)
        if webView.url == nil {
            webView.load(request)
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {

        let onComplete: () -> Void

        init(onComplete: @escaping () -> Void) {
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Trigger a login check on every navigation to detect post-signup state.
            LEANLoginManager.sharedManager()?.checkLogin()
        }
    }
}

// MARK: - Preview

#Preview {
    SignupView()
}
