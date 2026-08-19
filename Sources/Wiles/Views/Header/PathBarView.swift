import GitBeacon
import SwiftUI
import UniformTypeIdentifiers

struct PathBarView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @FocusState private var isFocused: Bool
    @State private var isHovering = false

    var pathSegments: [PathSegment] {
        var res: [(name: String, url: URL)] = []
        var cur = appState.navigation.currentURL.standardizedFileURL
        var depth = 0
        while depth < 50 {
            let name: String = if cur.path == "/" {
                appState.tr(.root)
            } else if cur.standardizedFileURL == URL.userTrash.standardizedFileURL {
                appState.tr(.sidebarTrash)
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
                .accessibilityIdentifier("PathBarTextField")
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
            breadcrumbScrollView

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

    private var showsFullBreadcrumb: Bool {
        isHovering || appState.preferences.alwaysShowFullPathBar
    }

    private var breadcrumbScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                breadcrumbPillRow
                    .padding(.horizontal, 4)
                    .frame(height: 28)
            }
            .onAppear { scrollToEnd(proxy: proxy) }
            .onChange(of: isHovering) { _, _ in scrollToEnd(proxy: proxy) }
            .onChange(of: appState.preferences.alwaysShowFullPathBar) { _, _ in scrollToEnd(proxy: proxy) }
            .onChange(of: appState.navigation.currentURL) { _, _ in scrollToEnd(proxy: proxy) }
        }
    }

    private var breadcrumbPillRow: some View {
        HStack(spacing: 2) {
            if showsFullBreadcrumb {
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

    /// Keeps the bar's scroll position pinned to the current folder (trailing edge) whenever it
    /// could be off-screen — the row is `.trailing`-anchored so a short collapsed pill already
    /// sits at the right, and this covers the case where the full breadcrumb overflows the
    /// visible width (on hover, when the "always show full path bar" setting is on, and on every
    /// navigation) so the scroll never rests showing the left/root end instead.
    private func scrollToEnd(proxy: ScrollViewProxy) {
        guard let lastID = pathSegments.last?.id else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(lastID, anchor: .trailing)
        }
    }

    private func breadcrumbPill(for item: PathSegment, isCollapsed: Bool = false) -> some View {
        let isHome = item.url.standardizedFileURL == URL.userHome.standardizedFileURL
        return HStack(spacing: 4) {
            if isHome {
                Image(systemName: "house.fill").font(.system(size: 11))
            }
            Text(item.name).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .hoverHighlight(
            isSelected: !isCollapsed && item.url == appState.navigation.currentURL,
            hoverBackground: Color.accentColor.opacity(0.12),
            selectedBackground: Color.accentColor.opacity(0.2),
            cornerRadius: 4)
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
                guard let url else { return }
                Task { @MainActor in
                    do {
                        _ = try appState.moveItem(at: url, toFolder: targetFolder)
                    } catch {
                        ErrorReporter.report(error, context: "Handling path bar drop")
                        appState.showError(error)
                    }
                    appState.refreshCurrentDirectory()
                }
            }
        }
    }
}
