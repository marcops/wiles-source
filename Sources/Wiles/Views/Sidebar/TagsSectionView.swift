import SwiftUI

struct TagsSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool

    var body: some View {
        SidebarSectionContainer(
            appState: appState, title: appState.tr(.tags), identifierKey: "TAGS", isExpanded: $isExpanded,
            hideAction: { appState.preferences.showTags = false },
            content: {
                ForEach(TagColor.allCases, id: \.self) { tagColor in
                    tagRow(tagColor: tagColor)
                }
            })
    }

    /// Splits the current search query into everything except a leading `tag:` token and that
    /// token's value — mirrors the `extractHiddenFlag` idiom so tapping a tag only adds/removes
    /// its own token instead of discarding whatever else the user typed.
    private func extractTagToken(from query: String) -> (remaining: String, tag: String?) {
        let tokens = query.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard let tagToken = tokens.first(where: { $0.lowercased().hasPrefix("tag:") }) else {
            return (query, nil)
        }
        let remaining = tokens.filter { $0.lowercased() != tagToken.lowercased() }.joined(separator: " ")
        return (remaining, String(tagToken.dropFirst(4)))
    }

    /// See AGENTS.md rule 33: a real `Button` on macOS does not reliably honor `.contentShape`
    /// for composite (icon + text) label content, so this uses a plain view + `.onTapGesture`.
    private func tagRow(tagColor: TagColor) -> some View {
        let tag = tagColor.rawValue
        let (remainingQuery, currentTag) = extractTagToken(from: appState.selection.searchQuery)
        let isSel = currentTag?.lowercased() == tag.lowercased()
        return HStack(spacing: 10) {
            Circle().fill(tagColor.displayColor).frame(width: 10, height: 10).padding(5)
            Text(appState.tr(tagColor.localizationKey))
                .font(.system(size: 13, weight: isSel ? .semibold : .regular))
                .foregroundColor(.primary)
            Spacer()
        }
        .sidebarRowChrome(isSelected: isSel)
        .onTapGesture {
            if isSel {
                appState.selection.searchQuery = remainingQuery
            } else {
                appState.selection.searchQuery = remainingQuery.isEmpty ? "tag:\(tag)" : "\(remainingQuery) tag:\(tag)"
            }
        }
        .padding(.horizontal, 8)
        .accessibilityAddTraits(isSel ? [.isButton, .isSelected] : [.isButton])
        .accessibilityIdentifier("Tag_\(tag)")
        .accessibilityLabel(appState.tr(tagColor.localizationKey))
        .accessibilityHint(appState.tr(.tags))
    }
}
