import Combine
import Foundation
import UIKit
import WebKit

@MainActor
final class BrowserViewModel: ObservableObject {
    private enum Keys {
        static let lastURL = "lastURL"
        static let userAgentIndex = "userAgentIndex"
    }

    @Published var urlText = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var isUAChanging = false
    @Published private(set) var isCookieRefreshing = false
    @Published private(set) var isAPRunning = false
    @Published private(set) var isIdentityRefreshInProgress = false
    @Published private(set) var toasts: [ToastMessage] = []
    @Published private(set) var sitePostStatus: SitePostStatus? = nil

    let bookmarkStore: BookmarkStore

    weak var webView: WKWebView?
    private let defaults: UserDefaults
    private let logStore: DebugLogStore
    private let ipService: IPAddressService
    private var selectedUAIndex: Int
    private var pendingCookieRefresh: PendingCookieRefresh?
    private var pendingAP: PendingAP?
    private var lastRelatedCookieCountByHost: [String: Int] = [:]

    private struct PendingCookieRefresh {
        let host: String
        let beforeCount: Int
        let deletedCount: Int
        let deletionConfirmed: Bool
        let identityRefresh: Bool
    }

    private struct PendingAP {
        let beforeIPv4: String?
        let reloadAfterCompletion: Bool
    }

    init(defaults: UserDefaults = .standard,
         ipService: IPAddressService = IPAddressService()) {
        self.defaults = defaults
        self.logStore = DebugLogStore(defaults: defaults)
        self.bookmarkStore = BookmarkStore(defaults: defaults)
        self.ipService = ipService
        let savedIndex = defaults.integer(forKey: Keys.userAgentIndex)
        self.selectedUAIndex = BrowserUserAgent.all.indices.contains(savedIndex) ? savedIndex : 0
    }

    var currentUserAgent: BrowserUserAgent {
        BrowserUserAgent.all[selectedUAIndex]
    }

    var userAgentButtonTitle: String {
        "UA \(selectedUAIndex + 1)/\(BrowserUserAgent.all.count)"
    }

    func attach(webView: WKWebView) {
        guard self.webView !== webView else { return }
        self.webView = webView
        webView.customUserAgent = currentUserAgent.value

        if let saved = defaults.string(forKey: Keys.lastURL),
           let url = URLNormalizer.normalize(saved) {
            urlText = url.absoluteString
            webView.load(URLRequest(url: url))
        }
    }

    func openURLFromField() {
        guard let url = URLNormalizer.normalize(urlText) else {
            showToast("URLを確認してください", kind: .failure)
            return
        }
        urlText = url.absoluteString
        webView?.load(URLRequest(url: url))
    }

