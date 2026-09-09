import Foundation

struct UserAgentRestrictionStore {
    static let defaultDuration: TimeInterval = 7 * 24 * 60 * 60

    private let defaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date

    init(defaults: UserDefaults = .standard,
         storageKey: String = "userAgentRestrictionExpiries",
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.now = now
    }

    func isRestricted(_ userAgentID: Int) -> Bool {
        guard let expiry = expiry(for: userAgentID) else { return false }
        return expiry > now()
    }

    func expiry(for userAgentID: Int) -> Date? {
        let entries = storedEntries()
        guard let timestamp = entries[String(userAgentID)] else { return nil }
        let expiry = Date(timeIntervalSince1970: timestamp)
        if expiry <= now() {
            var pruned = entries
            pruned.removeValue(forKey: String(userAgentID))
            saveEntries(pruned)
            return nil
        }
        return expiry
    }

    func restrictedIDs() -> Set<Int> {
        let currentDate = now()
        var entries = storedEntries()
        entries = entries.filter { $0.value > currentDate.timeIntervalSince1970 }
        saveEntries(entries)
        return Set(entries.keys.compactMap(Int.init))
    }

    @discardableResult
    func restrict(_ userAgentID: Int,
                  duration: TimeInterval = UserAgentRestrictionStore.defaultDuration) -> Date {
        var entries = storedEntries()
        let expiry = now().addingTimeInterval(duration)
        entries[String(userAgentID)] = expiry.timeIntervalSince1970
        saveEntries(entries)
        return expiry
    }

    func clear(_ userAgentID: Int) {
        var entries = storedEntries()
        entries.removeValue(forKey: String(userAgentID))
        saveEntries(entries)
    }

    /// Removes restrictions from a previous catalog when the profile set is
    /// replaced. Restriction IDs are catalog-specific and must not be applied
    /// to newly assigned profile values.
    func clearAll() {
        defaults.removeObject(forKey: storageKey)
    }

    private func storedEntries() -> [String: TimeInterval] {
        guard let raw = defaults.dictionary(forKey: storageKey) else { return [:] }
        return raw.reduce(into: [String: TimeInterval]()) { result, item in
            if let value = item.value as? TimeInterval {
                result[item.key] = value
            } else if let number = item.value as? NSNumber {
                result[item.key] = number.doubleValue
            }
        }
    }

    private func saveEntries(_ entries: [String: TimeInterval]) {
        if entries.isEmpty {
            defaults.removeObject(forKey: storageKey)
        } else {
            defaults.set(entries, forKey: storageKey)
        }
    }
}
