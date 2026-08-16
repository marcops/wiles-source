import SwiftUI

struct FolderPickerSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    var initialURL: URL?
    var onSelect: (URL) -> Void

    @State private var rootNode: FolderNode
    @State private var selectedURL: URL?
    @State private var expandedPaths: Set<URL> = []
    @State private var childrenCache: [URL: [FolderNode]] = [:]
    @State private var pathText: String = ""
    @State private var pathError: String?

    init(appState: AppState, initialURL: URL?, onSelect: @escaping (URL) -> Void) {
        self.appState = appState
        self.initialURL = initialURL
        self.onSelect = onSelect
        _rootNode = State(initialValue: FolderNode.buildRootTree())
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            contentArea
            Divider()
            footer
        }
        .frame(width: 640, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            selectedURL = initialURL ?? URL.userHome
            pathText = selectedURL?.path ?? ""
            if let selectedURL {
                expandAncestors(of: selectedURL)
            }
        }
        .onChange(of: selectedURL) { _, newValue in
            pathText = newValue?.path ?? ""
            pathError = nil
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "folder")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.selectFolder))
                    .font(.headline)
                Text(appState.tr(.selectFolderSubtitle))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            pathField
            HStack(spacing: 0) {
                if !favoriteURLs.isEmpty {
                    favoritesColumn
                    Divider()
                }
                treeColumn
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var pathField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(appState.tr(.selectFolder), text: $pathText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit(commitPathText)
                .accessibilityLabel(appState.tr(.selectFolder))
            if let pathError {
                Text(pathError)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }
        }
    }

    private var favoriteURLs: [URL] {
        appState.preferences.favoriteURLs
    }

    private var favoritesColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(favoriteURLs, id: \.self) { url in
                    favoriteRow(url)
                }
            }
            .padding(.trailing, 10)
        }
        .frame(width: 140, alignment: .top)
    }

    private var treeColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                FolderPickerNodeView(node: rootNode, depth: 0, selectedURL: $selectedURL, expandedPaths: $expandedPaths, childrenCache: $childrenCache)
                    .padding(.leading, 10)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onAppear {
                scrollToSelection(using: proxy)
            }
            .onChange(of: selectedURL) { _, _ in
                scrollToSelection(using: proxy)
            }
        }
    }

    private func scrollToSelection(using proxy: ScrollViewProxy) {
        guard let selectedURL else {
            return
        }
        DispatchQueue.main.async {
            proxy.scrollTo(selectedURL.standardizedFileURL, anchor: .center)
        }
    }

    private func favoriteRow(_ url: URL) -> some View {
        let isSelected = selectedURL?.standardizedFileURL == url.standardizedFileURL
        return HStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedURL = url
            expandAncestors(of: url)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(url.lastPathComponent)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(appState.tr(.cancel)) { dismiss() }
                .keyboardShortcut(.escape, modifiers: [])
            Button(appState.tr(.selectFolder)) {
                if let selectedURL {
                    onSelect(selectedURL)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(selectedURL == nil)
        }
        .padding(16)
    }

    private func commitPathText() {
        let expandedPath = (pathText as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        guard exists, isDirectory.boolValue else {
            pathError = appState.tr(.invalidFolderPath)
            return
        }
        pathError = nil
        selectedURL = url
        expandAncestors(of: url)
    }

    /// Ensures every folder between the tree root and `url` is expanded and has its children loaded.
    private func expandAncestors(of url: URL) {
        let home = rootNode.url
        guard url.standardizedFileURL.path.hasPrefix(home.path) else {
            return
        }
        var current = url.standardizedFileURL.deletingLastPathComponent()
        while current.path.hasPrefix(home.path) {
            expandedPaths.insert(current)
            if current != home, childrenCache[current] == nil {
                childrenCache[current] = FolderNode.loadChildren(of: current)
            }
            if current == home {
                break
            }
            current = current.deletingLastPathComponent()
        }
    }
}
