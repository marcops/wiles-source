import SwiftUI

struct FolderPickerSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    var initialURL: URL?
    var onSelect: (URL) -> Void

    @State private var rootNode: FolderNode = FolderNode.buildRootTree()
    @State private var selectedURL: URL?
    @State private var expandedPaths: Set<URL> = []

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                quickLocationsColumn
                Divider()
                treeColumn
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            selectedURL = initialURL
            if let initialURL { expandAncestors(of: initialURL) }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.accentColor)
            Text(appState.tr(.selectFolder))
                .font(.headline)
            Spacer()
        }
        .padding(16)
    }

    private var quickLocationsColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(quickLocations, id: \.url) { location in
                quickLocationRow(location)
            }
            Spacer()
        }
        .padding(10)
        .frame(width: 160, alignment: .top)
    }

    private func quickLocationRow(_ location: (name: String, url: URL, icon: String)) -> some View {
        Button {
            selectedURL = location.url
            expandAncestors(of: location.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: location.icon)
                    .foregroundColor(.accentColor)
                Text(location.name)
                    .font(.system(size: 12))
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(selectedURL?.standardizedFileURL == location.url.standardizedFileURL ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(location.name)
    }

    private var treeColumn: some View {
        ScrollView {
            FolderPickerNodeView(node: rootNode, depth: 0, selectedURL: $selectedURL, expandedPaths: $expandedPaths)
                .padding(10)
        }
    }

    private var footer: some View {
        HStack {
            Text(selectedURL?.path ?? "")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.head)
            Spacer()
            Button(appState.tr(.cancel)) { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
            Button(appState.tr(.selectFolder)) {
                if let selectedURL { onSelect(selectedURL) }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(selectedURL == nil)
        }
        .padding(12)
    }

    private var quickLocations: [(name: String, url: URL, icon: String)] {
        [
            (appState.tr(.home), URL.userHome, "house"),
            (appState.tr(.desktop), URL.userHome.appendingPathComponent("Desktop"), "menubar.dock.rectangle"),
            (appState.tr(.documents), URL.userHome.appendingPathComponent("Documents"), "folder"),
            (appState.tr(.downloads), URL.userHome.appendingPathComponent("Downloads"), "arrow.down.circle")
        ]
    }

    private func expandAncestors(of url: URL) {
        var current = url.standardizedFileURL
        while current.pathComponents.count > 1 {
            expandedPaths.insert(current)
            current = current.deletingLastPathComponent()
        }
    }
}

private struct FolderPickerNodeView: View {
    let node: FolderNode
    let depth: Int
    @Binding var selectedURL: URL?
    @Binding var expandedPaths: Set<URL>

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(node.url) },
            set: { newValue in
                if newValue { expandedPaths.insert(node.url) } else { expandedPaths.remove(node.url) }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let children = node.children, !children.isEmpty {
                DisclosureGroup(isExpanded: isExpandedBinding) {
                    ForEach(children) { child in
                        FolderPickerNodeView(node: child, depth: depth + 1, selectedURL: $selectedURL, expandedPaths: $expandedPaths)
                    }
                } label: { rowLabel }
            } else {
                rowLabel
            }
        }
    }

    private var rowLabel: some View {
        let isSelected = selectedURL?.standardizedFileURL == node.url.standardizedFileURL
        return Button {
            selectedURL = node.url
        } label: {
            HStack(spacing: 6) {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(node.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
