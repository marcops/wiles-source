import SwiftUI

/// One row in `ConnectToServerSheetView`'s recent-servers list — reveals a remove control on
/// hover so a mistyped host doesn't have to stay in the list forever.
struct RecentServerRow: View {
    let server: String
    let onSelect: () -> Void
    let onRemove: () -> Void
    var appState: AppState

    @State private var isHovered = false

    var body: some View {
        TappableRow(accessibilityLabel: server, action: onSelect, content: {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.secondary)
                Text(server)
                    .font(.system(size: 12))
                Spacer()
                if isHovered {
                    removeButton
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(4)
        })
        .onHover { isHovered = $0 }
    }

    private var removeButton: some View {
        Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.tr(.removeRecentServer))
    }
}
