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
    @Published private(set) var automaticPostStatus: AutomaticPostStatus? = nil

    let bookmarkStore: BookmarkStore

    weak var webView: WKWebView?
    private let defaults: UserDefaults
    private let logStore: DebugLogStore
    private let ipService: IPAddressService
    private var selectedUAIndex: Int
    private var pendingCookieRefresh: PendingCookieRefresh?
    private var pendingAP: PendingAP?
    private var lastRelatedCookieCountByHost: [String: Int] = [:]
    private var automaticPostMachine = AutomaticPostFlowMachine()
    private var automaticPostGeneration: UInt64 = 0
    private var pendingUAChangeGeneration: UInt64?
    private var automaticReloadGeneration: UInt64?
    private var automaticPostPreparationTimer: Task<Void, Never>?
    private var automaticPostStatusTask: Task<Void, Never>?
    private var latestCompactReady: (pageToken: String, hasComment: Bool, canSubmit: Bool)?
    private var handwritingImageAvailable = false
    private var automaticCookieRelatedCount: Int?
    private var automaticCookieCountDelta: Int?
    private var automaticAPResult = "NOT_REQUESTED"

    private struct PendingCookieRefresh {
        let host: String
        let beforeCount: Int
        let deletedCount: Int
        let deletionConfirmed: Bool
        let identityRefresh: Bool
        let automaticGenerationID: UInt64?
    }

    private enum APPurpose {
        case manual
        case identityRefresh(generationID: UInt64)
        case automaticIPRetry(generationID: UInt64)
    }

    private struct PendingAP {
        let beforeIPv4: String?
        let reloadAfterCompletion: Bool
        let purpose: APPurpose
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
        isUAChanging = true
        automaticPostGeneration &+= 1
        let generationID = automaticPostGeneration
        pendingUAChangeGeneration = generationID
        let oldPageToken = latestCompactReady?.pageToken
        let imageAvailable = handwritingImageAvailable
        let pageURL = webView.url

        // Read the current draft before changing the UA. This is deliberately
        // read-only: it never submits or mutates the page.
        webView.evaluateJavaScript(CompactPageModeService.currentPostStateScript) {
            [weak self] result, error in
            guard let self,
                  self.pendingUAChangeGeneration == generationID else { return }
            let state = Self.postState(from: result)
            let hasComment = state?.hasComment ?? false
            let canSubmit = state?.canSubmit ?? false
            let isTarget = Self.isTargetThreadURL(pageURL)
            let shouldStartAutomatic = isTarget && canSubmit && (hasComment || imageAvailable)
            self.startUserAgentChange(
                pageURL: pageURL,
                generationID: generationID,
                oldPageToken: oldPageToken,
                hasComment: hasComment,
                hasImage: imageAvailable,
                automatic: shouldStartAutomatic,
                readError: error != nil
            )
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
            await self?.deleteRelatedCookiesForRefresh(identityRefresh: false,
                                                       automaticGenerationID: nil)
        }
    }

    private func startUserAgentChange(pageURL: URL?,
                                      generationID: UInt64,
                                      oldPageToken: String?,
                                      hasComment: Bool,
                                      hasImage: Bool,
                                      automatic: Bool,
                                      readError: Bool) {
        guard let webView else {
            isUAChanging = false
            return
        }
        pendingUAChangeGeneration = nil

        selectedUAIndex = (selectedUAIndex + 1) % BrowserUserAgent.all.count
        defaults.set(selectedUAIndex, forKey: Keys.userAgentIndex)
        webView.customUserAgent = currentUserAgent.value
        isIdentityRefreshInProgress = true

        automaticPostPreparationTimer?.cancel()
        automaticPostStatusTask?.cancel()
        latestCompactReady = nil
        automaticCookieRelatedCount = nil
        automaticCookieCountDelta = nil
        automaticAPResult = automatic ? "PENDING" : "NOT_REQUESTED"

        automaticPostMachine.reset()
        if automatic && !readError {
            _ = automaticPostMachine.begin(generationID: generationID,
                                           oldPageToken: oldPageToken,
                                           hasComment: hasComment,
                                           hasImage: hasImage)
            setAutomaticPostStatus(.preparingUA, generationID: generationID)
            startAutomaticPostPreparationTimeout(generationID: generationID)
        }

        showToast("UA変更後にCookie更新とAP再接続を開始します", kind: .success)
        logStore.append(action: "User Agent Change", fields: [
            ("URL", LogSanitizer.url(pageURL)),
            ("UA", "\(selectedUAIndex + 1)/\(BrowserUserAgent.all.count) \(currentUserAgent.name)"),
            ("RESULT", "CHANGED")
        ])

        Task { [weak self] in
            await self?.deleteRelatedCookiesForRefresh(
                identityRefresh: true,
                automaticGenerationID: automatic && !readError ? generationID : nil
            )
        }
    }

    func startCellularReconnect() {
        startCellularReconnect(reloadAfterCompletion: false, purpose: .manual)
    }

    private func startCellularReconnect(reloadAfterCompletion: Bool,
                                        purpose: APPurpose) {
        guard !isAPRunning else { return }
        isAPRunning = true

        Task { [weak self] in
            guard let self else { return }
            let before = try? await ipService.fetchIPv4(userAgent: currentUserAgent.value)
            self.pendingAP = PendingAP(beforeIPv4: before,
                                       reloadAfterCompletion: reloadAfterCompletion,
                                       purpose: purpose)

            guard let shortcutURL = Self.cellularReconnectURL(),
                  await Self.openExternalURL(shortcutURL) else {
                self.finishAPFailure(status: "SHORTCUT_OPEN_FAILED",
                                     before: before,
                                     reloadAfterCompletion: reloadAfterCompletion,
                                     purpose: purpose)
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
        if automaticPostMachine.isActive,
           let generationID = automaticPostMachine.generationID,
           automaticReloadGeneration != generationID {
            stopAutomaticPost(.preparationFailed, generationID: generationID)
        }
        automaticReloadGeneration = nil
        isLoading = true
        sitePostStatus = nil
        latestCompactReady = nil
        refreshNavigationState()
    }

    func updateSitePostStatus(_ rawStatus: String?) {
        sitePostStatus = rawStatus.flatMap(SitePostStatus.init(rawValue:))
    }

    func setHandwritingImageAvailable(_ available: Bool) {
        handwritingImageAvailable = available
    }

    func shouldIgnoreAutomaticPageToken(_ pageToken: String) -> Bool {
        automaticPostMachine.isStalePageToken(pageToken)
    }

    func handleCompactReady(pageToken: String,
                            hasComment: Bool,
                            canSubmit: Bool) {
        guard automaticPostMachine.isActive,
              let generationID = automaticPostMachine.generationID else {
            latestCompactReady = (pageToken, hasComment, canSubmit)
            return
        }
        let effect = automaticPostMachine.handle(.markCompactReady(
            generationID: generationID,
            pageToken: pageToken,
            hasComment: hasComment,
            canSubmit: canSubmit
        ))
        guard automaticPostMachine.pageToken == pageToken else { return }
        latestCompactReady = (pageToken, hasComment, canSubmit)
        handleAutomaticPostEffect(effect, generationID: generationID)
    }

    func handleHandwritingReady(pageToken: String, ready: Bool) {
        guard automaticPostMachine.isActive,
              let generationID = automaticPostMachine.generationID else { return }
        let effect = automaticPostMachine.handle(.markHandwritingReady(
            generationID: generationID,
            pageToken: pageToken,
            ready: ready
        ))
        handleAutomaticPostEffect(effect, generationID: generationID)
    }

    func handlePostStatus(_ rawStatus: String?, pageToken: String?) {
        if automaticPostMachine.isActive {
            guard let pageToken,
                  automaticPostMachine.pageToken == pageToken else { return }
        }
        updateSitePostStatus(rawStatus)
        guard automaticPostMachine.isActive,
              let generationID = automaticPostMachine.generationID,
              let pageToken,
              automaticPostMachine.pageToken == pageToken else { return }
        if rawStatus == SitePostStatus.sending.rawValue {
            setAutomaticPostStatus(.sending, generationID: generationID)
        } else if rawStatus == SitePostStatus.completed.rawValue {
            let effect = automaticPostMachine.handle(.postCompleted(generationID: generationID))
            handleAutomaticPostEffect(effect, generationID: generationID)
        }
    }

    func handlePostCompleted(pageToken: String?) {
        guard automaticPostMachine.isActive,
              let generationID = automaticPostMachine.generationID,
              let pageToken,
              automaticPostMachine.pageToken == pageToken else { return }
        let effect = automaticPostMachine.handle(.postCompleted(generationID: generationID))
        handleAutomaticPostEffect(effect, generationID: generationID)
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
        if let pending = pendingCookieRefresh,
           let generationID = pending.automaticGenerationID,
           automaticPostMachine.isActive,
           automaticPostMachine.generationID == generationID,
           Self.isTargetThreadURL(url) {
            let effect = automaticPostMachine.handle(.markReloadCompleted(generationID: generationID))
            handleAutomaticPostEffect(effect, generationID: generationID)
        }
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
        stopAutomaticPost(.preparationFailed, generationID: automaticPostMachine.generationID)
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
        stopAutomaticPost(.preparationTimeout, generationID: automaticPostMachine.generationID)
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
                            reloadAfterCompletion: context.reloadAfterCompletion,
                            purpose: context.purpose)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let after = await self.fetchIPv4AfterRecovery()
            self.completeAP(before: context.beforeIPv4,
                            after: after,
                            reloadAfterCompletion: context.reloadAfterCompletion,
                            purpose: context.purpose)
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

    func handleTargetPageAlert(_ category: TargetPageAlertCategory,
                               host: String) -> TargetPageAlertDisposition {
        Task { [weak self] in
            await self?.recordTargetPageAlert(category, host: host)
        }

        guard automaticPostMachine.isActive,
              let generationID = automaticPostMachine.generationID else {
            return .showNormally
        }

        let alert: AutomaticPostAlert
        switch category {
        case .cookieRequired:
            alert = .cookieRetryRequired
        case .imagePostingRestricted:
            alert = .imagePostingRestricted
        }
        let result = automaticPostMachine.handleAlert(alert, generationID: generationID)
        handleAutomaticPostEffect(result.effect, generationID: generationID)
        if result.autoDismiss {
            guard automaticPostMachine.isActive else { return .autoDismiss }
            switch alert {
            case .cookieRetryRequired:
                setAutomaticPostStatus(.cookieRetry, generationID: generationID)
                Task { @MainActor [weak self] in
                    await Task.yield()
                    guard let self,
                          self.automaticPostMachine.generationID == generationID else { return }
                    let effect = self.automaticPostMachine.handle(
                        .cookieAlertDismissed(generationID: generationID)
                    )
                    self.handleAutomaticPostEffect(effect, generationID: generationID)
                }
            case .imagePostingRestricted:
                setAutomaticPostStatus(.reconnectingAfterIPLimit, generationID: generationID)
            }
            return .autoDismiss
        }
        return .showNormally
    }

    func handleUnknownJavaScriptAlert() {
        stopAutomaticPost(.unknownAlert, generationID: automaticPostMachine.generationID)
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
        if automaticPostMachine.isActive {
            automaticCookieRelatedCount = relatedCount
            automaticCookieCountDelta = previousCount.map { relatedCount - $0 }
        }

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

    private func deleteRelatedCookiesForRefresh(identityRefresh: Bool,
                                                automaticGenerationID: UInt64?) async {
        guard let webView,
              let host = webView.url?.host?.lowercased() else {
            if identityRefresh {
                finishIdentityRefresh()
            }
            if let automaticGenerationID {
                stopAutomaticPost(.preparationFailed, generationID: automaticGenerationID)
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
            identityRefresh: identityRefresh,
            automaticGenerationID: automaticGenerationID
        )
        if let automaticGenerationID {
            setAutomaticPostStatus(.checkingCookie, generationID: automaticGenerationID)
        }

        if identityRefresh {
            let purpose: APPurpose = automaticGenerationID.map {
                .identityRefresh(generationID: $0)
            } ?? .manual
            startCellularReconnect(reloadAfterCompletion: true, purpose: purpose)
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
        guard let pending = pendingCookieRefresh else {
            return
        }
        guard let store = webView?.configuration.websiteDataStore.httpCookieStore else {
            pendingCookieRefresh = nil
            isCookieRefreshing = false
            if pending.identityRefresh { finishIdentityRefresh() }
            if let generationID = pending.automaticGenerationID {
                stopAutomaticPost(.preparationFailed, generationID: generationID)
            }
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
        if pending.automaticGenerationID != nil {
            let previousCount = lastRelatedCookieCountByHost[pending.host]
            automaticCookieRelatedCount = after.count
            automaticCookieCountDelta = previousCount.map { after.count - $0 }
        }
        lastRelatedCookieCountByHost[pending.host] = after.count
        showToast(reloadObserved ? "Cookie再読込完了（投稿用は未確認）" : "Cookie再取得失敗",
                  kind: reloadObserved ? .warning : .failure)
        pendingCookieRefresh = nil
        isCookieRefreshing = false
        if pending.identityRefresh {
            finishIdentityRefresh()
        }
        if let generationID = pending.automaticGenerationID {
            guard reloadObserved else {
                stopAutomaticPost(.preparationFailed, generationID: generationID)
                return
            }
            let effect = automaticPostMachine.handle(.markCookieObserved(generationID: generationID))
            handleAutomaticPostEffect(effect, generationID: generationID)
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
        if let generationID = pending.automaticGenerationID {
            stopAutomaticPost(.preparationFailed, generationID: generationID)
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
                            reloadAfterCompletion: Bool,
                            purpose: APPurpose) {
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

        switch purpose {
        case let .identityRefresh(generationID):
            guard automaticPostMachine.generationID == generationID else { break }
            automaticAPResult = after == nil ? "FAILED" : "COMPLETED"
            guard after != nil else {
                stopAutomaticPost(.preparationFailed, generationID: generationID)
                return
            }
            let effect = automaticPostMachine.handle(.markAPCompleted(generationID: generationID))
            handleAutomaticPostEffect(effect, generationID: generationID)
        case let .automaticIPRetry(generationID):
            guard automaticPostMachine.generationID == generationID else { break }
            automaticAPResult = after == nil ? "FAILED" : "RECONNECTED"
            guard after != nil else {
                stopAutomaticPost(.communicationFailure, generationID: generationID)
                return
            }
            let effect = automaticPostMachine.handle(
                .ipReconnectCompleted(generationID: generationID, success: true)
            )
            handleAutomaticPostEffect(effect, generationID: generationID)
            scheduleIPRetrySubmit(generationID: generationID)
        case .manual:
            break
        }

        if reloadAfterCompletion {
            if case let .identityRefresh(generationID) = purpose,
               automaticPostMachine.generationID == generationID {
                automaticReloadGeneration = generationID
            }
            guard webView?.reload() != nil else {
                automaticReloadGeneration = nil
                failPendingCookieRefresh(result: "RELOAD_NOT_STARTED")
                return
            }
            return
        }
    }

    private func finishAPFailure(status: String,
                                 before: String?,
                                 reloadAfterCompletion: Bool,
                                 purpose: APPurpose) {
        showToast("IP確認失敗", kind: .warning)
        logStore.append(action: "Cellular Reconnect", fields: [
            ("IP_BEFORE", before ?? "UNAVAILABLE"),
            ("IP_AFTER", "UNAVAILABLE"),
            ("CALLBACK_STATUS", status),
            ("RESULT", "FAILED")
        ])
        pendingAP = nil
        isAPRunning = false
        switch purpose {
        case .manual:
            break
        case let .identityRefresh(generationID):
            if automaticPostMachine.generationID == generationID {
                automaticAPResult = "FAILED"
            }
        case let .automaticIPRetry(generationID):
            if automaticPostMachine.generationID == generationID {
                automaticAPResult = "FAILED"
            }
        }
        if reloadAfterCompletion {
            failPendingCookieRefresh(result: "AP_\(status)")
        }
        if case let .identityRefresh(generationID) = purpose {
            stopAutomaticPost(.preparationFailed, generationID: generationID)
        } else if case let .automaticIPRetry(generationID) = purpose {
            stopAutomaticPost(.communicationFailure, generationID: generationID)
        }
    }

    private func handleAutomaticPostEffect(_ effect: AutomaticPostFlowEffect,
                                           generationID: UInt64) {
        guard automaticPostMachine.generationID == generationID else { return }
        switch effect {
        case .none:
            break
        case .scheduleInitialSubmit:
            setAutomaticPostStatus(.checkingCookie, generationID: generationID)
            scheduleInitialSubmit(generationID: generationID)
        case let .submit(attempt):
            submitAutomatically(attempt: attempt, generationID: generationID)
        case .startIPReconnect:
            setAutomaticPostStatus(.reconnectingAfterIPLimit, generationID: generationID)
            startCellularReconnect(
                reloadAfterCompletion: false,
                purpose: .automaticIPRetry(generationID: generationID)
            )
        case .succeeded:
            setAutomaticPostStatus(.completed, generationID: generationID)
            finishAutomaticPost(generationID: generationID, result: "SUCCEEDED")
        case let .stopped(reason):
            setAutomaticPostStatus(.stopped, generationID: generationID)
            finishAutomaticPost(generationID: generationID,
                                result: "STOPPED_\(String(describing: reason).uppercased())")
        }
    }

    private func scheduleInitialSubmit(generationID: UInt64) {
        automaticPostPreparationTimer?.cancel()
        automaticPostPreparationTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.automaticPostMachine.generationID == generationID else { return }
            let effect = self.automaticPostMachine.handle(
                .initialSubmitDelayElapsed(generationID: generationID)
            )
            self.handleAutomaticPostEffect(effect, generationID: generationID)
        }
    }

    private func scheduleIPRetrySubmit(generationID: UInt64) {
        automaticPostPreparationTimer?.cancel()
        automaticPostPreparationTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.automaticPostMachine.generationID == generationID else { return }
            self.setAutomaticPostStatus(.finalSendAfterIPChange, generationID: generationID)
            let effect = self.automaticPostMachine.handle(
                .ipSubmitDelayElapsed(generationID: generationID)
            )
            self.handleAutomaticPostEffect(effect, generationID: generationID)
        }
    }

    private func submitAutomatically(attempt: Int, generationID: UInt64) {
        guard automaticPostMachine.generationID == generationID,
              let webView else {
            stopAutomaticPost(.communicationFailure, generationID: generationID)
            return
        }
        setAutomaticPostStatus(attempt == 3 ? .finalSendAfterIPChange : .sending,
                                generationID: generationID)
        logStore.append(action: "Automatic Post", fields: [
            ("ATTEMPT", String(attempt)),
            ("BRANCH", attempt == 1 ? "INITIAL" : (attempt == 2 ? "COOKIE_RETRY" : "IP_RETRY")),
            ("COOKIE_RELATED_COUNT", automaticCookieRelatedCount.map { String($0) } ?? "UNAVAILABLE"),
            ("COOKIE_COUNT_DELTA", automaticCookieCountDelta.map { String($0) } ?? "UNAVAILABLE"),
            ("AP_RESULT", automaticAPResult),
            ("RESULT", "SUBMIT_STARTED")
        ])
        webView.evaluateJavaScript(CompactPageModeService.autoSubmitScript) {
            [weak self] result, error in
            guard let self,
                  self.automaticPostMachine.generationID == generationID,
                  self.automaticPostMachine.currentAttempt == attempt else { return }
            if case .waitingForCookieRetry = self.automaticPostMachine.state {
                return
            }
            if case .waitingForIPRetry = self.automaticPostMachine.state {
                return
            }
            let didClick = (result as? Bool) ?? false
            guard error == nil, didClick else {
                let effect = self.automaticPostMachine.handle(
                    .fail(generationID: generationID, reason: .communicationFailure)
                )
                self.handleAutomaticPostEffect(effect, generationID: generationID)
                return
            }
        }
    }

    private func startAutomaticPostPreparationTimeout(generationID: UInt64) {
        automaticPostPreparationTimer?.cancel()
        automaticPostPreparationTimer = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.automaticPostMachine.generationID == generationID,
                  case .preparing = self.automaticPostMachine.state else { return }
            let effect = self.automaticPostMachine.handle(
                .fail(generationID: generationID, reason: .preparationTimeout)
            )
            self.handleAutomaticPostEffect(effect, generationID: generationID)
        }
    }

    private func stopAutomaticPost(_ reason: AutomaticPostStopReason,
                                   generationID: UInt64?) {
        guard let generationID,
              automaticPostMachine.generationID == generationID,
              automaticPostMachine.isActive else { return }
        let effect = automaticPostMachine.handle(
            .fail(generationID: generationID, reason: reason)
        )
        handleAutomaticPostEffect(effect, generationID: generationID)
    }

    private func finishAutomaticPost(generationID: UInt64, result: String) {
        guard automaticPostMachine.generationID == generationID else { return }
        automaticPostPreparationTimer?.cancel()
        logStore.append(action: "Automatic Post", fields: [
            ("ATTEMPT", String(automaticPostMachine.lastAttempt)),
            ("BRANCH", "FINAL"),
            ("COOKIE_RELATED_COUNT", automaticCookieRelatedCount.map { String($0) } ?? "UNAVAILABLE"),
            ("COOKIE_COUNT_DELTA", automaticCookieCountDelta.map { String($0) } ?? "UNAVAILABLE"),
            ("AP_RESULT", automaticAPResult),
            ("RESULT", result)
        ])
        automaticPostStatusTask?.cancel()
        automaticPostStatusTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard let self,
                  !Task.isCancelled,
                  self.automaticPostMachine.generationID == generationID else { return }
            self.automaticPostStatus = nil
        }
    }

    private func setAutomaticPostStatus(_ status: AutomaticPostStatus,
                                        generationID: UInt64) {
        guard automaticPostMachine.generationID == generationID else { return }
        automaticPostStatusTask?.cancel()
        automaticPostStatus = status
    }

    private static func postState(from result: Any?) -> (hasComment: Bool,
                                                          canSubmit: Bool)? {
        guard let dictionary = result as? [String: Any] else { return nil }
        guard let eligible = dictionary["eligible"] as? Bool, eligible else { return nil }
        return (dictionary["hasComment"] as? Bool ?? false,
                dictionary["canSubmit"] as? Bool ?? false)
    }

    private static func isTargetThreadURL(_ url: URL?) -> Bool {
        CanvasImageSessionService.isTargetPageThreadURL(url)
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
