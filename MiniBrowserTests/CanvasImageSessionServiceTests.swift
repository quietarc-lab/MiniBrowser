import XCTest
@testable import MiniBrowser

final class CanvasImageSessionServiceTests: XCTestCase {
    func testThreadScopeAcceptsOnlyTargetPageThreadPages() {
        XCTAssertTrue(CanvasImageSessionService.isTargetPageThreadURL(
            URL(string: "https://img.2chan.net/b/res/1465000000.htm")
        ))
        XCTAssertFalse(CanvasImageSessionService.isTargetPageThreadURL(
            URL(string: "https://img.2chan.net/b/futaba.php?mode=cat")
        ))
        XCTAssertFalse(CanvasImageSessionService.isTargetPageThreadURL(
            URL(string: "https://example.com/b/res/1465000000.htm")
        ))
    }

    func testBridgeCapturesOnlyExistingHandwritingInputAndRestoresOnePixel() throws {
        let script = CanvasImageSessionService.scriptSource
        XCTAssertTrue(script.contains("input.id !== \"itgkfile\""))
        XCTAssertTrue(script.contains("canvas#oejs"))
        XCTAssertTrue(script.contains("selectedImage"))
        XCTAssertTrue(script.contains("canvasReady"))
        XCTAssertTrue(script.contains("pageReady"))
        XCTAssertFalse(script.contains("localStorage"))
        XCTAssertFalse(script.contains("sessionStorage"))

        let store = TargetPageHandwritingImageStore()
        XCTAssertTrue(store.replace(withDataURL: "data:image/png;base64,AAECAwQ="))
        let restoration = try XCTUnwrap(store.restorationScript())
        XCTAssertTrue(restoration.contains("context.fillRect(x, y, 1, 1)"))
        XCTAssertTrue(restoration.contains("canvas#oejs"))
        XCTAssertTrue(CanvasImageSessionService.openExistingCanvasScript.contains("手書きjs"))
        XCTAssertTrue(CanvasImageSessionService.openExistingCanvasScript.contains("trigger.click()"))
        XCTAssertTrue(CanvasImageSessionService.openExistingCanvasScript.contains("#oebtnj"))
        XCTAssertTrue(CanvasImageSessionService.openExistingCanvasScript.contains("getComputedStyle"))
        XCTAssertTrue(CanvasImageSessionService.openExistingCanvasScript.contains("attempts < 50"))
    }

    func testStoreRejectsUnsupportedAndCreatesNoCrossLaunchState() {
        let store = TargetPageHandwritingImageStore()
        XCTAssertFalse(store.replace(withDataURL: "data:text/plain;base64,SGVsbG8="))
        XCTAssertFalse(store.hasImage)
        XCTAssertFalse(TargetPageHandwritingImageStore().hasImage)
    }
}
