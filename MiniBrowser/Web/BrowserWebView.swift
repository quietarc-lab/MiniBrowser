import SwiftUI
import UIKit
import WebKit

struct BrowserWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        InputAutoZoomPreventionService.install(on: configuration.userContentController)
        CompactPageModeService.install(on: configuration.userContentController)
        CanvasImageSessionService.install(on: configuration.userContentController)
        configuration.userContentController.add(context.coordinator,
                                                name: CanvasImageSessionService.messageHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        context.coordinator.attach(webView: webView)
        Task { @MainActor [weak webView] in
            guard let webView else { return }
            do {
                try await ContentBlockerService.install(on: configuration.userContentController)
            } catch {
                model.contentBlockerFailed(error: error)
            }
            model.attach(webView: webView)
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: CanvasImageSessionService.messageHandlerName
        )
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        private let model: BrowserViewModel
        private var timeoutTimer: Timer?
        private weak var attachedWebView: WKWebView?
        private let handwritingImageStore = TargetPageHandwritingImageStore()

        init(model: BrowserViewModel) {
            self.model = model
        }

        deinit {
            timeoutTimer?.invalidate()
        }

        func attach(webView: WKWebView) {
            attachedWebView = webView
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == CanvasImageSessionService.messageHandlerName,
                  message.frameInfo.isMainFrame,
                  CanvasImageSessionService.isTargetPageThreadURL(
                    message.frameInfo.request.url ?? attachedWebView?.url
                  ),
                  let body = message.body as? [String: Any],
                  let type = body["type"] as? String else {
                return
            }

            switch type {
            case "selectedImage":
                guard let dataURL = body["dataURL"] as? String else { return }
                _ = handwritingImageStore.replace(withDataURL: dataURL)

            case "pageReady":
                guard handwritingImageStore.hasImage else { return }
                attachedWebView?.evaluateJavaScript(CanvasImageSessionService.openExistingCanvasScript)

            case "canvasReady":
                guard let script = handwritingImageStore.restorationScript() else { return }
                attachedWebView?.evaluateJavaScript(script)

            case "postCompleted":
                let canvasWasOpen = body["canvasWasOpen"] as? Bool ?? false
                guard canvasWasOpen || handwritingImageStore.hasImage else { return }
                attachedWebView?.evaluateJavaScript(CanvasImageSessionService.openExistingCanvasScript)

            default:
                return
            }
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased() else {
                decisionHandler(.cancel)
                return
            }

            if ["http", "https", "about"].contains(scheme) {
                decisionHandler(.allow)
            } else {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            startTimeout(for: webView)
            model.navigationStarted()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.navigationCommitted(url: webView.url)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelTimeout()
            model.navigationFinished(url: webView.url)
        }

        func webView(_ webView: WKWebView,
                     didFail navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(webView: webView, error: error)
        }

        func webView(_ webView: WKWebView,
                     didFailProvisionalNavigation navigation: WKNavigation!,
                     withError error: Error) {
            handleFailure(webView: webView, error: error)
        }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                    webView.load(navigationAction.request)
                } else {
                    UIApplication.shared.open(url)
                }
            }
            return nil
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptAlertPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping () -> Void) {
            if WebDialogPolicy.shouldAutoDismissAlert(host: frame.request.url?.host ?? webView.url?.host,
                                                      message: message) {
                completionHandler()
                return
            }
            let alert = UIAlertController(title: dialogTitle(for: frame, webView: webView),
                                          message: message,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler()
            })
            present(alert, from: webView, orCompleteWith: completionHandler)
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptConfirmPanelWithMessage message: String,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: dialogTitle(for: frame, webView: webView),
                                          message: message,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                completionHandler(true)
            })
            present(alert, from: webView) {
                completionHandler(false)
            }
        }

        func webView(_ webView: WKWebView,
                     runJavaScriptTextInputPanelWithPrompt prompt: String,
                     defaultText: String?,
                     initiatedByFrame frame: WKFrameInfo,
                     completionHandler: @escaping (String?) -> Void) {
            let alert = UIAlertController(title: dialogTitle(for: frame, webView: webView),
                                          message: prompt,
                                          preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = defaultText
            }
            alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
                completionHandler(alert?.textFields?.first?.text)
            })
            present(alert, from: webView) {
                completionHandler(nil)
            }
        }

        private func dialogTitle(for frame: WKFrameInfo, webView: WKWebView) -> String {
            let host = frame.request.url?.host ?? webView.url?.host ?? "Webサイト"
            return "\(host) のメッセージ"
        }

        private func present(_ alert: UIAlertController,
                             from webView: WKWebView,
                             orCompleteWith fallback: @escaping () -> Void) {
            guard let presenter = Self.topViewController(from: webView.window?.rootViewController) else {
                fallback()
                return
            }
            presenter.present(alert, animated: true)
        }

        private static func topViewController(from root: UIViewController?) -> UIViewController? {
            if let presented = root?.presentedViewController,
               !presented.isBeingDismissed {
                return topViewController(from: presented)
            }
            if let navigation = root as? UINavigationController {
                return topViewController(from: navigation.visibleViewController)
            }
            if let tabs = root as? UITabBarController {
                return topViewController(from: tabs.selectedViewController)
            }
            return root
        }

        private func startTimeout(for webView: WKWebView) {
            cancelTimeout()
            let timer = Timer(timeInterval: 30, repeats: false) { [weak self, weak webView] _ in
                guard let self, let webView, webView.isLoading else { return }
                webView.stopLoading()
                self.model.navigationTimedOut(url: webView.url)
            }
            timeoutTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func cancelTimeout() {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        }

        private func handleFailure(webView: WKWebView, error: Error) {
            cancelTimeout()
            if (error as NSError).code == NSURLErrorCancelled { return }
            model.navigationFailed(url: webView.url, error: error)
        }
    }
}
