import SwiftUI

struct TagsSectionView: View {
    var appState: AppState
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if appState.preferences.showSidebarSectionTitles {
                SidebarSectionHeaderView(title: appState.tr(.tags), identifierKey: "TAGS", appState: appState, isExpanded: $isExpanded)
            }
            if !appState.preferences.showSidebarSectionTitles || isExpanded {
                ForEach(TagColor.allCases, id: \.self) { tagColor in
                    tagRow(tag: tagColor.rawValue, colorKey: tagColor.localizationKey)
                }
            }
        }
    }

    private func tagRow(tag: String, colorKey: L10n.Key) -> some View {
        let query = "tag:\(tag.lowercased())"
        let isSel = appState.selection.searchQuery.lowercased() == query
        return Button {
            if isSel {
                appState.selection.searchQuery = ""
            } else {
                appState.selection.searchQuery = query
            }
        } label: {
            HStack(spacing: 10) {
                Circle().fill(colorForTag(tag)).frame(width: 10, height: 10).frame(width: 20, height: 20)
                Text(appState.tr(colorKey))
                    .font(.system(size: 13, weight: isSel ? .semibold : .regular, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .hoverHighlight(isSelected: isSel, selectedBackground: Color.accentColor.opacity(0.15), cornerRadius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(appState.tr(colorKey))
        .accessibilityHint(appState.tr(.tags))
    }
}
