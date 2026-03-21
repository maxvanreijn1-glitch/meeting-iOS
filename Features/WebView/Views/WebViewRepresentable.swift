// WebViewRepresentable.swift
// meeting-iOS
//
// UIViewRepresentable bridge that wraps WKWebView for use in SwiftUI.

import SwiftUI
import WebKit
import Combine

// MARK: - Representable

struct WebViewRepresentable: UIViewRepresentable {

    // MARK: - Dependencies (injected by parent view)

    @ObservedObject var viewModel: WebViewModel
    let configService: ConfigService
    let jsService: JSBridgeService

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(coordinator: context.coordinator)
        viewModel.bind(to: webView)
        context.coordinator.startObserving(webView: webView)
        viewModel.loadInitialURL()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if let pending = viewModel.pendingURL {
            viewModel.pendingURL = nil
            webView.load(URLRequest(url: pending))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, configService: configService, jsService: jsService)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.teardown(webView: webView)
    }

    // MARK: - WebView construction

    private func buildWebView(coordinator: Coordinator) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Process pool for shared session state
        config.processPool = WKProcessPool()

        // Enable window.open
        if configService.enableWindowOpen {
            config.preferences.javaScriptCanOpenWindowsAutomatically = true
        }

        // Media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // JavaScript bridge message handlers
        jsService.configure(contentController: config.userContentController)

        // Inject Median bridge script at document start
        if configService.injectMedianJS {
            let bridgeSource = WKUserScript(
                source: makeBridgeSource(),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
            config.userContentController.addUserScript(bridgeSource)
        }

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.scrollView.bounces = true

        // Pull-to-refresh
        if configService.pullToRefresh {
            let refresh = UIRefreshControl()
            refresh.addTarget(coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
            webView.scrollView.refreshControl = refresh
        }

        // Pinch-to-zoom
        webView.scrollView.pinchGestureRecognizer?.isEnabled = configService.pinchToZoom

        // Debug inspection
#if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
#endif

        return webView
    }

    private func makeBridgeSource() -> String {
        """
        (function() {
            'use strict';
            if (window.median) return;
            var _callbacks = {};
            var _id = 0;
            function post(h, d) {
                var mh = window.webkit && window.webkit.messageHandlers;
                if (mh && mh[h]) mh[h].postMessage(d);
            }
            window.median = window.gonative = {
                nativeCallback: function(id, data) {
                    var cb = _callbacks[id];
                    if (cb) { cb(data); delete _callbacks[id]; }
                },
                call: function(action, data, cb) {
                    var id = ++_id;
                    if (cb) _callbacks[id] = cb;
                    post('median', { action: action, data: data || {}, callbackId: id });
                }
            };
            window.median_app_resumed = window.gonative_app_resumed = function() {
                window.dispatchEvent(new CustomEvent('median_app_resumed'));
            };
            var _origLog = console.log;
            var _origWarn = console.warn;
            var _origError = console.error;
            var _origInfo = console.info;
            var _origDebug = console.debug;
            function patchConsole(level, orig) {
                return function() {
                    var msg = '[' + level + '] ' + Array.prototype.slice.call(arguments).join(' ');
                    post('log', msg);
                    orig && orig.apply(console, arguments);
                };
            }
            console.log   = patchConsole('log',   _origLog);
            console.warn  = patchConsole('warn',  _origWarn);
            console.error = patchConsole('error', _origError);
            console.info  = patchConsole('info',  _origInfo);
            console.debug = patchConsole('debug', _origDebug);
        })();
        """
    }
}

// MARK: - Coordinator

extension WebViewRepresentable {

    final class Coordinator: NSObject {

        // MARK: - Properties

        private let viewModel: WebViewModel
        private let configService: ConfigService
        private let jsService: JSBridgeService
        private let navigationService: NavigationService
        private var cancellables = Set<AnyCancellable>()
        private var progressObserver: NSKeyValueObservation?
        private var titleObserver: NSKeyValueObservation?

        // MARK: - Init

        init(viewModel: WebViewModel, configService: ConfigService, jsService: JSBridgeService) {
            self.viewModel = viewModel
            self.configService = configService
            self.jsService = jsService
            self.navigationService = NavigationService(configService: configService)
        }

        // MARK: - Observation lifecycle

        func startObserving(webView: WKWebView) {
            progressObserver = webView.observe(\.estimatedProgress) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.viewModel.progressChanged(wv.estimatedProgress)
                }
            }
            titleObserver = webView.observe(\.title) { [weak self] wv, _ in
                DispatchQueue.main.async {
                    self?.viewModel.titleChanged(wv.title)
                }
            }
        }

        func teardown(webView: WKWebView) {
            progressObserver?.invalidate()
            titleObserver?.invalidate()
            jsService.teardown(contentController: webView.configuration.userContentController)
        }

        // MARK: - Pull-to-refresh

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            viewModel.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                sender.endRefreshing()
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewRepresentable.Coordinator: WKNavigationDelegate {

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .cancel }

        let isNewWindow = navigationAction.targetFrame == nil
        let decision = navigationService.decide(for: url, isNewWindow: isNewWindow)

        switch decision {
        case .allow:
            return .allow
        case .openExternal:
            await UIApplication.shared.open(url)
            return .cancel
        case .cancel:
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        viewModel.didStartNavigation(url: webView.url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        viewModel.didFinishNavigation(url: webView.url, title: webView.title)
        viewModel.syncNavigationState()

        // Inject bridge after page load
        if configService.injectMedianJS {
            jsService.injectBridgeScript(into: webView)
        }

        // Inject custom JavaScript from bundle
        injectCustomJS(into: webView)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        viewModel.didFailNavigation(url: webView.url, error: error)
        viewModel.syncNavigationState()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        viewModel.didFailNavigation(url: webView.url, error: error)
        viewModel.syncNavigationState()
    }

    // MARK: - Custom JS injection

    private func injectCustomJS(into webView: WKWebView) {
        // iosCustomJS.js
        if let jsPath = Bundle.main.path(forResource: "iosCustomJS", ofType: "js"),
           let jsContent = try? String(contentsOfFile: jsPath) {
            webView.runJavaScript(jsContent)
        }
        // customJS.js
        if let jsPath = Bundle.main.path(forResource: "customJS", ofType: "js"),
           let jsContent = try? String(contentsOfFile: jsPath) {
            webView.runJavaScript(jsContent)
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewRepresentable.Coordinator: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Handle window.open by loading in the same WebView when configured
        if configService.enableWindowOpen,
           let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        UIApplication.shared.activeKeyWindow?.rootViewController?.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        UIApplication.shared.activeKeyWindow?.rootViewController?.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { $0.text = defaultText }
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        UIApplication.shared.activeKeyWindow?.rootViewController?.present(alert, animated: true)
    }
}
