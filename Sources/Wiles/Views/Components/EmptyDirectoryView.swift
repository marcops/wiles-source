import SwiftUI

public struct EmptyDirectoryView: View {
    var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if !appState.searchQuery.isEmpty {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(appState.tr(.noResultsFound))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Button {
                    appState.searchQuery = ""
                } label: {
                    Text(appState.tr(.clearSearch))
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(appState.tr(.clearSearch))
            } else if !FileManager.default.isReadableFile(atPath: appState.navigation.currentURL.path) {
                // An unreadable folder (e.g. `~/.Trash`, which macOS restricts to Finder without
                // Full Disk Access) silently returns an empty item list from
                // `FileSystemService` — indistinguishable from a genuinely empty folder unless we
                // check readability here. Without this, the user sees "no items" with no
                // explanation for why a folder Finder shows full of files appears empty in Wiles.
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(appState.tr(.permissionDeniedNotice))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(appState.tr(.fullDiskAccessNotice))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Button {
                    PermissionService.openFullDiskAccessSettings()
                } label: {
                    Text(appState.tr(.grantFullDiskAccess))
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel(appState.tr(.grantFullDiskAccess))
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.6))

                Text(appState.tr(.emptyFolder))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
