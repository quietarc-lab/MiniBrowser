import XCTest
@testable import MiniBrowser

final class SitePostStatusTests: XCTestCase {
    func testOnlyTheTwoSiteMarkersAreRepresented() {
        XCTAssertEqual(SitePostStatus(rawValue: "…"), .sending)
        XCTAssertEqual(SitePostStatus(rawValue: "完了"), .completed)
        XCTAssertNil(SitePostStatus(rawValue: "エラー"))
        XCTAssertNil(SitePostStatus(rawValue: ""))
    }
}
