import SwiftUI

struct FolderPickerNodeView: View {
    let node: FolderNode
    let depth: Int
    @Binding var selectedURL: URL?
    @Binding var expandedPaths: Set<URL>
    @Binding var childrenCache: [URL: [FolderNode]]

    private var children: [FolderNode]? {
        node.children ?? childrenCache[node.url]
    }

    private var isExpanded: Bool {
        expandedPaths.contains(node.url)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowLabel
            if node.hasSubfolders, isExpanded, let children {
                ForEach(children) { child in
                    Self(node: child, depth: depth + 1, selectedURL: $selectedURL, expandedPaths: $expandedPaths, childrenCache: $childrenCache)
                }
            }
        }
        .padding(.leading, depth == 0 ? 0 : 12)
        .id(node.url)
    }

    private var rowLabel: some View {
        let isSelected = selectedURL?.standardizedFileURL == node.url.standardizedFileURL
        return HStack(spacing: 4) {
            if node.hasSubfolders {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 10)
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }
                    .accessibilityAddTraits(.isButton)
            } else {
                Color.clear.frame(width: 10)
            }
            Image(systemName: "folder.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(node.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.middle)
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

    private func toggleExpanded() {
        if isExpanded {
            expandedPaths.remove(node.url)
        } else {
            expandedPaths.insert(node.url)
            if children == nil {
                childrenCache[node.url] = FolderNode.loadChildren(of: node.url)
            }
        }
    }
}
