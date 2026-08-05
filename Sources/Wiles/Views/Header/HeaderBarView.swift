import SwiftUI
import AppKit

struct HeaderBarView: View {
    var appState: AppState
    @FocusState private var isSearchFocused: Bool
    @State private var viewSwitcherExpanded = false

    var body: some View {
        HStack(spacing: 12) {
            historyButtons
            if appState.isSearching {
                searchField.frame(maxWidth: .infinity)
            } else {
                PathBarView(appState: appState).frame(maxWidth: .infinity)
            }
            rightControls
                .padding(.trailing, -2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(TrafficLightRepositioner(offsetX: 6, offsetY: 6))
        .doubleClickToZoom()
    }

    private var historyButtons: some View {
        HStack(spacing: 4) {
            Button { appState.goBack() } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(appState.historyBack.isEmpty)
            .opacity(appState.historyBack.isEmpty ? 0.4 : 1.0)
            .help(appState.tr(.back))
            .accessibilityLabel(appState.tr(.back))
            .accessibilityHint(appState.tr(.back))

            Button { appState.goForward() } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(appState.historyForward.isEmpty)
            .opacity(appState.historyForward.isEmpty ? 0.4 : 1.0)
            .help(appState.tr(.forward))
            .accessibilityLabel(appState.tr(.forward))
            .accessibilityHint(appState.tr(.forward))
        }
    }

    private var rightControls: some View {
        HStack(spacing: 8) {
            searchButton
            viewSwitcher
        }
    }

    private var searchField: some View {
        @Bindable var appState = appState
        return HStack(spacing: 6) {
            TextField("\(appState.tr(.searchPlaceholder)) \(appState.currentURL.lastPathComponent)...", text: $appState.searchQuery)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isSearchFocused = true
                    }
                }
                .onSubmit {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
                .onExitCommand {
                    withAnimation(MotionTokens.quickEase) {
                        appState.isSearching = false
                        appState.searchQuery = ""
                    }
                }

            searchFilterMenu

            if !appState.searchQuery.isEmpty {
                Button { appState.showSaveSmartFolderSheet = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(appState.tr(.saveAsSmartFolder))

                Button { appState.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        .background(ClickOutsideDetector {
            if appState.isSearching && appState.searchQuery.isEmpty {
                withAnimation(MotionTokens.quickEase) {
                    appState.isSearching = false
                }
            }
        })
    }

    private var searchFilterMenu: some View {
        @Bindable var appState = appState
        return Menu {
            Picker(appState.tr(.searchScope), selection: $appState.searchScope) {
                Text(appState.tr(.searchByName)).tag(SearchScope.name)
                Text(appState.tr(.searchByContent)).tag(SearchScope.content)
            }
            Divider()
            Button("Modified Today (date:today)") {
                appState.searchQuery = "date:today"
                appState.refreshCurrentDirectory()
            }
            Button(appState.tr(.filterModified7Days)) {
                appState.searchQuery = "date:7d"
                appState.refreshCurrentDirectory()
            }
            Button("Modified Past 30 Days (date:30d)") {
                appState.searchQuery = "date:30d"
                appState.refreshCurrentDirectory()
            }

            Divider()

            Button(appState.tr(.filterImages)) {
                appState.searchQuery = "kind:image"
                appState.refreshCurrentDirectory()
            }
            Button(appState.tr(.filterDocuments)) {
                appState.searchQuery = "kind:doc"
                appState.refreshCurrentDirectory()
            }
            Button(appState.tr(.filterCodeFiles)) {
                appState.searchQuery = "kind:code"
                appState.refreshCurrentDirectory()
            }
            Button(appState.tr(.filterPDFs)) {
                appState.searchQuery = "kind:pdf"
                appState.refreshCurrentDirectory()
            }
            Button(appState.tr(.filterFolders)) {
                appState.searchQuery = "kind:folder"
                appState.refreshCurrentDirectory()
            }

            Divider()

            Button(appState.tr(.filterLargeFiles)) {
                appState.searchQuery = "size:>100m"
                appState.refreshCurrentDirectory()
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .help("Search Filters (Date, Type, Size)")
    }

    private var searchButton: some View {
        Button {
            withAnimation { appState.toggleSearching() }
        } label: {
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .foregroundColor(appState.isSearching ? .accentColor : .primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help("\(appState.tr(.searchPlaceholder)) (Cmd+F)")
    }

    private func iconName(for mode: ViewMode) -> String {
        switch mode {
        case .grid:   return "square.grid.2x2"
        case .list:   return "list.bullet"
        case .column: return "sidebar.left"
        }
    }

    private func accessibilityID(for mode: ViewMode) -> String {
        switch mode {
        case .grid:   return "ViewModeGrid"
        case .list:   return "ViewModeList"
        case .column: return "ViewModeColumn"
        }
    }

    private var viewSwitcher: some View {
        HStack(spacing: 2) {
            if viewSwitcherExpanded {
                ForEach(ViewMode.allCases) { mode in
                    Button {
                        withAnimation(MotionTokens.snappySpring) {
                            appState.viewMode = mode
                            viewSwitcherExpanded = false
                        }
                    } label: {
                        Image(systemName: iconName(for: mode)).font(.system(size: 12))
                            .frame(width: 26, height: 24)
                            .background(appState.viewMode == mode ? Color.accentColor : Color.clear)
                            .foregroundColor(appState.viewMode == mode ? .white : .primary)
                            .cornerRadius(4)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(accessibilityID(for: mode))
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            } else {
                Button {
                    withAnimation(MotionTokens.snappySpring) {
                        viewSwitcherExpanded = true
                    }
                } label: {
                    Image(systemName: iconName(for: appState.viewMode)).font(.system(size: 12))
                        .frame(width: 26, height: 24)
                        .background(Color.clear)
                        .foregroundColor(.primary)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("View Mode")
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
        .padding(2)
        .animation(MotionTokens.expandSpring, value: viewSwitcherExpanded)
        .background(ClickOutsideDetector {
            if viewSwitcherExpanded { viewSwitcherExpanded = false }
        })
    }

}

struct TrafficLightRepositioner: NSViewRepresentable {
    var offsetX: CGFloat = 0
    let offsetY: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = RepositionerView()
        view.offsetX = offsetX
        view.offsetY = offsetY
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? RepositionerView {
            view.offsetX = offsetX
            view.offsetY = offsetY
        }
    }

    class RepositionerView: NSView {
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 6
        private var baseOrigins: [ObjectIdentifier: CGFloat] = [:]

        /// Purely a passive layout observer — must never intercept clicks meant for whatever's
        /// drawn on top of or behind it, since the default NSView.hitTest claims everything.
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reposition()
        }

        override func layout() {
            super.layout()
            reposition()
        }

        private func reposition() {
            guard let window = self.window,
                  let closeBtn = window.standardWindowButton(.closeButton),
                  let superview = closeBtn.superview else { return }

            let buttons = [
                window.standardWindowButton(.closeButton),
                window.standardWindowButton(.miniaturizeButton),
                window.standardWindowButton(.zoomButton)
            ]

            for btn in buttons {
                guard let button = btn else { continue }
                let key = ObjectIdentifier(button)
                // AppKit re-centers these buttons on every window layout pass, so the stock
                // x-position (before our offset) has to be captured once and reused — otherwise
                // offsetX compounds further right on every subsequent `layout()` call.
                let baseX = baseOrigins[key] ?? button.frame.origin.x
                baseOrigins[key] = baseX

                var buttonFrame = button.frame
                buttonFrame.origin.x = baseX + offsetX
                buttonFrame.origin.y = (superview.bounds.height - buttonFrame.height) / 2 - offsetY
                button.setFrameOrigin(buttonFrame.origin)
            }
        }
    }
}
