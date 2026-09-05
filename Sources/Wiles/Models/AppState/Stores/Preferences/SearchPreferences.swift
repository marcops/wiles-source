import Foundation
import Observation

/// Search-bar behavior preferences: match scope, case sensitivity, and whole-home recursion.
/// Split out of `PreferencesStore` (SRP).
@Observable
@MainActor
public final class SearchPreferences: PersistablePreferenceStore {
    @ObservationIgnored var isRestoringDefaults = false

    public var searchScope: SearchScope = .name {
        didSet { guard !isRestoringDefaults else { return }
            persist(searchScope, .searchScope)
        }
    }

    public var searchCaseSensitive: Bool = false {
        didSet { guard !isRestoringDefaults else { return }
            persist(searchCaseSensitive, .searchCaseSensitive)
        }
    }

    /// When on, a search query recurses through the whole user home directory (`URL.userHome`)
    /// instead of just the current folder's direct children.
    public var searchEverywhere: Bool = false {
        didSet { guard !isRestoringDefaults else { return }
            persist(searchEverywhere, .searchEverywhere)
        }
    }

    public init() {
        let defaults = UserDefaults.standard
        loadEnum(.searchScope, into: \.searchScope, from: defaults)
        loadBool(.searchCaseSensitive, into: \.searchCaseSensitive, from: defaults)
        loadBool(.searchEverywhere, into: \.searchEverywhere, from: defaults)
    }

    /// Reassigns every property to its literal factory default — see `ViewPreferences.resetToDefaults()`.
    func resetToDefaults() {
        searchScope = .name
        searchCaseSensitive = false
        searchEverywhere = false
    }
}
