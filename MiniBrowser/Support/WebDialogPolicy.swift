import Foundation

enum TargetPageAlertCategory: String, Equatable {
    case cookieRetryRequired = "COOKIE_RETRY_REQUIRED"
    case imagePostingRestricted = "IMAGE_POSTING_RESTRICTED"
}

enum TargetPageAlertClassifier {
    private static let targetHost = "img.2chan.net"

    static func category(host: String?, message: String) -> TargetPageAlertCategory? {
        guard host?.lowercased() == targetHost else { return nil }

        let normalized = message
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()

        if normalized.contains("cookieを有効にしてもう一度送信してください") {
            return .cookieRetryRequired
        }
        if normalized.contains("あなたのipアドレスからは画像を投稿できません") {
            return .imagePostingRestricted
        }
        return nil
    }
}

enum WebDialogPolicy {
    static func shouldAutoDismissAlert(host: String?, message: String) -> Bool {
        // Site-side errors, including the target page's Cookie error, must
        // remain visible so the user can diagnose the current state.
        _ = host
        _ = message
        return false
    }
}
