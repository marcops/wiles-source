import Foundation
import Observation

/// Search-bar behavior preferences: match scope, case sensitivity, and whole-home recursion.
/// Split out of `PreferencesStore` (SRP).
@Observable
@MainActor
public final class SearchPreferences: PersistablePreferenceStore {
    public var searchScope: SearchScope = .name {
        didSet { persist(searchScope, .searchScope) }
    }

    public var searchCaseSensitive: Bool = false {
        didSet { persist(searchCaseSensitive, .searchCaseSensitive) }
    }

    /// When on, a search query recurses through the whole user home directory (`URL.userHome`)
    /// instead of just the current folder's direct children.
    public var searchEverywhere: Bool = false {
        didSet { persist(searchEverywhere, .searchEverywhere) }
    }

    public init() {
        let defaults = UserDefaults.standard
        loadEnum(.searchScope, into: \.searchScope, from: defaults)
        loadBool(.searchCaseSensitive, into: \.searchCaseSensitive, from: defaults)
        loadBool(.searchEverywhere, into: \.searchEverywhere, from: defaults)
    }
}
