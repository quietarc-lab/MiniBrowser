import XCTest
@testable import MiniBrowser

final class InputAutoZoomPreventionServiceTests: XCTestCase {
    func testScriptRaisesOnlySmallEditableControlText() {
        let script = InputAutoZoomPreventionService.scriptSource
        XCTAssertTrue(script.contains("input-helper-no-auto-zoom"))
        XCTAssertTrue(script.contains("input-helper-auto-zoom-style"))
        XCTAssertTrue(script.contains("__inputAutoZoomInstalled"))
        XCTAssertFalse(script.contains("minibrowser"))
        XCTAssertTrue(script.contains("fontSize < 16"))
        XCTAssertTrue(script.contains("font-size: 16px !important"))
        XCTAssertTrue(script.contains("textarea"))
        XCTAssertTrue(script.contains("contenteditable"))
    }

    func testScriptPreservesManualPinchZoom() {
        let script = InputAutoZoomPreventionService.scriptSource
        XCTAssertFalse(script.contains("maximum-scale"))
        XCTAssertFalse(script.contains("user-scalable"))
        XCTAssertFalse(script.contains("pinchGestureRecognizer"))
    }

    func testScriptHandlesFormsAddedAfterPageLoad() {
        let script = InputAutoZoomPreventionService.scriptSource
        XCTAssertTrue(script.contains("MutationObserver"))
        XCTAssertTrue(script.contains("focusin"))
    }
}
