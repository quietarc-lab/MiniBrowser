import XCTest
@testable import MiniBrowser

final class BrowserUserAgentTests: XCTestCase {
    func testCatalogContainsOneHundredStableUniqueMobileProfiles() {
        XCTAssertEqual(BrowserUserAgent.all.count, 100)
        XCTAssertEqual(BrowserUserAgent.all.map(\.id), Array(1...100))
        XCTAssertEqual(Set(BrowserUserAgent.all.map(\.id)).count, 100)
        XCTAssertEqual(Set(BrowserUserAgent.all.map(\.name)).count, 100)
        XCTAssertEqual(Set(BrowserUserAgent.all.map(\.value)).count, 100)
        XCTAssertEqual(BrowserUserAgent.all.filter { $0.value.contains("(iPhone;") }.count, 50)
        XCTAssertEqual(BrowserUserAgent.all.filter { $0.value.contains("(iPad;") }.count, 50)
        XCTAssertTrue(BrowserUserAgent.all.allSatisfy { agent in
            agent.value.contains("AppleWebKit/605.1.15") &&
                agent.value.contains("Mobile/15E148") &&
                (agent.value.contains("iPhone; CPU iPhone OS 18_7") ||
                 agent.value.contains("iPad; CPU OS 18_7"))
        })
    }

    func testCatalogVersionMarksReplacement() {
        XCTAssertEqual(BrowserUserAgent.catalogVersion, 2)
    }
}
