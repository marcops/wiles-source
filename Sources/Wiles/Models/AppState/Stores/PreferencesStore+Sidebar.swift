import Foundation

/// Per-section "should this sidebar section render?" gates. `SidebarView` renders each section
/// behind the matching gate here, and `hasVisibleSidebarContent` ORs them — one source of truth
/// so the "show the sidebar pane at all" check and the per-section checks can't drift apart.
public extension PreferencesStore {
    var showsRecentsSection: Bool {
        showRecents
    }

    var showsFavoritesSection: Bool {
        showFavorites && !favoriteURLs.isEmpty
    }

    var showsNetworkSection: Bool {
        showNetworkAndCloud
    }

    var showsPlacesSection: Bool {
        showPlaces
    }

    var showsDirectoryTreeSection: Bool {
        showDirectoryTree
    }

    var showsTagsSection: Bool {
        showTags
    }

    var showsSmartFoldersSection: Bool {
        !smartFolders.isEmpty
    }

    /// False hides the whole sidebar pane.
    var hasVisibleSidebarContent: Bool {
        showsRecentsSection || showsFavoritesSection || showsNetworkSection || showsPlacesSection
            || showsDirectoryTreeSection || showsTagsSection || showsSmartFoldersSection
    }
}
