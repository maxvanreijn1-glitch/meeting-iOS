/**
 * auth-bridge.js
 * meeting-iOS / LeanIOS
 *
 * JavaScript bridge helpers for authentication operations.
 * Injected into web pages to facilitate communication between
 * the native iOS layer and the web-based auth flow.
 */

(function (window) {
  'use strict';

  // ── Namespace ────────────────────────────────────────────────────────────────

  var AuthBridge = window.AuthBridge || {};

  // ── Internal helpers ─────────────────────────────────────────────────────────

  /**
   * Send a message to the native iOS bridge (GoNative / Median JS interface).
   * Falls back gracefully when running in a regular browser.
   * @param {string} command
   * @param {Object} [params]
   */
  function sendNativeMessage(command, params) {
    var payload = Object.assign({ command: command }, params || {});
    if (window.gonative && typeof window.gonative.nativebridge === 'function') {
      window.gonative.nativebridge(JSON.stringify(payload));
    } else if (
      window.webkit &&
      window.webkit.messageHandlers &&
      window.webkit.messageHandlers.gonative
    ) {
      window.webkit.messageHandlers.gonative.postMessage(payload);
    } else {
      console.debug('[AuthBridge]', command, payload);
    }
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  /**
   * Call from the web page after a successful login to notify the native layer.
   * @param {Object} [userData] - Optional user details to pass along.
   */
  AuthBridge.notifyLoginSuccess = function (userData) {
    sendNativeMessage('auth.loginSuccess', { user: userData || {} });
  };

  /**
   * Call from the web page after logout.
   */
  AuthBridge.notifyLogout = function () {
    sendNativeMessage('auth.logout');
  };

  /**
   * Call when the signup form is submitted successfully.
   * @param {Object} [userData] - Optional user details.
   */
  AuthBridge.notifySignupSuccess = function (userData) {
    sendNativeMessage('auth.signupSuccess', { user: userData || {} });
  };

  /**
   * Request the native layer to dismiss the auth sheet (e.g. cancel button).
   */
  AuthBridge.dismissAuthSheet = function () {
    sendNativeMessage('auth.dismiss');
  };

  /**
   * Request the native layer to open the pricing view.
   */
  AuthBridge.openPricing = function () {
    sendNativeMessage('pricing.open');
  };

  /**
   * Retrieve the current login state from the native layer via a callback.
   * @param {function(boolean, string)} callback - Receives (loggedIn, status).
   */
  AuthBridge.getLoginState = function (callback) {
    if (typeof callback !== 'function') return;
    sendNativeMessage('auth.getState', { callbackId: 'authStateCallback' });

    // The native layer is expected to call window.AuthBridge._onStateResponse
    // with the result.  We store the callback for that invocation.
    AuthBridge._pendingStateCallback = callback;
  };

  /**
   * Called by the native iOS layer to deliver the current auth state.
   * @param {boolean} loggedIn
   * @param {string}  status
   */
  AuthBridge._onStateResponse = function (loggedIn, status) {
    if (typeof AuthBridge._pendingStateCallback === 'function') {
      AuthBridge._pendingStateCallback(loggedIn, status || 'default');
      AuthBridge._pendingStateCallback = null;
    }
  };

  // ── Event listeners ──────────────────────────────────────────────────────────

  /**
   * Automatically detect common login/logout form submissions and notify
   * the native layer.  Works as a best-effort helper when the web page
   * does not explicitly call AuthBridge methods.
   */
  function autoDetectAuthEvents() {
    document.addEventListener(
      'submit',
      function (evt) {
        var form = evt.target;
        if (!(form instanceof HTMLFormElement)) return;

        var action = (form.action || '').toLowerCase();
        var id     = (form.id || '').toLowerCase();
        var cls    = (form.className || '').toLowerCase();

        if (/login|sign[\-_]?in/.test(action + id + cls)) {
          // Give the server a moment to process before triggering a check.
          setTimeout(function () {
            sendNativeMessage('auth.triggerLoginCheck');
          }, 1500);
        }

        if (/sign[\-_]?up|register/.test(action + id + cls)) {
          setTimeout(function () {
            sendNativeMessage('auth.triggerSignupCheck');
          }, 1500);
        }
      },
      true
    );
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', autoDetectAuthEvents);
  } else {
    autoDetectAuthEvents();
  }

  // ── Expose ───────────────────────────────────────────────────────────────────

  window.AuthBridge = AuthBridge;
})(window);
