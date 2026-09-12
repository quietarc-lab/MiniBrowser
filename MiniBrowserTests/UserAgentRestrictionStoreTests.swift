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

    func testClearAllRemovesCatalogSpecificRestrictions() {
        let defaults = UserDefaults(suiteName: "UserAgentRestrictionStoreTests.clearAll")!
        defaults.removePersistentDomain(forName: "UserAgentRestrictionStoreTests.clearAll")
        defer { defaults.removePersistentDomain(forName: "UserAgentRestrictionStoreTests.clearAll") }
        let store = UserAgentRestrictionStore(defaults: defaults,
                                               storageKey: "expiries")
        store.restrict(1)
        store.restrict(100)

        store.clearAll()

        XCTAssertTrue(store.restrictedIDs().isEmpty)
        XCTAssertNil(defaults.object(forKey: "expiries"))
    }

    func testGeneratedKeyIsStableForTheInstallAndDoesNotStoreTheRawValue() {
        let suiteName = "UserAgentRestrictionStoreTests.generatedKey.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserAgentRestrictionStore(defaults: defaults,
                                               storageKey: "expiries")
        let value = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)"

        let first = store.generatedRestrictionKey(for: value)
        let second = store.generatedRestrictionKey(for: value)

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix("generated:"))
        XCTAssertFalse(first.contains(value))
        XCTAssertNil(defaults.object(forKey: "expiries"))
    }

    func testGeneratedRestrictionExpiresAndIsNotReturnedAsFixedID() {
        let suiteName = "UserAgentRestrictionStoreTests.generatedExpiry.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var now = Date(timeIntervalSince1970: 2_000_000)
        let store = UserAgentRestrictionStore(
            defaults: defaults,
            storageKey: "expiries",
            now: { now }
        )
        let key = store.generatedRestrictionKey(for: "generated-value")
        let expiry = store.restrict(key)

        XCTAssertTrue(store.isRestricted(key))
        XCTAssertTrue(store.restrictedIDs().isEmpty)
        now = expiry.addingTimeInterval(1)
        XCTAssertFalse(store.isRestricted(key))
        XCTAssertFalse(store.restrictedKeys().contains(key))
    }
}
