import SwiftUI

struct FolderPickerSheet: View {
    /// GCD timer, not a sibling `Task`, mirroring `SidebarView`: a stuck detached scan can starve
    /// the cooperative thread pool, and a `Task.sleep` timeout sharing that pool would starve too.
    private static let rootTreeFallbackTimeout: TimeInterval = 6
    private static let sheetWidth: CGFloat = 640
    private static let sheetHeight: CGFloat = 560
    private static let favoritesColumnWidth: CGFloat = 140

    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    var initialURL: URL?
    var onSelect: (URL) -> Void

    @State private var rootNode: FolderNode?
    @State private var rootTreeTimedOut = false
    @State private var treeBuildGeneration = 0
    @State private var selectedURL: URL?
    @State private var expandedPaths: Set<URL> = []
    @State private var childrenCache = BoundedFolderNodeCache()
    @State private var loadingChildrenURLs: Set<URL> = []
    @State private var pathText: String = ""
    @State private var pathError: String?

    init(appState: AppState, initialURL: URL?, onSelect: @escaping (URL) -> Void) {
        self.appState = appState
        self.initialURL = initialURL
        self.onSelect = onSelect
    }

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("folder"),
            title: appState.tr(.selectFolder),
            subtitle: appState.tr(.selectFolderSubtitle),
            width: Self.sheetWidth,
            height: Self.sheetHeight,
            primaryButton: ModalFooterButton(
                title: appState.tr(.selectFolder),
                isEnabled: selectedURL != nil) {
                    if let selectedURL {
                        onSelect(selectedURL)
                    }
                    dismiss()
                },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            content: { contentArea })
            .onAppear {
                selectedURL = initialURL ?? URL.userHome
                pathText = selectedURL?.path ?? ""
            }
            .onChange(of: selectedURL) { _, newValue in
                pathText = newValue?.path ?? ""
                pathError = nil
            }
            .task(id: treeBuildGeneration) {
                await buildRootNodeIfNeeded()
            }
    }

    /// Builds the root tree off `@MainActor`, mirroring `SidebarView`'s `.task` — `FolderNode.buildRootTree()`
    /// walks the whole home directory synchronously and would otherwise freeze the sheet on appear.
    /// On the fallback timeout it leaves `rootNode == nil` and shows a Retry state (like `SidebarView`);
    /// the still-running scan can still finish and populate the tree, or Retry restarts it.
    private func buildRootNodeIfNeeded() async {
        guard rootNode == nil else { return }
        rootTreeTimedOut = false
        let buildTask = Task.detached(priority: .userInitiated) { FolderNode.buildRootTree() }
        let fallbackWorkItem = DispatchWorkItem {
            guard rootNode == nil else { return }
            rootTreeTimedOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rootTreeFallbackTimeout, execute: fallbackWorkItem)
        let node = await buildTask.value
        guard rootNode == nil else { return }
        fallbackWorkItem.cancel()
        rootTreeTimedOut = false
        rootNode = node
        if let selectedURL {
            expandAncestors(of: selectedURL)
        }
    }

    private func retryTreeBuild() {
        rootNode = nil
        rootTreeTimedOut = false
        treeBuildGeneration += 1
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
        appState.preferences.favorites.favoriteURLs
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
        .frame(width: Self.favoritesColumnWidth, alignment: .top)
    }

    private var treeColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                treeColumnContent
            }
            .onAppear {
                scrollToSelection(using: proxy)
            }
            .onChange(of: selectedURL) { _, _ in
                scrollToSelection(using: proxy)
            }
            .onChange(of: expandedPaths) { _, _ in
                scrollToSelection(using: proxy)
            }
        }
    }

    @ViewBuilder private var treeColumnContent: some View {
        if let rootNode {
            FolderPickerNodeView(
                node: rootNode,
                depth: 0,
                appState: appState,
                selectedURL: $selectedURL,
                expandedPaths: $expandedPaths,
                childrenCache: $childrenCache,
                loadingURLs: $loadingChildrenURLs)
                .padding(.leading, 10)
                .padding(.trailing, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if rootTreeTimedOut {
            Button {
                retryTreeBuild()
            } label: {
                Label(appState.tr(.retry), systemImage: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .padding(.top, 20)
        } else {
            ProgressView()
                .controlSize(.small)
                .padding(.top, 20)
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
        return TappableRow(
            accessibilityLabel: url.lastPathComponent,
            isSelected: isSelected,
            action: {
                selectedURL = url
                expandAncestors(of: url)
            },
            content: {
                HStack(spacing: 6) {
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
            })
    }

    private func commitPathText() {
        let expandedPath = (pathText as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
        // fileExists(atPath:) resolves in microseconds for a local path, so it stays inline. Under
        // /Volumes/ the same call can block for seconds against a stalled network share, so it hops
        // off @MainActor there (mirrors AppState+Navigation.navigateTo(_:addToHistory:)).
        if SlowVolumePathValidator.isLikelySlowVolume(url.path) {
            Task {
                let isValidDirectory = await Task.detached(priority: .userInitiated) {
                    Self.directoryExists(at: url)
                }.value
                applyCommittedPath(url, isValidDirectory: isValidDirectory)
            }
            return
        }
        applyCommittedPath(url, isValidDirectory: Self.directoryExists(at: url))
    }

    private nonisolated static func directoryExists(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }

    private func applyCommittedPath(_ url: URL, isValidDirectory: Bool) {
        guard isValidDirectory else {
            pathError = appState.tr(.invalidFolderPath)
            return
        }
        pathError = nil
        selectedURL = url
        expandAncestors(of: url)
    }

    /// Snapshot of one ancestor-expansion pass — computed off `@MainActor` for `/Volumes/` paths so the
    /// result can be merged back in a single hop (mirrors `AppState+Navigation.RefreshSnapshot`).
    private nonisolated struct AncestorExpansion {
        let folders: [URL]
        let loadedChildren: [URL: [FolderNode]]
    }

    /// Ensures every folder between the tree root and `url` is expanded and has its children loaded.
    /// The walk itself stays synchronous for local paths; under `/Volumes/` it runs off `@MainActor`
    /// since it calls `FolderNode.loadChildren(of:)` — a `FileManager` hit — once per ancestor level.
    private func expandAncestors(of url: URL) {
        guard let home = rootNode?.url else { return }
        guard Self.isWithinOrEqual(url, home) else {
            return
        }
        let alreadyCached = childrenCache.cachedURLs
        if SlowVolumePathValidator.isLikelySlowVolume(url.path) {
            Task {
                let expansion = await Task.detached(priority: .userInitiated) {
                    Self.computeAncestorExpansion(of: url, home: home, alreadyCached: alreadyCached)
                }.value
                applyAncestorExpansion(expansion)
            }
            return
        }
        applyAncestorExpansion(Self.computeAncestorExpansion(of: url, home: home, alreadyCached: alreadyCached))
    }

    private nonisolated static func computeAncestorExpansion(of url: URL, home: URL, alreadyCached: Set<URL>) -> AncestorExpansion {
        var folders: [URL] = []
        var loadedChildren: [URL: [FolderNode]] = [:]
        var current = url.standardizedFileURL.deletingLastPathComponent()
        while isWithinOrEqual(current, home) {
            folders.append(current)
            if current != home, !alreadyCached.contains(current) {
                loadedChildren[current] = FolderNode.loadChildren(of: current)
            }
            if current == home {
                break
            }
            current = current.deletingLastPathComponent()
        }
        return AncestorExpansion(folders: folders, loadedChildren: loadedChildren)
    }

    /// Returns whether `url` is `home` itself or somewhere inside it, compared via standardized path
    /// components (not raw string prefix) so sibling directories that merely share a string prefix —
    /// e.g. home `/Users/foo` vs `/Users/foo2` — are never mistaken for an ancestor relationship.
    /// Mirrors `AppState+Navigation.childToRestore(whenLeaving:movingTo:)`.
    private nonisolated static func isWithinOrEqual(_ url: URL, _ home: URL) -> Bool {
        url.isDescendantOrSelf(of: home)
    }

    private func applyAncestorExpansion(_ expansion: AncestorExpansion) {
        for folder in expansion.folders {
            expandedPaths.insert(folder)
        }
        for (folder, children) in expansion.loadedChildren {
            childrenCache[folder] = children
        }
    }
}
