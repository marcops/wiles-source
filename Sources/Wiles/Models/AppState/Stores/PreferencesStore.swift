import Foundation
import Observation

/// Container for the app's persisted preferences, split by concern into cohesive sub-stores
/// (`view`, `sidebar`, `search`, `appearance`) plus `favorites`. Read as
/// `appState.preferences.view.viewMode`, `appState.preferences.favorites.favoriteURLs`, etc.
///
/// `smartFolders` (and its CRUD, in `PreferencesStore+SmartFolders.swift`) stays here rather than
/// in a sub-store: it's a small, self-contained list whose persistence path (`SmartFolderService`)
/// is unlike the simple `UserDefaults` keys the other preferences use.
///
/// Adding/removing a `DefaultsKey` needs no migration; *changing* one's stored type/format does —
/// give it a new key name instead.
@Observable
@MainActor
public final class PreferencesStore {
    // `var`, not `let`, on every sub-store: SwiftUI's `$appState.preferences.view.iconSize`-style
    // two-way bindings only compose into a `ReferenceWritableKeyPath` when every intermediate
    // stored property in the chain is mutable — even though each sub-store is a class and nothing
    // here ever reassigns one (same reason `AppState.preferences` itself is `var`).
    public var view = ViewPreferences()
    public var sidebar = SidebarPreferences()
    public var search = SearchPreferences()
    public var appearance = AppearancePreferences()
    public var favorites = FavoritesStore()

    /// `private(set)`: mutations must go through the methods in `PreferencesStore+SmartFolders.swift`
    /// so persistence can't be bypassed. Populated from disk in `init`, not as a stored-property
    /// default (that would read JSON off disk before `init`'s body even runs).
    public internal(set) var smartFolders: [SmartFolder] = []

    public init() {
        smartFolders = SmartFolderService.loadSavedSmartFolders()
    }
}
