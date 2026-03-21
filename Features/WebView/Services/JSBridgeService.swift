// JSBridgeService.swift
// meeting-iOS
//
// Handles JavaScript ↔ Native messaging via WKScriptMessageHandler.

import Foundation
import WebKit
import Combine

// MARK: - Supported JS message names

enum JSMessageName: String, CaseIterable {
    case median        = "median"
    case gonative      = "gonative"
    case log           = "log"
}

// MARK: - Protocol

protocol JSBridgeServiceProtocol: AnyObject {
    func configure(contentController: WKUserContentController)
    func teardown(contentController: WKUserContentController)
    func injectBridgeScript(into webView: WKWebView)
}

// MARK: - Implementation

final class JSBridgeService: NSObject, JSBridgeServiceProtocol {

    // MARK: - Subjects for upstream consumers

    let messagePublisher = PassthroughSubject<(name: String, body: Any), Never>()

    // MARK: - Protocol implementation

    func configure(contentController: WKUserContentController) {
        for name in JSMessageName.allCases {
            contentController.add(self, name: name.rawValue)
        }
        LoggingService.shared.debug("JSBridgeService: message handlers registered.")
    }

    func teardown(contentController: WKUserContentController) {
        for name in JSMessageName.allCases {
            contentController.removeScriptMessageHandler(forName: name.rawValue)
        }
    }

    func injectBridgeScript(into webView: WKWebView) {
        let script = Self.makeNativeBridgeScript()
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                LoggingService.shared.warning("Bridge script injection failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private static func makeNativeBridgeScript() -> String {
        """
        (function() {
            'use strict';
            if (window.median) return;

            var _callbacks = {};
            var _callbackId = 0;

            function postMessage(handler, data) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[handler]) {
                    window.webkit.messageHandlers[handler].postMessage(data);
                }
            }

            window.median = window.gonative = {
                nativeCallback: function(callbackId, data) {
                    var callback = _callbacks[callbackId];
                    if (callback) {
                        callback(data);
                        delete _callbacks[callbackId];
                    }
                },
                call: function(action, data, callback) {
                    var id = ++_callbackId;
                    if (callback) _callbacks[id] = callback;
                    var message = { action: action, data: data || {}, callbackId: id };
                    postMessage('median', message);
                }
            };

            // App resume events
            window.median_app_resumed = window.gonative_app_resumed = function() {
                var event = new CustomEvent('median_app_resumed');
                window.dispatchEvent(event);
            };
        })();
        """
    }
}

// MARK: - WKScriptMessageHandler

extension JSBridgeService: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        LoggingService.shared.debug("JS message received: \(message.name) – \(message.body)")
        messagePublisher.send((name: message.name, body: message.body))

        // Handle log messages for web console passthrough
        if message.name == JSMessageName.log.rawValue {
            let text = (message.body as? String) ?? "\(message.body)"
            LoggingService.shared.debug("[WebConsole] \(text)")
        }
    }
}
