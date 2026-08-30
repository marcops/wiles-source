import AppKit
import SwiftUI

struct SidebarRowView: View {
    private static let staleFavoriteOpacity: Double = 0.4

    let item: SidebarItem
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    let isFavoritesSection: Bool
    let isRightClicked: Bool
    let isAnotherRowRightClicked: Bool
    var isCompact: Bool = false
    let onRightClick: () -> Void
    let onLeftClick: () -> Void

    @State private var isDragTargeted = false
    @State private var isEjectable = false
    @State private var isMissingFavorite = false

    /// `navigation.currentURL` doesn't change for a smart folder run, so without the
    /// `smartFolder.activeFolderID` check this row would incorrectly keep showing as the
    /// active/current folder while a smart folder's results (from a different location) are shown.
    private var isCurrentFolder: Bool {
        appState.smartFolder.activeFolderID == nil && appState.navigation.currentURL.standardizedFileURL == item.url.standardizedFileURL
    }

    private var isSel: Bool {
        isRightClicked || (isCurrentFolder && !isAnotherRowRightClicked)
    }

    private var isTrash: Bool {
        item.url.standardizedFileURL == URL.userTrash.standardizedFileURL
    }

    var body: some View {
        // See SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`": a real `Button` on macOS does not reliably honor
        // `.contentShape`
        // for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
        rowContent
            .sidebarRowChrome(isSelected: isSel, isDragTargeted: isDragTargeted)
            .onTapGesture {
                onLeftClick()
                if item.url == SidebarItem.airDropURL {
                    NSWorkspace.shared.open(item.url)
                } else {
                    appState.navigateTo(item.url)
                }
                windowUIState.selectedFavoriteURL = isFavoritesSection ? item.url : nil
            }
            .padding(.horizontal, 8)
            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
            .accessibilityIdentifier(item.name)
            .accessibilityLabel(item.name)
            .accessibilityHint(appState.tr(.folder))
            .help(item.name)
            .overlay(
                RightClickDetector { onRightClick() })
            .springLoadedFolder(folderURL: item.url, isDirectory: true, appState: appState) { targeted in
                isDragTargeted = targeted
            }
            .contextMenu {
                rowContextMenu
            }
            .opacity(isMissingFavorite ? Self.staleFavoriteOpacity : 1)
            .task(id: item.url) { await refreshEjectable() }
            .task(id: favoriteStatusKey) { await refreshMissingFavoriteStatus() }
    }

    /// Re-runs the missing-favorite check when the user navigates (picks up a volume that
    /// unmounted while the sidebar stayed open) and, additionally, on the visible folder's
    /// contents changing — but that FSEvents-driven contents signal is folded in ONLY for the one
    /// favorite whose parent is the folder currently on screen. Otherwise every directory refresh
    /// re-ran `fileExists` for every favorite row. No timer/poll.
    private var favoriteStatusKey: String {
        Self.favoriteStatusKey(
            favoriteURL: item.url,
            currentURL: appState.navigation.currentURL,
            visibleItemCount: appState.fileSystem.items.count,
            isFavoritesSection: isFavoritesSection)
    }

    /// Pure key builder (unit-testable without `AppState`): the `visibleItemCount` term — the
    /// high-frequency FSEvents signal — is included only when `favoriteURL`'s parent is `currentURL`.
    static func favoriteStatusKey(favoriteURL: URL, currentURL: URL, visibleItemCount: Int, isFavoritesSection: Bool) -> String {
        guard isFavoritesSection else { return favoriteURL.path }
        let base = "\(favoriteURL.path)|\(currentURL.path)"
        guard favoriteURL.deletingLastPathComponent().path == currentURL.path else { return base }
        return "\(base)|\(visibleItemCount)"
    }

    /// A favorite is dimmed only when it's in the Favorites section and its backing path is gone
    /// from disk. Pure so the decision is unit-testable without the async `FileManager` hop.
    static func isFavoriteMissing(isFavoritesSection: Bool, pathExists: Bool) -> Bool {
        isFavoritesSection && !pathExists
    }

