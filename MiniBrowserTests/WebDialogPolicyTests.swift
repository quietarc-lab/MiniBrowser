import XCTest
@testable import MiniBrowser

final class WebDialogPolicyTests: XCTestCase {
    func testSiteAlertsAreNeverAutoDismissed() {
        XCTAssertFalse(WebDialogPolicy.shouldAutoDismissAlert(
            host: "img.2chan.net",
            message: "cookieを有効にしてもう一度送信してください"
        ))
        XCTAssertFalse(WebDialogPolicy.shouldAutoDismissAlert(
            host: "IMG.2CHAN.NET",
            message: "cookieを有効にして\nもう一度送信してください"
        ))
        XCTAssertFalse(WebDialogPolicy.shouldAutoDismissAlert(
            host: "img.2chan.net",
            message: "cookieが無いので投稿できません"
        ))
        XCTAssertFalse(WebDialogPolicy.shouldAutoDismissAlert(
            host: "example.com",
            message: "cookieを有効にしてもう一度送信してください"
        ))
    }

    func testTargetPageAlertClassifierOnlyRecordsKnownTargetErrors() {
        XCTAssertEqual(
            TargetPageAlertClassifier.category(
                host: "img.2chan.net",
                message: "cookieを有効にして\nもう一度送信してください"
            ),
            .cookieRetryRequired
        )
        XCTAssertEqual(
            TargetPageAlertClassifier.category(
                host: "img.2chan.net",
                message: "あなたのIPアドレスからは画像を投稿できません"
            ),
            .imagePostingRestricted
        )
        XCTAssertNil(TargetPageAlertClassifier.category(
            host: "example.com",
            message: "cookieを有効にしてもう一度送信してください"
        ))
        XCTAssertNil(TargetPageAlertClassifier.category(
            host: "img.2chan.net",
            message: "任意のエラー本文"
        ))
        XCTAssertNil(TargetPageAlertClassifier.category(
            host: "img.2chan.net",
            message: "cookieを有効にしてもう一度送信してください。"
        ))
        XCTAssertNil(TargetPageAlertClassifier.category(
            host: "img.2chan.net",
            message: "あなたのIPアドレスからは画像を投稿できません（再試行）"
        ))
    }
}
