import SwiftUI

public struct EmptyDirectoryView: View {
    private static let iconFontSize: CGFloat = 48.0
    private static let titleFontSize: CGFloat = 15.0
    private static let bodyFontSize: CGFloat = 12.0
    private static let noticeMaxWidth: CGFloat = 320.0

    var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    /// Assumes slow `/Volumes/` mounts are readable to avoid blocking `access()` on the main thread.
    private var isCurrentFolderReadable: Bool {
        let path = appState.navigation.currentURL.path
        if path.hasPrefix("/Volumes/") {
            return true
        }
        return FileManager.default.isReadableFile(atPath: path)
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if !appState.selection.searchQuery.isEmpty {
                searchEmptyView
            } else if !isCurrentFolderReadable {
                // An unreadable folder (e.g. `~/.Trash`, which macOS restricts to Finder without
                // Full Disk Access) silently returns an empty item list from
                // `FileSystemService` — indistinguishable from a genuinely empty folder unless we
                // check readability here. Without this, the user sees "no items" with no
                // explanation for why a folder Finder shows full of files appears empty in Wiles.
                unreadableFolderView
            } else {
                emptyFolderView
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var searchEmptyView: some View {
        Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: Self.iconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.noResultsFound))
            .font(.system(size: Self.titleFontSize, weight: .semibold))
            .foregroundColor(.secondary)

        Button {
            appState.selection.searchQuery = ""
        } label: {
            Text(appState.tr(.clearSearch))
                .font(.system(size: Self.bodyFontSize, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.tr(.clearSearch))
    }

    @ViewBuilder private var unreadableFolderView: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: Self.iconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.permissionDeniedNotice))
            .font(.system(size: Self.titleFontSize, weight: .semibold))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

        Text(appState.tr(.fullDiskAccessNotice))
            .font(.system(size: Self.bodyFontSize))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: Self.noticeMaxWidth)

        Button {
            PermissionService.openFullDiskAccessSettings()
        } label: {
            Text(appState.tr(.grantFullDiskAccess))
                .font(.system(size: Self.bodyFontSize, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.tr(.grantFullDiskAccess))
    }

    @ViewBuilder private var emptyFolderView: some View {
        Image(systemName: "folder")
            .font(.system(size: Self.iconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.emptyFolder))
            .font(.system(size: Self.titleFontSize, weight: .semibold))
            .foregroundColor(.secondary)
    }
}
