import SwiftUI

/// Shared add/remove-favorite button, used by `SidebarRowView` and `SharedFileItemContextMenu`.
struct FavoriteToggleButton: View {
    let url: URL
    var appState: AppState
    /// Set by `SidebarRowView` when `url` is already known to be a favorite.
    var forceRemove: Bool = false

    var body: some View {
        if forceRemove || appState.isFavorite(url) {
            Button(appState.tr(.removeFromFavorites)) { appState.removeFavorite(url) }
        } else {
            Button(appState.tr(.addToFavorites)) { appState.addFavorite(url) }
        }
    }
}
