import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FileGridCardItemView: View {
    let item: FileItem
    var appState: AppState
    let iconSize: CGFloat
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let onRightClick: () -> Void

    @Environment(WindowUIState.self)
    private var windowUIState
    @State private var isDropTargeted = false

    var body: some View {
        let isSel = appState.selection.selectedURLs.contains(item.url)
        let isCut = appState.transient.clipboard?.isCut(url: item.url) ?? false

        return mainContent(isSel: isSel, isCut: isCut)
            .fileItemInteractions(
                item: item,
                appState: appState,
                onRightClick: onRightClick,
                onTargetedChanged: { targeted in
                    withAnimation(MotionTokens.quickEase) { isDropTargeted = targeted }
                })
    }

    private func mainContent(isSel: Bool, isCut: Bool) -> some View {
        let borderStroke = isDropTargeted ? Color.accentColor : (isSel ? Color.accentColor : Color.clear)
        let strokeWidth: CGFloat = isDropTargeted ? 3 : 2
        let isRenaming = windowUIState.renameItem?.url == item.url

        return cardVStack(isSel: isSel)
            .frame(width: cardWidth, height: cardHeight, alignment: .top)
            .padding(LayoutTokens.gridCardPadding)
            .hoverHighlight(isSelected: isSel, selectedBackground: Color.accentColor.opacity(0.18), cornerRadius: 10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderStroke, lineWidth: strokeWidth))
            .opacity(isCut ? 0.5 : 1.0)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: URLFrameKey.self, value: [item.url: geo.frame(in: .named("gridContainer"))])
                })
            // Renaming must never resize this cell — that would reflow every other card in the
            // grid. The card's own footprint stays fixed at cardHeight; the growing rename field
            // is a same-size-as-normal-label placeholder with an overlay on top, so it renders at
            // its natural (possibly much taller) size without contributing to this view's own
            // layout size, floating above whatever is below it instead of pushing it away.
            .zIndex(isRenaming ? 2 : (isSel ? 1 : 0))
            .contentShape(Rectangle())
            .fileMetadataTooltip(item, language: appState.preferences.appLanguage)
            .accessibilityLabel(item.name)
            .accessibilityHint(item.isDirectory ? appState.tr(.folder) : appState.tr(.open))
            .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
            .accessibilityValue(item.formattedSize)
    }

    private func cardVStack(isSel: Bool) -> some View {
        VStack(spacing: LayoutTokens.gridCardVStackSpacing) {
            FileItemIconView(item: item, size: iconSize, isOpenTargeted: isDropTargeted)
                .overlay(ICloudStatusBadgeView(item: item, appState: appState).padding(2), alignment: .topTrailing)
            cardLabel(isSel: isSel)
            if appState.preferences.showTags, !item.tags.isEmpty {
                TagsIndicatorView(tags: item.tags)
            }
        }
    }

    @ViewBuilder
    private func cardLabel(isSel: Bool) -> some View {
        let fontSize = max(
            LayoutTokens.gridCardLabelMinFontSize,
            min(LayoutTokens.gridCardLabelMaxFontSize, Double(iconSize) * LayoutTokens.gridCardLabelFontScaleMultiplier))
        let fontWeight: Font.Weight = isSel ? .semibold : .regular
        let nsWeight: NSFont.Weight = isSel ? .semibold : .regular
        let nsFont = NSFont.systemFont(ofSize: fontSize, weight: nsWeight)
        // Same height a normal 2-line label occupies, so the icon above never shifts when entering
        // rename. A LazyVGrid cell clips its own content to its allocated row height, so the actual
        // growing field can't live here — this is just an invisible placeholder reserving the
        // label's usual space; `FileGridView` renders the real field as a grid-level overlay
        // (outside any cell) positioned over this same spot via `URLFrameKey`.
        let normalLabelHeight = (nsFont.ascender - nsFont.descender + nsFont.leading) * 2 + 4

        if windowUIState.renameItem?.url == item.url {
            Color.clear
                .frame(width: cardWidth - LayoutTokens.gridCardLabelHorizontalInset, height: normalLabelHeight)
        } else {
            SelectionAwareNameText(
                name: item.name,
                isSelected: isSel,
                font: .system(size: fontSize, weight: fontWeight),
                nsFont: .systemFont(ofSize: fontSize, weight: nsWeight),
                color: isSel ? .white : .primary,
                collapsedLineLimit: 2,
                availableWidth: cardWidth - LayoutTokens.gridCardLabelHorizontalInset,
                alignment: .center,
                middleTruncate: appState.preferences.middleTruncateNames)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isSel ? Color.accentColor : Color.clear)
                .cornerRadius(4)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: LabelWidthKey.self, value: [item.url: geo.size.width])
                    })
        }
    }
}
