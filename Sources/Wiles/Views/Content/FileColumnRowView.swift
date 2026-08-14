import SwiftUI
import AppKit

struct FileColumnRowView: View {
    let item: FileItem
    let columnIndex: Int
    let isSelected: Bool
    var appState: AppState
    let onSelect: () -> Void

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 8) {
            FileItemIconView(item: item, size: 16, isOpenTargeted: isDropTargeted)
            ICloudStatusBadgeView(item: item)

            if windowUIState.renameItem?.url == item.url {
                InlineRenameField(item: item, appState: appState, windowUIState: windowUIState, font: .system(size: 12, weight: isSelected ? .semibold : .regular))
            } else {
                SelectionAwareNameText(
                    name: item.name,
                    isSelected: isSelected,
                    font: .system(size: 12, weight: isSelected ? .semibold : .regular),
                    nsFont: .systemFont(ofSize: 12, weight: isSelected ? .semibold : .regular),
                    color: isSelected ? .white : .primary,
                    collapsedLineLimit: 1,
                    middleTruncate: appState.preferences.middleTruncateNames
                )
                .fileMetadataTooltip(item)
            }

            Spacer()

            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .hoverHighlight(isSelected: isSelected, cornerRadius: 4)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .accessibilityLabel(item.name)
        .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityValue(item.formattedSize)
        .fileItemInteractions(
            item: item,
            appState: appState,
            onSelect: onSelect,
            onTargetedChanged: { targeted in isDropTargeted = targeted }
        )
    }
}
