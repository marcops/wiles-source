import GitBeacon
import SwiftUI
import UniformTypeIdentifiers

struct PathBarView: View {
    /// Hard cap on ancestor-walk iterations while building the breadcrumb trail, guarding
    /// against an unbounded loop if a pathological URL never reaches "/".
    private static let maxPathDepth = 50

    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @State private var isDragHovering = false
    @State private var scrollWorkItem: DispatchWorkItem?
    @State private var dragTargetSegmentID: String?
    @State private var pathSegments: [PathSegment] = []

    var body: some View {
        HStack(spacing: 4) {
            if windowUIState.isEditingPath {
                textFieldMode
            } else {
                breadcrumbMode(segments: pathSegments)
            }
        }
        .animation(MotionTokens.quickEase, value: windowUIState.isEditingPath)
        .onAppear { recomputePathSegments() }
        .onChange(of: appState.navigation.currentURL) { _, _ in recomputePathSegments() }
        .onChange(of: appState.preferences.appLanguage) { _, _ in recomputePathSegments() }
    }

    /// Breadcrumb trail is a pure function of currentURL + localized Root/Trash labels; cache it in
    /// @State and rebuild only on those changes, not on every hover/drag re-render.
    private func recomputePathSegments() {
        pathSegments = Self.buildSegments(
            currentURL: appState.navigation.currentURL,
            rootLabel: appState.tr(.root),
            trashLabel: appState.tr(.sidebarTrash))
    }

    static func buildSegments(currentURL: URL, rootLabel: String, trashLabel: String) -> [PathSegment] {
        let trashPath = URL.userTrash.standardizedFileURL
        var res: [(name: String, url: URL)] = []
        var cur = currentURL.standardizedFileURL
        var depth = 0
        while depth < maxPathDepth {
            let name: String = if cur.path == "/" {
                rootLabel
            } else if cur.standardizedFileURL == trashPath {
                trashLabel
            } else {
                cur.lastPathComponent
            }
            res.insert((name: name, url: cur), at: 0)
            if cur.path == "/" || cur.path.isEmpty {
                break
            }
            let parent = cur.deletingLastPathComponent()
            if parent.path == cur.path || parent == cur {
                break
            }
            cur = parent
            depth += 1
        }
        return res.enumerated().map { index, item in
            PathSegment(name: item.name, url: item.url, isLast: index == res.count - 1)
        }
    }

