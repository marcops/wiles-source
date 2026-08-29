import Foundation

/// Shared persistence helpers for `PreferencesStore`. Split from `PreferencesStore.swift` to keep
/// that file under the 500-line lint cap, and because these are one cohesive concern.
extension PreferencesStore {
    /// Every simple stored preference persists through one of these on `didSet`, instead of a
    /// hand-written `UserDefaults.standard.set(x, forKey: DefaultsKey.x.rawValue)` per property, so
    /// the value and its key can never be typed out of sync.
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

    /// Keys to drop to bring a capped collection back to `cap` without reverting the user's whole
    /// assignment (which used to leave disclosure triangles / view-mode changes silently inert once
    /// the cap was hit). Evicts the pre-existing baseline first, then the just-added batch only if
    /// that alone isn't enough. Shared by `expandedTreePaths` and `perFolderViewModes`.
    static func keysToEvict<Key: Hashable>(current: Set<Key>, previous: Set<Key>, cap: Int) -> [Key] {
        let overflow = current.count - cap
        guard overflow > 0 else { return [] }
        let justAdded = current.subtracting(previous)
        let order = Array(previous.subtracting(justAdded)) + Array(justAdded)
        return Array(order.prefix(overflow))
    }
}
