import XCTest
@testable import MiniBrowser

final class PageMarkerNamespaceTests: XCTestCase {
    func testNeutralizesOnlyPageVisibleAppMarkers() {
        let source = """
        window.webkit.messageHandlers.miniBrowserHandwriting;
        window.__miniBrowserPageToken;
        window.__miniBrowserInputAutoZoomPreventionInstalled;
        document.querySelector('.minibrowser-targetpage-form');
        """

        let neutralized = PageMarkerNamespace.neutralize(source)

        XCTAssertTrue(neutralized.contains("contentBridge"))
        XCTAssertTrue(neutralized.contains("__pageSessionToken"))
        XCTAssertTrue(neutralized.contains("__inputAutoZoomInstalled"))
        XCTAssertTrue(neutralized.contains(".pagehelper-targetpage-form"))
        XCTAssertFalse(neutralized.contains("miniBrowserHandwriting"))
        XCTAssertFalse(neutralized.contains("__miniBrowser"))
        XCTAssertFalse(neutralized.contains("minibrowser-"))
    }

    func testBridgeNameIsStableAndDoesNotUseProductName() {
        XCTAssertEqual(CanvasImageSessionService.messageHandlerName,
                       PageMarkerNamespace.bridgeName)
        XCTAssertFalse(PageMarkerNamespace.bridgeName.localizedCaseInsensitiveContains("minibrowser"))
    }
}
