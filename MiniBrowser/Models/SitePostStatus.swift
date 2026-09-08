import Foundation

enum SitePostStatus: String, Equatable {
    case sending = "…"
    case completed = "完了"
}

enum AutomaticPostStatus: String, Equatable {
    case preparingUA = "UA準備中"
    case checkingCookie = "Cookie確認中"
    case sending = "投稿中…"
    case cookieRetry = "Cookie確認後に再送"
    case reconnectingAfterIPLimit = "IP制限 → AP再接続中"
    case finalSendAfterIPChange = "IP変更後に最終送信"
    case completed = "完了"
    case stopped = "自動投稿停止"

    var isFinal: Bool {
        switch self {
        case .completed, .stopped:
            return true
        case .preparingUA, .checkingCookie, .sending, .cookieRetry,
             .reconnectingAfterIPLimit, .finalSendAfterIPChange:
            return false
        }
    }
}
