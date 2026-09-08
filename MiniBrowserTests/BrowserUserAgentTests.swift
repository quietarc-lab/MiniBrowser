import XCTest
@testable import MiniBrowser

final class BrowserUserAgentTests: XCTestCase {
    func testCatalogContainsFiftyStableUniqueMobileProfiles() {
        XCTAssertEqual(BrowserUserAgent.all.count, 50)
        XCTAssertEqual(Set(BrowserUserAgent.all.map(\.id)).count, 50)
        XCTAssertEqual(Set(BrowserUserAgent.all.map(\.value)).count, 50)
        XCTAssertEqual(BrowserUserAgent.all.prefix(10).map(\.id), Array(1...10))
        XCTAssertTrue(BrowserUserAgent.all.allSatisfy { agent in
            agent.value.contains("AppleWebKit/605.1.15") &&
                agent.value.contains("Mobile/15E148") &&
                (agent.value.contains("iPhone; CPU iPhone OS 18_7") ||
                 agent.value.contains("iPad; CPU OS 18_7"))
        })
    }
}
