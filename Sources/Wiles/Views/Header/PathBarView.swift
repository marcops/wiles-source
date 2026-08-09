import SwiftUI
import UniformTypeIdentifiers

struct PathBarView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @FocusState private var isFocused: Bool
    @State private var isHovering = false
    @State private var breadcrumbContentWidth: CGFloat = 0

    var pathSegments: [PathSegment] {
        var res: [(name: String, url: URL)] = []
        var cur = appState.navigation.currentURL.standardizedFileURL
        var depth = 0
        while depth < 50 {
            let name: String
            if cur.path == "/" {
                name = appState.tr(.root)
            } else if cur.standardizedFileURL == URL.userTrash.standardizedFileURL {
                name = appState.tr(.sidebarTrash)
            } else {
                name = cur.lastPathComponent
            }
            res.insert((name: name, url: cur), at: 0)
            if cur.path == "/" || cur.path.isEmpty { break }
            let parent = cur.deletingLastPathComponent()
            if parent.path == cur.path || parent == cur { break }
            cur = parent
            depth += 1
        }
        return res.enumerated().map { index, item in
            PathSegment(name: item.name, url: item.url, isFirst: index == 0)
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if windowUIState.isEditingPath {
                textFieldMode
            } else {
                breadcrumbMode
            }
        }
        .animation(MotionTokens.quickEase, value: windowUIState.isEditingPath)
    }

    private var textFieldMode: some View {
        @Bindable var appState = appState
        return HStack(spacing: 6) {
            Image(systemName: "folder").foregroundColor(.secondary)
            TextField(appState.tr(.enterPathPlaceholder), text: $appState.navigation.pathText)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    let url = URL(fileURLWithPath: (appState.navigation.pathText as NSString).expandingTildeInPath)
                    appState.navigateTo(url)
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
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        .background(ClickOutsideDetector {
            windowUIState.isEditingPath = false
        })
        .onAppear { isFocused = true }
    }

    private var breadcrumbMode: some View {
        HStack(spacing: 0) {
            GeometryReader { outerGeo in
                breadcrumbScrollView(outerGeo: outerGeo)
            }
            .background(hiddenFullBreadcrumbMeasurer)

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
    }

    private func breadcrumbScrollView(outerGeo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                breadcrumbPillRow
                    .padding(.horizontal, 4)
                    .frame(height: 28)
            }
            .onChange(of: isHovering) { _, hovering in
                handleHoverChange(hovering: hovering, outerWidth: outerGeo.size.width, proxy: proxy)
            }
        }
    }

    @ViewBuilder private var breadcrumbPillRow: some View {
        HStack(spacing: 2) {
            if isHovering {
                ForEach(pathSegments) { item in
                    breadcrumbPill(for: item)
                        .id(item.id)
                    if item.url != appState.navigation.currentURL.standardizedFileURL {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            } else if let last = pathSegments.last {
                breadcrumbPill(for: last, isCollapsed: true)
            }
        }
    }

    // fullBreadcrumbWidth comes from the always-rendered hidden measurer below, so it's already
    // known by the time this fires — no race with the ForEach switching content in this same
    // transition.
    private func handleHoverChange(hovering: Bool, outerWidth: CGFloat, proxy: ScrollViewProxy) {
        guard hovering, breadcrumbContentWidth > outerWidth,
              let lastID = pathSegments.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(lastID, anchor: .trailing)
        }
    }

    /// Renders the full breadcrumb off-screen at all times, purely to know its natural width
    /// ahead of the hover transition — decoupled from the visible collapsed/expanded toggle so
    /// there's no one-frame-late race between measuring and deciding whether to scroll.
    private var hiddenFullBreadcrumbMeasurer: some View {
        HStack(spacing: 2) {
            ForEach(pathSegments) { item in
                breadcrumbPill(for: item)
                if item.url != appState.navigation.currentURL.standardizedFileURL {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                }
            }
        }
        .padding(.horizontal, 4)
        .fixedSize()
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: BreadcrumbContentWidthKey.self, value: geo.size.width)
            }
        )
        .opacity(0)
        .allowsHitTesting(false)
        .frame(width: 0, height: 0)
        .clipped()
        .onPreferenceChange(BreadcrumbContentWidthKey.self) { breadcrumbContentWidth = $0 }
    }

    private func breadcrumbPill(for item: PathSegment, isCollapsed: Bool = false) -> some View {
        let isHome = item.url.standardizedFileURL == URL.userHome.standardizedFileURL
        return HStack(spacing: 4) {
            if isHome { Image(systemName: "house.fill").font(.system(size: 11)) }
            Text(item.name).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .hoverHighlight(
            isSelected: !isCollapsed && item.url == appState.navigation.currentURL,
            hoverBackground: Color.accentColor.opacity(0.12),
            selectedBackground: Color.accentColor.opacity(0.2),
            cornerRadius: 4
        )
        .foregroundColor(isCollapsed || item.url == appState.navigation.currentURL ? .primary : .secondary)
        .contentShape(Rectangle())
        .onTapGesture { appState.navigateTo(item.url) }
        .accessibilityLabel(item.name)
        .accessibilityHint(appState.tr(.folder))
        .accessibilityAddTraits(item.url == appState.navigation.currentURL ? [.isButton, .isSelected] : [.isButton])
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers, targetFolder: item.url)
            return true
        }
    }

    private func handleDrop(providers: [NSItemProvider], targetFolder: URL) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                Task { @MainActor in
                    do {
                        _ = try appState.moveItem(at: url, toFolder: targetFolder)
                    } catch {
                        appState.showError(error)
                    }
                    appState.refreshCurrentDirectory()
                }
            }
        }
    }
}
