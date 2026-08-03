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
