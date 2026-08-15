import SwiftUI

struct FolderPickerNodeView: View {
    let node: FolderNode
    let depth: Int
    @Binding var selectedURL: URL?
    @Binding var expandedPaths: Set<URL>

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(node.url) },
            set: { newValue in
                if newValue {
                    expandedPaths.insert(node.url)
                } else {
                    expandedPaths.remove(node.url)
                }
            })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: isExpandedBinding) {
                    ForEach(children) { child in
                        Self(node: child, depth: depth + 1, selectedURL: $selectedURL, expandedPaths: $expandedPaths)
                    }
                } label: { rowLabel }
            } else {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        let isSelected = selectedURL?.standardizedFileURL == node.url.standardizedFileURL
        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(node.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedURL = node.url
        }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .accessibilityLabel(node.name)
    }
}
