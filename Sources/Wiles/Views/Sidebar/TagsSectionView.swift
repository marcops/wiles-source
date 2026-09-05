import SwiftUI

struct TagsSectionView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @Binding var isExpanded: Bool

    var body: some View {
        SidebarSectionContainer(
            appState: appState, title: appState.tr(.tags), identifierKey: "TAGS", isExpanded: $isExpanded,
            hideAction: { appState.preferences.sidebar.showTags = false },
            content: {
                ForEach(SystemTagsService.favoriteTags, id: \.self) { systemTag in
                    tagRow(systemTag: systemTag)
                }
            })
    }

    /// See SWIFT_LANG_RULES.md "Custom Tappable Content MUST Have an Explicit `.contentShape`": a real `Button` on macOS does not reliably honor
    /// `.contentShape`
    /// for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
    private func tagRow(systemTag: SystemTag) -> some View {
        let tag = systemTag.name
        let (_, currentTag) = SearchFilterService.extractPrefixedToken(
            prefix: "tag:", from: appState.selection.searchQuery)
        let isSel = currentTag?.lowercased() == tag.lowercased()
        return HStack(spacing: 10) {
            Circle().fill(systemTag.color?.displayColor ?? .secondary).frame(width: 10, height: 10).padding(5)
            Text(systemTag.displayName(language: appState.preferences.appearance.appLanguage))
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
            Spacer()
        }
        .sidebarRowChrome(isSelected: isSel)
        .onTapGesture {
            appState.toggleTagFilter(tag, windowUIState: windowUIState)
        }
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier("Tag_\(tag)")
        .accessibilityLabel(tag)
        .accessibilityHint(appState.tr(.tags))
    }
}
