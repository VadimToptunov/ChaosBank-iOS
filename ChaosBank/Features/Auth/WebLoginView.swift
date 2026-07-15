//
//  WebLoginView.swift
//  ChaosBank
//
//  Login rendered inside a WKWebView ("web-шторка") — a self-contained HTML form
//  (no network) that posts credentials back to native over a JS bridge. This is
//  deliberately tester-hostile: the login fields live in a web context, so tests
//  must reach them through `app.webViews` and web element ids, not native
//  accessibility identifiers.
//

import SwiftUI
import WebKit

struct WebLoginSheet: View {
    let onSubmit: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebLoginView(onSubmit: onSubmit)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Sign in")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .tint(Palette.sand)
                            .accessibilityIdentifier(A11y.Auth.webCancel)
                    }
                }
                .toolbarBackground(Palette.bg, for: .navigationBar)
        }
        .accessibilityIdentifier(A11y.Auth.webSheet)
    }
}

struct WebLoginView: UIViewRepresentable {
    let onSubmit: (String, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSubmit: onSubmit) }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "chaosbankLogin")
        let config = WKWebViewConfiguration()
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.loadHTMLString(Self.html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onSubmit: (String, String) -> Void
        init(onSubmit: @escaping (String, String) -> Void) { self.onSubmit = onSubmit }

        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            let username = body["username"] as? String ?? ""
            let password = body["password"] as? String ?? ""
            onSubmit(username, password)
        }
    }

    static let html = """
    <!doctype html>
    <html>
    <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <style>
      :root { color-scheme: dark; }
      * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
      body {
        margin: 0; padding: 28px 22px;
        background: #0E1218; color: #F4F1EA;
        font-family: -apple-system, system-ui, sans-serif;
      }
      .brand { text-align: center; margin: 24px 0 28px; }
      .brand .mark { font-size: 40px; }
      .brand h1 { font-size: 26px; margin: 8px 0 4px; }
      .brand p { color: #8B95A6; font-size: 13px; margin: 0; }
      label { display: block; font-size: 12px; color: #8B95A6; margin: 0 0 6px; }
      .field { margin-bottom: 16px; }
      input {
        width: 100%; padding: 14px; font-size: 16px;
        background: #171C25; color: #F4F1EA;
        border: 1px solid #262F3D; border-radius: 12px; outline: none;
      }
      input:focus { border-color: #E9B45E; }
      button {
        width: 100%; padding: 15px; font-size: 16px; font-weight: 600;
        background: #E9B45E; color: #0E1218;
        border: none; border-radius: 14px; margin-top: 6px;
      }
      .hint { text-align: center; color: #8B95A6; font-size: 11px; margin-top: 16px; }
    </style>
    </head>
    <body>
      <div class="brand">
        <div class="mark">🏦</div>
        <h1>ChaosBank</h1>
        <p>Secure web sign-in</p>
      </div>
      <form id="login-form" onsubmit="return submitLogin(event)">
        <div class="field">
          <label for="web-username">Username</label>
          <input id="web-username" name="username" type="text" autocapitalize="none" autocorrect="off" />
        </div>
        <div class="field">
          <label for="web-password">Password</label>
          <input id="web-password" name="password" type="password" />
        </div>
        <button id="web-submit" type="submit">Log in</button>
      </form>
      <p class="hint">Demo: any username + password</p>
      <script>
        function submitLogin(e) {
          e.preventDefault();
          var u = document.getElementById('web-username').value;
          var p = document.getElementById('web-password').value;
          window.webkit.messageHandlers.chaosbankLogin.postMessage({ username: u, password: p });
          return false;
        }
      </script>
    </body>
    </html>
    """
}
