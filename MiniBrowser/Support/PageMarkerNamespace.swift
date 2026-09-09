import Foundation

/// Replaces app-branded page markers before helper scripts are injected.
///
/// The app display name and bundle identifier remain unchanged. Keeping this
/// rewrite in one place makes the privacy change easy to review and revert
/// without changing posting behavior.
enum PageMarkerNamespace {
    static let bridgeName = "contentBridge"
    static let pageTokenName = "__pageSessionToken"

    static func neutralize(_ source: String) -> String {
        source
            .replacingOccurrences(of: "miniBrowserHandwriting", with: bridgeName)
            .replacingOccurrences(of: "__miniBrowserPageToken", with: pageTokenName)
            .replacingOccurrences(of: "__miniBrowserInputAutoZoomPreventionInstalled",
                                  with: "__inputAutoZoomInstalled")
            .replacingOccurrences(of: "minibrowser", with: "pagehelper")
    }
}
