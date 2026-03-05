import SwiftUI
import WebKit

struct HeadingScrollRequest: Equatable {
    let headingIndex: Int
    let sequence: Int
}

struct RenderedMarkdownView: NSViewRepresentable {
    let document: ParsedMarkdownDocument
    let headingScrollRequest: HeadingScrollRequest?
    private let builder = RenderedHTMLBuilder()

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = builder.build(document: document)
        let coordinator = context.coordinator
        if coordinator.renderedHTML != html {
            coordinator.renderedHTML = html
            coordinator.pendingScrollRequest = headingScrollRequest
            webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
            return
        }

        coordinator.applyScrollRequestIfNeeded(headingScrollRequest, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var renderedHTML: String?
        var pendingScrollRequest: HeadingScrollRequest?
        private var appliedScrollRequest: HeadingScrollRequest?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if LocalNavigationPolicy.allows(navigationAction.request.url) {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyScrollRequestIfNeeded(pendingScrollRequest, in: webView)
            pendingScrollRequest = nil
        }

        func applyScrollRequestIfNeeded(_ request: HeadingScrollRequest?, in webView: WKWebView) {
            guard let request,
                  request != appliedScrollRequest else {
                return
            }

            let script = """
            (function() {
              const headings = document.querySelectorAll('article.markdown h1, article.markdown h2, article.markdown h3, article.markdown h4, article.markdown h5, article.markdown h6');
              const target = headings[\(request.headingIndex)];
              if (!target) { return false; }
              target.scrollIntoView({ behavior: 'smooth', block: 'start', inline: 'nearest' });
              return true;
            })();
            """

            webView.evaluateJavaScript(script)
            appliedScrollRequest = request
        }
    }
}
