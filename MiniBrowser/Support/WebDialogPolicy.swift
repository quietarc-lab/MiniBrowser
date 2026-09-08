import Foundation

enum WebDialogPolicy {
    static func shouldAutoDismissAlert(host: String?, message: String) -> Bool {
        // Site-side errors, including the target page's Cookie error, must
        // remain visible so the user can diagnose the current state.
        _ = host
        _ = message
        return false
    }
}
