import Foundation

/// Backs the View menu's Appearance ▸ Default / Director View actions. Split out of
/// `PreferencesStore.swift` for the same reason `PreferencesStore+SmartFolders.swift` is.
public extension PreferencesStore {
    /// Wipes every persisted Wiles preference and resets every sub-store's live properties to their
    /// factory defaults, as if the app had just been installed.
    func resetToDefaults() {
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "com.marco.wiles")
        view.resetToDefaults()
        sidebar.resetToDefaults()
        search.resetToDefaults()
        appearance.resetToDefaults()
        favorites.resetToDefaults()
        persistSmartFolders([])
    }

    /// Same full reset as `resetToDefaults()`, then a decluttered sidebar for screen recordings /
    /// presentations: every section disabled except Favorites, seeded with just Desktop, Home,
    /// Documents, and Downloads.
    func applyDirectorView() {
        resetToDefaults()
        sidebar.showFavorites = true
        sidebar.showRecents = false
        sidebar.showPlaces = false
        sidebar.showNetworkAndCloud = false
        sidebar.showDirectoryTree = false
        sidebar.showTags = false
        sidebar.showSidebarSectionTitles = false
        let home = FileManager.default.homeDirectoryForCurrentUser
        favorites.favoriteURLs = [
            home.appendingPathComponent("Desktop"),
            home,
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Downloads")
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
    }
}
