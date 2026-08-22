import SwiftUI

public struct EmptyDirectoryView: View {
    var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if !appState.selection.searchQuery.isEmpty {
                searchEmptyView
            } else if !FileManager.default.isReadableFile(atPath: appState.navigation.currentURL.path) {
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
            .font(.system(size: LayoutTokens.emptyStateIconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.noResultsFound))
            .font(.system(size: LayoutTokens.emptyStateTitleFontSize, weight: .semibold))
            .foregroundColor(.secondary)

        Button {
            appState.selection.searchQuery = ""
        } label: {
            Text(appState.tr(.clearSearch))
                .font(.system(size: LayoutTokens.emptyStateBodyFontSize, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.tr(.clearSearch))
    }

    @ViewBuilder private var unreadableFolderView: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: LayoutTokens.emptyStateIconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.permissionDeniedNotice))
            .font(.system(size: LayoutTokens.emptyStateTitleFontSize, weight: .semibold))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

        Text(appState.tr(.fullDiskAccessNotice))
            .font(.system(size: LayoutTokens.emptyStateBodyFontSize))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: LayoutTokens.emptyStateNoticeMaxWidth)

        Button {
            PermissionService.openFullDiskAccessSettings()
        } label: {
            Text(appState.tr(.grantFullDiskAccess))
                .font(.system(size: LayoutTokens.emptyStateBodyFontSize, weight: .medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel(appState.tr(.grantFullDiskAccess))
    }

    @ViewBuilder private var emptyFolderView: some View {
        Image(systemName: "folder")
            .font(.system(size: LayoutTokens.emptyStateIconFontSize))
            .foregroundColor(.secondary.opacity(0.6))

        Text(appState.tr(.emptyFolder))
            .font(.system(size: LayoutTokens.emptyStateTitleFontSize, weight: .semibold))
            .foregroundColor(.secondary)
    }
}
