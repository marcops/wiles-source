import Foundation

/// Per-section "should this sidebar section render?" gates. `SidebarView` renders each section
/// behind the matching gate here, and `hasVisibleSidebarContent` ORs them — one source of truth so
/// the "show the sidebar pane at all" check and the per-section checks can't drift apart. Lives on
/// `AppState` (not `PreferencesStore`) because two of the gates depend on non-preferences data
/// (`favorites.favoriteURLs`, `smartFolders`).
public extension AppState {
    var showsRecentsSection: Bool {
        preferences.sidebar.showRecents
    }

    var showsFavoritesSection: Bool {
        preferences.sidebar.showFavorites && !preferences.favorites.favoriteURLs.isEmpty
    }

    var showsNetworkSection: Bool {
        preferences.sidebar.showNetworkAndCloud
    }

    var showsPlacesSection: Bool {
        preferences.sidebar.showPlaces
    }

    var showsDirectoryTreeSection: Bool {
        preferences.sidebar.showDirectoryTree
    }

    var showsTagsSection: Bool {
        preferences.sidebar.showTags
    }

    var showsSmartFoldersSection: Bool {
        !preferences.smartFolders.isEmpty
    }

    /// False hides the whole sidebar pane.
    var hasVisibleSidebarContent: Bool {
        showsRecentsSection || showsFavoritesSection || showsNetworkSection || showsPlacesSection
            || showsDirectoryTreeSection || showsTagsSection || showsSmartFoldersSection
    }
}
