import XCTest
@testable import MiniBrowser

final class UserAgentRestrictionStoreTests: XCTestCase {
    func testRestrictionPersistsForSevenDaysAndExpires() {
        let defaults = UserDefaults(suiteName: "UserAgentRestrictionStoreTests.expiry")!
        defaults.removePersistentDomain(forName: "UserAgentRestrictionStoreTests.expiry")
        var now = Date(timeIntervalSince1970: 1_000_000)
        var store = UserAgentRestrictionStore(
            defaults: defaults,
            storageKey: "expiries",
            now: { now }
        )

        let expiry = store.restrict(17)
        XCTAssertEqual(expiry.timeIntervalSince(now), UserAgentRestrictionStore.defaultDuration)
        XCTAssertTrue(store.isRestricted(17))
        XCTAssertTrue(store.restrictedIDs().contains(17))

        now = expiry.addingTimeInterval(1)
        XCTAssertFalse(store.isRestricted(17))
        XCTAssertFalse(store.restrictedIDs().contains(17))
    }

    func testRestrictionCanBeClearedAndOtherIDsRemain() {
        let defaults = UserDefaults(suiteName: "UserAgentRestrictionStoreTests.clear")!
        defaults.removePersistentDomain(forName: "UserAgentRestrictionStoreTests.clear")
        let store = UserAgentRestrictionStore(defaults: defaults,
                                               storageKey: "expiries")
        store.restrict(1)
        store.restrict(2)
        store.clear(1)
        XCTAssertFalse(store.isRestricted(1))
        XCTAssertTrue(store.isRestricted(2))
    }
}