    /// A favorite whose folder was deleted or whose volume was unmounted still rendered identically
    /// to a live one before this check — dims it instead. Runs off `@MainActor` since a `/Volumes/`
    /// path's existence check can block for seconds against a stalled network share.
    private func refreshMissingFavoriteStatus() async {
        guard isFavoritesSection else {
            isMissingFavorite = false
            return
        }
        let url = item.url
        let exists = await Task.detached(priority: .utility) {
            FileManager.default.fileExists(atPath: url.path)
        }.value
        guard !Task.isCancelled else { return }
        isMissingFavorite = Self.isFavoriteMissing(isFavoritesSection: isFavoritesSection, pathExists: exists)
    }

    /// Real `URLResourceValues.volumeIsEjectable` check, not the old `/Volumes/` path-prefix
    /// heuristic — that wrongly offered Eject on the boot volume when mounted under `/Volumes/`
    /// (a modern macOS Data volume) and on non-ejectable network mounts. Runs off `@MainActor`
    /// since a stalled network share can make `resourceValues` block for seconds.
    private func refreshEjectable() async {
        guard SlowVolumePathValidator.isLikelySlowVolume(item.url.standardizedFileURL.path) else {
            isEjectable = false
            return
        }
        let url = item.url
        let ejectable = await Task.detached(priority: .utility) { () -> Bool in
            guard let values = try? url.resourceValues(forKeys: [.volumeIsEjectableKey, .volumeIsRemovableKey]) else { return false }
            return (values.volumeIsEjectable ?? false) || (values.volumeIsRemovable ?? false)
        }.value
        guard !Task.isCancelled else { return }
        isEjectable = ejectable
    }

    @ViewBuilder private var rowContent: some View {
        if isCompact {
            Image(systemName: item.iconName)
                .font(.system(size: 15)).foregroundColor(.accentColor).frame(width: 20)
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 10) {
                Image(systemName: item.iconName)
                    .font(.system(size: 15)).foregroundColor(.accentColor).frame(width: 20)
                Text(item.name)
                    .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isTrash {
                    trashSizeIndicator
                }
                if isEjectable {
                    ejectButton.padding(.leading, 4)
                }
            }
        }
    }

    @ViewBuilder private var trashSizeIndicator: some View {
        if appState.fileSystem.trash.isUpdating {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.mini)
                .scaleEffect(0.6)
                .frame(width: 16, height: 16)
        } else if !appState.fileSystem.trash.sizeString.isEmpty, appState.fileSystem.trash.sizeBytes > 0 {
            Text(appState.fileSystem.trash.sizeString)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(10)
        }
    }

    private var ejectButton: some View {
        TappableRow(
            accessibilityLabel: appState.tr(.ejectVolume),
            accessibilityHint: appState.tr(.ejectVolume),
            action: { ejectVolume() },
            content: {
                Image(systemName: "eject.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 22)
            })
            .help(appState.tr(.ejectVolume))
    }

    private func ejectVolume() {
        let target = item.url
        Task {
            // `unmountAndEjectDevice` can block for seconds on a slow/network volume — keep it
            // off `@MainActor` and hop back only for the refresh/error.
            let result = await Task.detached(priority: .userInitiated) { () -> (any Error)? in
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: target)
                    return nil
                } catch {
                    return error
                }
            }.value
            if let result {
                appState.showError(result, context: "Ejecting volume")
            } else {
                appState.refreshCurrentDirectory()
            }
        }
    }

    @ViewBuilder private var rowContextMenu: some View {
        SidebarItemContextMenu(url: item.url, appState: appState)
        Divider()
        FavoriteToggleButton(url: item.url, appState: appState, forceRemove: isFavoritesSection)
        if isTrash {
            Divider()
            Button(appState.tr(.emptyTrashEllipsis)) {
                windowUIState.showEmptyTrashAlert = true
            }
        }
    }
}
