import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileGridCardItemView: View {
    let item: FileItem
    var appState: AppState
    let iconSize: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onRightClick: () -> Void

    @State private var isDropTargeted = false

    var body: some View {
        let isSel = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard?.isCut(url: item.url) ?? false

        return mainContent(isSel: isSel, isCut: isCut)
            .fileItemInteractions(
                item: item,
                appState: appState,
                onRightClick: onRightClick,
                onTargetedChanged: { targeted in
                    withAnimation(MotionTokens.quickEase) { isDropTargeted = targeted }
                }
            )
    }

    private func mainContent(isSel: Bool, isCut: Bool) -> some View {
        let borderStroke = isDropTargeted ? Color.accentColor : (isSel ? Color.accentColor : Color.clear)
        let strokeWidth: CGFloat = isDropTargeted ? 3 : 2

        return cardVStack(isSel: isSel)
            .frame(width: cardWidth, height: cardHeight, alignment: .top)
            .padding(6)
            .hoverHighlight(isSelected: isSel, selectedBackground: Color.accentColor.opacity(0.18), cornerRadius: 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderStroke, lineWidth: strokeWidth))
            .opacity(isCut ? 0.5 : 1.0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: CellFrameKey.self, value: [item.url: geo.frame(in: .named("gridContainer"))])
                }
            )
            .zIndex(isSel ? 1 : 0)
            .contentShape(Rectangle())
            .fileMetadataTooltip(item)
            .accessibilityLabel(item.name)
            .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
            .accessibilityValue(item.formattedSize)
    }

    private func cardVStack(isSel: Bool) -> some View {
        VStack(spacing: 6) {
            FileItemIconView(item: item, size: iconSize, isOpenTargeted: isDropTargeted)
                .overlay(ICloudStatusBadgeView(item: item).padding(2), alignment: .topTrailing)
            cardLabel(isSel: isSel)
            if appState.preferences.showTags && !item.tags.isEmpty {
                tagsView
            }
        }
    }

    private func cardLabel(isSel: Bool) -> some View {
        let fontSize = max(8.0, min(12.0, Double(iconSize) * 0.22))
        let fontWeight: Font.Weight = isSel ? .semibold : .regular
        let nsWeight: NSFont.Weight = isSel ? .semibold : .regular
        return SelectionAwareNameText(
            name: item.name,
            isSelected: isSel,
            font: .system(size: fontSize, weight: fontWeight),
            nsFont: .systemFont(ofSize: fontSize, weight: nsWeight),
            color: isSel ? .white : .primary,
            collapsedLineLimit: 2,
            availableWidth: cardWidth - 12, // cardWidth minus the 6pt horizontal padding below × 2
            alignment: .center,
            middleTruncate: appState.preferences.middleTruncateNames
        )
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(isSel ? Color.accentColor : Color.clear)
            .cornerRadius(4)
    }

    private var tagsView: some View {
        HStack(spacing: -2) {
            ForEach(item.tags, id: \.self) { tag in
                Circle()
                    .fill(colorForTag(tag))
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color(NSColor.windowBackgroundColor), lineWidth: 1))
            }
        }
    }
}
