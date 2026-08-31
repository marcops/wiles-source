import Foundation

/// Shared persistence helpers for the split preference stores (`ViewPreferences`,
/// `SidebarPreferences`, `SearchPreferences`, `AppearancePreferences`). Every simple stored
/// preference persists through one of these on `didSet` instead of a hand-written
/// `UserDefaults.standard.set(x, forKey: DefaultsKey.x.rawValue)` per property, so the value and
/// its key can never be typed out of sync.
@MainActor
protocol PersistablePreferenceStore: AnyObject {
    /// True only while `init` is seeding a property from disk — every persisting `didSet` checks it
    /// and skips writing the just-read value straight back to `UserDefaults`.
    var isRestoringDefaults: Bool { get set }
}

extension PersistablePreferenceStore {
    func persist(_ value: Bool, _ key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    func persist(_ value: Int, _ key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    func persist(_ value: Double, _ key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    func persist(_ value: [String], _ key: DefaultsKey) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    func persist(_ value: some RawRepresentable<String>, _ key: DefaultsKey) {
        UserDefaults.standard.set(value.rawValue, forKey: key.rawValue)
    }

    /// Restores a `RawRepresentable<String>`-backed preference (enum settings) if a saved value
    /// exists and is still a recognized case.
    func loadEnum<T: RawRepresentable>(
        _ key: DefaultsKey, into keyPath: ReferenceWritableKeyPath<Self, T>, from defaults: UserDefaults) where T.RawValue == String {
        if let raw = defaults.string(forKey: key.rawValue), let value = T(rawValue: raw) {
            isRestoringDefaults = true
            self[keyPath: keyPath] = value
            isRestoringDefaults = false
        }
    }

    /// Restores a `Bool` preference, distinguishing "never saved" (leave the property's default)
    /// from an explicitly saved `false` (`UserDefaults.bool(forKey:)` returns false for both).
    func loadBool(_ key: DefaultsKey, into keyPath: ReferenceWritableKeyPath<Self, Bool>, from defaults: UserDefaults) {
        if defaults.object(forKey: key.rawValue) != nil {
            isRestoringDefaults = true
            self[keyPath: keyPath] = defaults.bool(forKey: key.rawValue)
            isRestoringDefaults = false
        }
    }

    /// Restores an `Int` preference, distinguishing "never saved" (leave the property's default)
    /// from an explicitly saved `0` (`UserDefaults.integer(forKey:)` returns 0 for both — a raw
    /// `if value > 0` restore silently drops a user's choice of 0, e.g. a translucency level of 0%).
    func loadInt(_ key: DefaultsKey, into keyPath: ReferenceWritableKeyPath<Self, Int>, from defaults: UserDefaults) {
        if defaults.object(forKey: key.rawValue) != nil {
            isRestoringDefaults = true
            self[keyPath: keyPath] = defaults.integer(forKey: key.rawValue)
            isRestoringDefaults = false
        }
    }

    /// Runs `body` with `isRestoringDefaults` set, so any persisting `didSet` it fires is a no-op.
    func withRestoringDefaults(_ body: () -> Void) {
        isRestoringDefaults = true
        defer { isRestoringDefaults = false }
        body()
    }

    /// Keys to drop to bring a capped collection back to `cap` without reverting the user's whole
    /// assignment. Evicts the pre-existing baseline first, then the just-added batch only if that
    /// alone isn't enough. Shared by `expandedTreePaths` and `perFolderViewModes`.
    static func keysToEvict<Key: Hashable>(current: Set<Key>, previous: Set<Key>, cap: Int) -> [Key] {
        let overflow = current.count - cap
        guard overflow > 0 else { return [] }
        let justAdded = current.subtracting(previous)
        let order = Array(previous.subtracting(justAdded)) + Array(justAdded)
        return Array(order.prefix(overflow))
    }
}