    private var textFieldMode: some View {
        @Bindable var appState = appState
        return HStack(spacing: 6) {
            Image(systemName: "folder").foregroundColor(.secondary)
            TextField(appState.tr(.enterPathPlaceholder), text: $appState.navigation.pathText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .accessibilityIdentifier("PathBarTextField")
                .onSubmit {
                    let trimmed = appState.navigation.pathText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let url = URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath)
                    if FileManager.default.fileExists(atPath: url.path) {
                        appState.navigateTo(url)
                    } else {
                        appState.showError(WilesError.itemNotFound(path: url.path))
                    }
                    windowUIState.isEditingPath = false
                }
                .onExitCommand {
                    appState.navigation.pathText = appState.navigation.currentURL.path
                    windowUIState.isEditingPath = false
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        windowUIState.isEditingPath = false
                    }
                }
        }
        .headerFieldChrome()
        .background(ClickOutsideDetector {
            windowUIState.isEditingPath = false
        })
        .onAppear { isFocused = true }
    }

    private func breadcrumbMode(segments: [PathSegment]) -> some View {
        HStack(spacing: 0) {
            breadcrumbScrollView(segments: segments)

            Spacer(minLength: 4)
        }
        .frame(height: 28)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(MotionTokens.quickEase) { isHovering = hovering }
        }
        .onTapGesture(count: 2) {
            appState.navigation.pathText = appState.navigation.currentURL.path
            windowUIState.isEditingPath = true
        }
        // `.onHover` doesn't fire during an active drag; this catches drag-over instead so the
        // bar still expands. The `false` leaves the actual drop to the pills below.
        .onDrop(of: [.fileURL], isTargeted: $isDragHovering) { _ in false }
    }

    private var showsFullBreadcrumb: Bool {
        isHovering || isDragHovering || appState.preferences.alwaysShowFullPathBar
    }

    private func breadcrumbScrollView(segments: [PathSegment]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                breadcrumbPillRow(segments: segments)
                    .padding(.horizontal, 4)
                    .frame(height: 28)
            }
            .onAppear { scrollToEnd(proxy: proxy, segments: segments) }
            .onChange(of: isHovering) { _, _ in scrollToEnd(proxy: proxy, segments: segments) }
            .onChange(of: isDragHovering) { _, _ in scrollToEnd(proxy: proxy, segments: segments) }
            .onChange(of: appState.preferences.alwaysShowFullPathBar) { _, _ in scrollToEnd(proxy: proxy, segments: segments) }
            .onChange(of: appState.navigation.currentURL) { _, _ in scrollToEnd(proxy: proxy, segments: segments) }
        }
    }

    private func breadcrumbPillRow(segments: [PathSegment]) -> some View {
        HStack(spacing: 2) {
            if showsFullBreadcrumb {
                ForEach(segments) { item in
                    breadcrumbPill(for: item)
                        .id(item.id)
                    if !item.isLast {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            } else if let last = segments.last {
                breadcrumbPill(for: last, isCollapsed: true)
            }
        }
    }

    /// Waits out the row's own expand animation before scrolling — firing on the very next run
    /// loop tick lands against a still-animating (not yet final) content width and undershoots.
    private func scrollToEnd(proxy: ScrollViewProxy, segments: [PathSegment]) {
        guard let lastID = segments.last?.id else { return }
        scrollWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation(.linear(duration: 0)) {
                proxy.scrollTo(lastID, anchor: .trailing)
            }
        }
        scrollWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.pathBarScrollDelay, execute: workItem)
    }

    private func breadcrumbPill(for item: PathSegment, isCollapsed: Bool = false) -> some View {
        let isHome = item.url.standardizedFileURL == URL.userHome.standardizedFileURL
        let currentURL = appState.navigation.currentURL.standardizedFileURL
        let isCurrent = item.url == currentURL
        return HStack(spacing: 4) {
            if isHome {
                Image(systemName: "house.fill").font(.system(size: 11))
            }
            Text(item.name).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .hoverHighlight(
            isSelected: !isCollapsed && isCurrent,
            hoverBackground: Color.accentColor.opacity(0.12),
            selectedBackground: Color.accentColor.opacity(0.2),
            cornerRadius: 4)
        .foregroundColor(isCollapsed || isCurrent ? .primary : .secondary)
        .background(dragTargetSegmentID == item.id ? Color.accentColor.opacity(0.25) : Color.clear)
        .cornerRadius(4)
        .scaleEffect(dragTargetSegmentID == item.id ? 1.05 : 1.0)
        .animation(MotionTokens.snappySpring, value: dragTargetSegmentID)
        .contentShape(Rectangle())
        .onTapGesture { appState.navigateTo(item.url) }
        .accessibilityLabel(item.name)
        .accessibilityHint(appState.tr(.folder))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : [.isButton])
        .onDrop(
            of: [.fileURL],
            isTargeted: Binding(
                get: { dragTargetSegmentID == item.id },
                set: { dragTargetSegmentID = $0 ? item.id : nil })) { providers in
            handleDrop(providers: providers, targetFolder: item.url)
        }
    }

    @discardableResult
    private func handleDrop(providers: [NSItemProvider], targetFolder: URL) -> Bool {
        Task { @MainActor in
            var urls: [URL] = []
            for provider in providers {
                if let url = await Self.loadDroppedURL(from: provider) {
                    urls.append(url)
                }
            }
            let movable = urls.filter {
                $0.deletingLastPathComponent().standardizedFileURL != targetFolder.standardizedFileURL
            }
            guard !movable.isEmpty else { return }
            _ = await appState.moveItemsResolvingCollisions(movable, toFolder: targetFolder, windowUIState: windowUIState)
            appState.refreshCurrentDirectory()
        }
        return !providers.isEmpty
    }

    private static func loadDroppedURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