    func openThreadListThread(_ url: URL) {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "img.2chan.net",
              url.path.range(of: #"^/[^/]+/res/\d+\.htm$"#,
                             options: .regularExpression) != nil else {
            showToast("スレURLを確認してください", kind: .failure)
            return
        }
        urlText = url.absoluteString
        webView?.load(URLRequest(url: url))
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

    func cycleUserAgent() {
        guard !isIdentityRefreshInProgress,
              !isUAChanging,
              !isCookieRefreshing,
              !isAPRunning,
              !isLoading,
              let webView,
              webView.url?.host != nil else {
            showToast("UA更新を開始できません", kind: .warning)
            return
        }
        selectedUAIndex = (selectedUAIndex + 1) % BrowserUserAgent.all.count
        defaults.set(selectedUAIndex, forKey: Keys.userAgentIndex)
        webView.customUserAgent = currentUserAgent.value
        isUAChanging = true
        isIdentityRefreshInProgress = true
        showToast("UA変更後にCookie更新とAP再接続を開始します",
                  kind: .success)
        logStore.append(action: "User Agent Change", fields: [
            ("URL", LogSanitizer.url(currentURL)),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("RESULT", "CHANGED")
        ])

        Task { [weak self] in
            await self?.deleteRelatedCookiesForRefresh(identityRefresh: true)
        }
    }

    func refreshCookies() {
        guard !isCookieRefreshing,
              !isIdentityRefreshInProgress,
              !isLoading,
              webView?.url?.host != nil else {
            showToast("Cookie確認失敗", kind: .warning)
            return
        }

        isCookieRefreshing = true
        Task { [weak self] in
            await self?.deleteRelatedCookiesForRefresh(identityRefresh: false)
        }
    }

    func startCellularReconnect() {
        startCellularReconnect(reloadAfterCompletion: false)
    }

    private func startCellularReconnect(reloadAfterCompletion: Bool) {
        guard !isAPRunning else { return }
        isAPRunning = true

        Task { [weak self] in
            guard let self else { return }
            let before = try? await ipService.fetchIPv4(userAgent: currentUserAgent.value)
            self.pendingAP = PendingAP(beforeIPv4: before,
                                       reloadAfterCompletion: reloadAfterCompletion)

            guard let shortcutURL = Self.cellularReconnectURL(),
                  await Self.openExternalURL(shortcutURL) else {
                self.finishAPFailure(status: "SHORTCUT_OPEN_FAILED",
                                     before: before,
                                     reloadAfterCompletion: reloadAfterCompletion)
                return
            }
        }
    }

    func openBookmark(_ item: BookmarkItem) {
        switch item.kind {
        case .url:
            guard let url = URLNormalizer.normalize(item.content) else {
                showToast("URLを確認してください", kind: .failure)
                return
            }
            urlText = url.absoluteString
            webView?.load(URLRequest(url: url))
        case .bookmarklet:
            executeBookmarklet(item.content)
        }
    }

    func validateBookmarklet(_ source: String) {
        let script = Self.bookmarkletScript(from: source)
        guard let literal = Self.javaScriptStringLiteral(script) else {
            showToast("Bookmarklet構文を確認してください", kind: .warning)
            return
        }
        webView?.evaluateJavaScript("new Function(\(literal)); true;") { [weak self] _, error in
            if error != nil {
                self?.showToast("Bookmarklet構文を確認してください", kind: .warning)
            }
        }
    }

    func copyDebugLog() {
        let text = logStore.plainText(limit: 50)
        guard !text.isEmpty else {
            showToast("ログなし", kind: .warning)
            return
        }
        UIPasteboard.general.string = text
        showToast("ログをコピーしました", kind: .success)
    }

    func contentBlockerFailed(error: Error) {
        logStore.append(action: "Content Blocker Setup", fields: [
            ("ERROR_DOMAIN", (error as NSError).domain),
            ("ERROR_CODE", String((error as NSError).code)),
            ("DETAIL", error.localizedDescription),
            ("RESULT", "FAILED")
        ])
        showToast("広告ブロック初期化失敗", kind: .warning)
    }

    func navigationStarted() {
        isLoading = true
        sitePostStatus = nil
        refreshNavigationState()
    }

    func updateSitePostStatus(_ rawStatus: String?) {
        sitePostStatus = rawStatus.flatMap(SitePostStatus.init(rawValue:))
    }

    func navigationCommitted(url: URL?) {
        updateCurrentURL(url)
        refreshNavigationState()
    }

    func navigationFinished(url: URL?) {
        isLoading = false
        if !isIdentityRefreshInProgress {
            isUAChanging = false
        }
        updateCurrentURL(url)
        refreshNavigationState()
        runAutomaticBookmarklets(for: url)
        if pendingCookieRefresh != nil {
            Task { [weak self] in
                await self?.completeCookieRefreshAfterReload()
            }
        }
    }

    func navigationFailed(url: URL?, error: Error) {
        isLoading = false
        if !isIdentityRefreshInProgress {
            isUAChanging = false
        }
        updateCurrentURL(url)
        refreshNavigationState()
        showToast("読み込み失敗", kind: .failure)
        logStore.append(action: "Web Load Failure", fields: [
            ("URL", LogSanitizer.url(url)),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("ERROR_DOMAIN", (error as NSError).domain),
            ("ERROR_CODE", String((error as NSError).code)),
            ("DETAIL", error.localizedDescription),
            ("RESULT", "FAILED")
        ])
        failPendingCookieRefresh(result: "RELOAD_FAILED")
    }

    func navigationTimedOut(url: URL?) {
        isLoading = false
        if !isIdentityRefreshInProgress {
            isUAChanging = false
        }
        updateCurrentURL(url)
        refreshNavigationState()
        showToast("読み込みタイムアウト", kind: .failure)
        logStore.append(action: "Web Load Timeout", fields: [
            ("URL", LogSanitizer.url(url)),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("TIMEOUT_SECONDS", "30"),
            ("RESULT", "TIMEOUT")
        ])
        failPendingCookieRefresh(result: "RELOAD_TIMEOUT")
    }

    func handleCallbackURL(_ url: URL) {
        guard url.scheme?.lowercased() == "minibrowser",
              url.host?.lowercased() == "return",
              isAPRunning,
              let context = pendingAP else { return }

        let status = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "status" })?.value ?? "success"
        guard status == "success" else {
            finishAPFailure(status: "CALLBACK_\(status.uppercased())",
                            before: context.beforeIPv4,
                            reloadAfterCompletion: context.reloadAfterCompletion)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let after = await self.fetchIPv4AfterRecovery()
            self.completeAP(before: context.beforeIPv4,
                            after: after,
                            reloadAfterCompletion: context.reloadAfterCompletion)
        }
    }

    func showToast(_ text: String, kind: ToastKind, duration: TimeInterval = 3.5) {
        let toast = ToastMessage(text: text, kind: kind)
        toasts.append(toast)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            self?.toasts.removeAll { $0.id == toast.id }
        }
    }

    func recordTargetPageAlert(_ category: TargetPageAlertCategory, host: String) async {
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore else { return }
        let normalizedHost = host.lowercased()
        let cookies = await store.miniBrowserAllCookies()
        let relatedCount = cookies.filter {
            CookieDomainMatcher.isRelated(cookieDomain: $0.domain, toHost: normalizedHost)
        }.count
        let previousCount = lastRelatedCookieCountByHost[normalizedHost]
        lastRelatedCookieCountByHost[normalizedHost] = relatedCount

        // Deliberately record only a known alert category and aggregate counts.
        // Cookie names, values, and the site-provided message stay out of the log.
        logStore.append(action: "Site Post Alert", fields: [
            ("URL", LogSanitizer.url(currentURL)),
            ("DOMAIN", normalizedHost),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("ALERT_CATEGORY", category.rawValue),
            ("RELATED_COOKIE_COUNT", String(relatedCount)),
            ("COOKIE_COUNT_DELTA", previousCount.map { String(relatedCount - $0) } ?? "NO_BASELINE"),
            ("POST_COOKIE", "UNVERIFIED"),
            ("RESULT", "OBSERVED")
        ])
    }

    private func deleteRelatedCookiesForRefresh(identityRefresh: Bool) async {
        guard let webView,
              let host = webView.url?.host?.lowercased() else {
            if identityRefresh {
                finishIdentityRefresh()
            }
            isCookieRefreshing = false
            showToast("Cookie確認失敗", kind: .warning)
            return
        }

        let store = webView.configuration.websiteDataStore.httpCookieStore
        let before = await store.miniBrowserAllCookies()
        let targets = before.filter {
            CookieDomainMatcher.isRelated(cookieDomain: $0.domain, toHost: host)
        }

        if targets.isEmpty, !identityRefresh {
            logCookieRefresh(host: host, before: 0, deleted: 0, after: 0, result: "NO_COOKIE")
            showToast("Cookieなし", kind: .warning)
            isCookieRefreshing = false
            return
        }

        for cookie in targets {
            await store.miniBrowserDelete(cookie)
        }

        let afterDeletion = await store.miniBrowserAllCookies()
        let remaining = afterDeletion.filter {
            CookieDomainMatcher.isRelated(cookieDomain: $0.domain, toHost: host)
        }
        pendingCookieRefresh = PendingCookieRefresh(
            host: host,
            beforeCount: targets.count,
            deletedCount: max(0, targets.count - remaining.count),
            deletionConfirmed: remaining.isEmpty,
            identityRefresh: identityRefresh
        )

        if identityRefresh {
            startCellularReconnect(reloadAfterCompletion: true)
        } else if webView.reload() == nil {
            failPendingCookieRefresh(result: "RELOAD_NOT_STARTED")
        }
    }

    private func updateCurrentURL(_ url: URL?) {
        guard let url, url.scheme != "about" else { return }
        currentURL = url
        urlText = url.absoluteString
        defaults.set(url.absoluteString, forKey: Keys.lastURL)
    }

    private func refreshNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }

    private func executeBookmarklet(_ source: String,
                                    failureMessage: String = "ブックマークレット実行失敗") {
        guard let webView else {
            showToast(failureMessage, kind: .failure)
            return
        }
        let script = Self.bookmarkletScript(from: source)
        // Bookmarklets often leave a DOM node or function as their completion
        // value. Force a bridgeable Boolean result without changing their
        // side effects; genuine JavaScript exceptions still reach the handler.
        let executableScript = "\(script)\n; true;"
        webView.evaluateJavaScript(executableScript) { [weak self] _, error in
            guard let self, let error else { return }
            self.showToast(failureMessage, kind: .failure)
            self.logStore.append(action: "Bookmarklet Execution", fields: [
                ("URL", LogSanitizer.url(self.currentURL)),
                ("UA", "\(self.selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(self.currentUserAgent.name)"),
                ("ERROR_DOMAIN", (error as NSError).domain),
                ("ERROR_CODE", String((error as NSError).code)),
                ("DETAIL", error.localizedDescription),
                ("RESULT", "FAILED")
            ])
        }
    }

    private func runAutomaticBookmarklets(for url: URL?) {
        guard let host = url?.host else { return }
        let matches = bookmarkStore.items.filter {
            $0.kind == .bookmarklet &&
                BookmarkAutoRunMatcher.matches(host: host, configuredDomain: $0.autoRunDomain)
        }
        for item in matches {
            executeBookmarklet(item.content,
                               failureMessage: "自動ブックマークレット実行失敗")
        }
    }

    private static func bookmarkletScript(from source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: String
        if trimmed.lowercased().hasPrefix("javascript:") {
            body = String(trimmed.dropFirst("javascript:".count))
        } else {
            body = source
        }
        return body.removingPercentEncoding ?? body
    }

    private static func javaScriptStringLiteral(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func completeCookieRefreshAfterReload() async {
        guard let pending = pendingCookieRefresh,
              let store = webView?.configuration.websiteDataStore.httpCookieStore else {
            return
        }
        let allAfterReload = await store.miniBrowserAllCookies()
        let after = allAfterReload.filter {
            CookieDomainMatcher.isRelated(cookieDomain: $0.domain, toHost: pending.host)
        }
        let reloadObserved = pending.deletionConfirmed && !after.isEmpty &&
            (pending.beforeCount > 0 || pending.identityRefresh)
        logCookieRefresh(host: pending.host,
                         before: pending.beforeCount,
                         deleted: pending.deletedCount,
                         after: after.count,
                         result: reloadObserved ? "RELOADED_POST_COOKIE_UNVERIFIED" : "FAILED")
        lastRelatedCookieCountByHost[pending.host] = after.count
        showToast(reloadObserved ? "Cookie再読込完了（投稿用は未確認）" : "Cookie再取得失敗",
                  kind: reloadObserved ? .warning : .failure)
        pendingCookieRefresh = nil
        isCookieRefreshing = false
        if pending.identityRefresh {
            finishIdentityRefresh()
        }
    }

    private func failPendingCookieRefresh(result: String) {
        guard let pending = pendingCookieRefresh else { return }
        logCookieRefresh(host: pending.host,
                         before: pending.beforeCount,
                         deleted: pending.deletedCount,
                         after: 0,
                         result: result)
        showToast("Cookie再取得失敗", kind: .failure)
        pendingCookieRefresh = nil
        isCookieRefreshing = false
        if pending.identityRefresh {
            finishIdentityRefresh()
        }
    }

    private func logCookieRefresh(host: String,
                                  before: Int,
                                  deleted: Int,
                                  after: Int,
                                  result: String) {
        logStore.append(action: "Cookie Refresh", fields: [
            ("URL", LogSanitizer.url(currentURL)),
            ("DOMAIN", host),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("COOKIE_BEFORE", String(before)),
            ("COOKIE_DELETED", String(deleted)),
            ("COOKIE_AFTER_RELOAD", String(after)),
            ("POST_COOKIE", "UNVERIFIED"),
            ("RESULT", result)
        ])
    }

    private static func cellularReconnectURL() -> URL? {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: "セルラー再接続"),
            URLQueryItem(name: "x-success", value: "minibrowser://return?status=success"),
            URLQueryItem(name: "x-cancel", value: "minibrowser://return?status=cancel"),
            URLQueryItem(name: "x-error", value: "minibrowser://return?status=error")
        ]
        return components.url
    }

    private static func openExternalURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { opened in
                continuation.resume(returning: opened)
            }
        }
    }

    private func fetchIPv4AfterRecovery() async -> String? {
        let delays: [UInt64] = [1_500_000_000, 2_000_000_000, 3_000_000_000, 4_000_000_000]
        for delay in delays {
            try? await Task.sleep(nanoseconds: delay)
            if let value = try? await ipService.fetchIPv4(userAgent: currentUserAgent.value) {
                return value
            }
        }
        return nil
    }

    private func completeAP(before: String?,
                            after: String?,
                            reloadAfterCompletion: Bool) {
        let result: String
        if let before, let after {
            if before == after {
                result = "IP_UNCHANGED"
                showToast("IP変更なし", kind: .warning)
            } else {
                result = "IP_CHANGED"
                showToast("IP変更済み \(before) → \(after)", kind: .success, duration: 5)
            }
        } else {
            result = "IP_CHECK_FAILED"
            showToast("IP確認失敗", kind: .warning)
        }

        logStore.append(action: "Cellular Reconnect", fields: [
            ("IP_BEFORE", before ?? "UNAVAILABLE"),
            ("IP_AFTER", after ?? "UNAVAILABLE"),
            ("RESULT", result)
        ])
        pendingAP = nil
        isAPRunning = false

        if reloadAfterCompletion {
            guard webView?.reload() != nil else {
                failPendingCookieRefresh(result: "RELOAD_NOT_STARTED")
                return
            }
            return
        }
    }

    private func finishAPFailure(status: String,
                                 before: String?,
                                 reloadAfterCompletion: Bool) {
        showToast("IP確認失敗", kind: .warning)
        logStore.append(action: "Cellular Reconnect", fields: [
            ("IP_BEFORE", before ?? "UNAVAILABLE"),
            ("IP_AFTER", "UNAVAILABLE"),
            ("CALLBACK_STATUS", status),
            ("RESULT", "FAILED")
        ])
        pendingAP = nil
        isAPRunning = false
        if reloadAfterCompletion {
            failPendingCookieRefresh(result: "AP_\(status)")
        }
    }

    private func finishIdentityRefresh() {
        isIdentityRefreshInProgress = false
        isUAChanging = false
    }
}

private extension WKHTTPCookieStore {
    func miniBrowserAllCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            getAllCookies { continuation.resume(returning: $0) }
        }
    }

    func miniBrowserDelete(_ cookie: HTTPCookie) async {
        await withCheckedContinuation { continuation in
            delete(cookie) { continuation.resume() }
        }
    }
}
