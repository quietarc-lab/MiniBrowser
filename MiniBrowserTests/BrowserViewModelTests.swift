import Foundation
import XCTest
@testable import MiniBrowser

@MainActor
final class BrowserViewModelTests: XCTestCase {
    func testCatalogReplacementResetsLegacySelectionAndRestrictions() {
        let suiteName = "BrowserViewModelTests.catalogReplacement.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(49, forKey: "userAgentIndex")
        defaults.set(50, forKey: "userAgentID")
        defaults.set(["50": Date().addingTimeInterval(86_400).timeIntervalSince1970],
                     forKey: "userAgentRestrictionExpiries")

        let model = BrowserViewModel(defaults: defaults)

        XCTAssertEqual(model.userAgentButtonTitle, "UA 1/100")
        XCTAssertEqual(model.currentUserAgent.id, 1)
        XCTAssertEqual(defaults.integer(forKey: "userAgentIndex"), 0)
        XCTAssertEqual(defaults.integer(forKey: "userAgentID"), 1)
        XCTAssertEqual(defaults.integer(forKey: "userAgentCatalogVersion"),
                       BrowserUserAgent.catalogVersion)
        XCTAssertNil(defaults.object(forKey: "userAgentRestrictionExpiries"))
    }

    func testCurrentCatalogKeepsSelectedProfileAcrossViewModels() {
        let suiteName = "BrowserViewModelTests.catalogPersistence.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let selectedIndex = 42
        defaults.set(BrowserUserAgent.catalogVersion, forKey: "userAgentCatalogVersion")
        defaults.set(selectedIndex, forKey: "userAgentIndex")
        defaults.set(BrowserUserAgent.all[selectedIndex].id, forKey: "userAgentID")

        let model = BrowserViewModel(defaults: defaults)

        XCTAssertEqual(model.userAgentButtonTitle, "UA 43/100")
        XCTAssertEqual(model.currentUserAgent.id, BrowserUserAgent.all[selectedIndex].id)
    }
}
