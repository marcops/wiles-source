import AppKit
import SwiftUI

struct HeaderBarView: View {
    /// Minimum leading inset for the header row when there's no sidebar pane to its left reserving
    /// room for the repositioned traffic-light window buttons (see `TrafficLightRepositioner`).
    private static let trafficLightsSafeLeadingInset: CGFloat = 40.0
    private static let defaultLeadingInset: CGFloat = 12.0
    /// Trailing space after `rightControls` — 12pt row padding minus 2pt to bring the view
    /// switcher closer to the trailing edge.
    private static let rightControlsTrailingInset: CGFloat = 10.0

    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @FocusState private var isSearchFocused: Bool
    @State private var viewSwitcherExpanded = false

    var body: some View {
        HStack(spacing: 12) {
            historyButtons
            if appState.selection.isSearching {
                searchField.frame(maxWidth: .infinity)
            } else {
                PathBarView(appState: appState).frame(maxWidth: .infinity)
            }
            rightControls
        }
        .padding(.leading, sidebarProvidesSafeLeadingInset ? Self.defaultLeadingInset : Self.trafficLightsSafeLeadingInset)
        .padding(.trailing, Self.rightControlsTrailingInset)
        .padding(.top, 6)
        .padding(.bottom, 6)
        // Content sits clear of the traffic lights at rest, but the leading inset above animates
        // (sidebar collapsing/appearing), so content can transiently slide through that reserved
        // zone. Fading it out there instead of letting it visibly pass under the (unclickable)
        // buttons reads as intentional rather than a layout glitch.
        .mask(alignment: .leading) {
            if sidebarProvidesSafeLeadingInset {
                Color.black
            } else {
                HStack(spacing: 0) {
                    LinearGradient(
                        colors: [.black.opacity(0), .black],
                        startPoint: .leading, endPoint: .trailing)
                        .frame(width: Self.trafficLightsSafeLeadingInset)
                    Color.black
                }
            }
        }
        .background(TrafficLightRepositioner())
        .background(
            // Spans the whole header row (search field + the search toggle button included) so
            // clicking the search button itself never counts as an "outside" click — it used to,
            // since this only wrapped the search field, racing the button's own toggle and making
            // a second click on the button re-open the search instead of closing it.
            Group {
                if appState.selection.isSearching {
                    ClickOutsideDetector {
                        if appState.selection.searchQuery.isEmpty {
                            withAnimation(MotionTokens.quickEase) {
                                appState.selection.isSearching = false
                            }
                        }
                    }
                }
            })
        .doubleClickToZoom()
    }

    /// False whenever the sidebar isn't reserving enough leading width to clear the repositioned
    /// traffic-light buttons — fully hidden, or collapsed to its icon-only rail and not peeking.
    private var sidebarProvidesSafeLeadingInset: Bool {
        guard appState.preferences.hasVisibleSidebarContent else { return false }
        return !appState.preferences.isSidebarCollapsed || windowUIState.isSidebarPeeking
    }

    private var historyButtons: some View {
        HStack(spacing: 4) {
            Button { appState.goBack() } label: {
                Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(appState.navigation.historyBack.isEmpty)
            .opacity(appState.navigation.historyBack.isEmpty ? 0.4 : 1.0)
            .help(appState.tr(.back))
            .accessibilityLabel(appState.tr(.back))

            Button { appState.goForward() } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(appState.navigation.historyForward.isEmpty)
            .opacity(appState.navigation.historyForward.isEmpty ? 0.4 : 1.0)
            .help(appState.tr(.forward))
            .accessibilityLabel(appState.tr(.forward))
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
            searchTextField
            searchEverywhereToggle
            searchFilterMenu
            if !appState.selection.searchQuery.isEmpty {
                searchQueryActionButtons
            }
        }
        .headerFieldChrome()
    }

    private var searchTextField: some View {
        @Bindable var appState = appState
        return TextField("\(appState.tr(.searchPlaceholder)) \(appState.navigation.currentURL.lastPathComponent)...", text: $appState.selection.searchQuery)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focused($isSearchFocused)
            .task {
                guard !appState.smartFolder.suppressNextSearchFocus else {
                    appState.smartFolder.suppressNextSearchFocus = false
                    return
                }
                try? await Task.sleep(for: .seconds(AsyncDelayTokens.searchFieldFocusDelay))
                isSearchFocused = true
            }
            .onSubmit {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
            .onExitCommand {
                withAnimation(MotionTokens.quickEase) {
                    appState.selection.isSearching = false
                    appState.selection.searchQuery = ""
                }
            }
    }

    @ViewBuilder private var searchQueryActionButtons: some View {
        Button { windowUIState.showSaveSmartFolderSheet = true } label: {
            Image(systemName: "folder.badge.plus")
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(appState.tr(.saveAsSmartFolder))
        .accessibilityLabel(appState.tr(.saveAsSmartFolder))
        .accessibilityHint(appState.tr(.saveAsSmartFolderHint))

        Button { appState.selection.searchQuery = "" } label: {
            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.tr(.clearSearch))
        .accessibilityHint(appState.tr(.clearSearchHint))
    }

    private var searchFilterMenu: some View {
        Menu {
            searchFilterMenuContent
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .menuStyle(.borderlessButton)
        .help(appState.tr(.searchFiltersHelp))
        .accessibilityLabel(appState.tr(.searchFiltersHelp))
        .accessibilityHint(appState.tr(.searchFiltersMenuHint))
    }

    @ViewBuilder private var searchFilterMenuContent: some View {
        @Bindable var appState = appState
        Picker(appState.tr(.searchScope), selection: $appState.preferences.searchScope) {
            Text(appState.tr(.searchByName)).tag(SearchScope.name)
            Text(appState.tr(.searchByContent)).tag(SearchScope.content)
            Text(appState.tr(.searchByBoth)).tag(SearchScope.both)
        }
        Toggle(appState.tr(.searchCaseSensitive), isOn: $appState.preferences.searchCaseSensitive)
        Toggle(appState.tr(.searchIncludeHiddenFolders), isOn: includeHiddenFoldersBinding)
        Divider()
        dateFilterButtons
        Divider()
        kindFilterButtons
        Divider()
        Button(appState.tr(.filterLargeFiles)) {
            applyQuickFilter("size:>100m")
        }
    }

    /// Sets the search query to a quick-filter token (e.g. `date:today`, `kind:image`) and
    /// re-runs the directory listing, shared by the large-files, date, and kind filter buttons.
    private func applyQuickFilter(_ token: String) {
        appState.selection.searchQuery = token
    }

    @ViewBuilder private var dateFilterButtons: some View {
        Button(appState.tr(.filterModifiedToday)) {
            applyQuickFilter("date:today")
        }
        Button(appState.tr(.filterModified7Days)) {
            applyQuickFilter("date:7d")
        }
        Button(appState.tr(.filterModified30Days)) {
            applyQuickFilter("date:30d")
        }
    }

    @ViewBuilder private var kindFilterButtons: some View {
        Button(appState.tr(.filterImages)) {
            applyQuickFilter("kind:image")
        }
        Button(appState.tr(.filterDocuments)) {
            applyQuickFilter("kind:doc")
        }
        Button(appState.tr(.filterCodeFiles)) {
            applyQuickFilter("kind:code")
        }
        Button(appState.tr(.filterPDFs)) {
            applyQuickFilter("kind:pdf")
        }
        Button(appState.tr(.filterFolders)) {
            applyQuickFilter("kind:folder")
        }
    }

    /// Mirrors the `hidden:true` token in `appState.selection.searchQuery` — same query-language convention
    /// as `date:`/`kind:`/`size:` used elsewhere in this menu, defaulting off (hidden folders are
    /// excluded from search unless explicitly requested).
    private var includeHiddenFoldersBinding: Binding<Bool> {
        Binding(
            get: { SearchFilterService.extractHiddenFlag(from: appState.selection.searchQuery).includeHidden },
            set: { newValue in
                let (strippedQuery, _) = SearchFilterService.extractHiddenFlag(from: appState.selection.searchQuery)
                if newValue {
                    appState.selection.searchQuery = strippedQuery.isEmpty ? "hidden:true" : "\(strippedQuery) hidden:true"
                } else {
                    appState.selection.searchQuery = strippedQuery
                }
            })
    }

    private var searchButton: some View {
        Button {
            withAnimation(MotionTokens.quickEase) { appState.toggleSearching() }
        } label: {
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .foregroundColor(appState.selection.isSearching ? .accentColor : .primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help(appState.trWithShortcutHint(.actSearch, shortcut: KeyLabel.cmdF))
        .accessibilityLabel(appState.tr(.actSearch))
        .accessibilityHint(appState.tr(.find))
    }

    private var searchEverywhereToggle: some View {
        @Bindable var appState = appState
        return Button {
            appState.preferences.searchEverywhere.toggle()
            appState.refreshCurrentDirectory()
        } label: {
            Text(appState.tr(.searchEverywhere)).font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 6)
                .frame(height: 22)
                .foregroundColor(appState.preferences.searchEverywhere ? .white : .primary)
                .background(appState.preferences.searchEverywhere ? Color.accentColor : Color(NSColor.controlColor))
                .cornerRadius(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(appState.tr(.searchEverywhereHelp))
        .accessibilityLabel(appState.tr(.searchEverywhere))
        .accessibilityHint(appState.tr(.searchEverywhereHelp))
        .accessibilityAddTraits(appState.preferences.searchEverywhere ? [.isButton, .isSelected] : [.isButton])
    }

    private func iconName(for mode: ViewMode) -> String {
        switch mode {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }

    private func accessibilityID(for mode: ViewMode) -> String {
        switch mode {
        case .grid: "ViewModeGrid"
        case .list: "ViewModeList"
        }
    }

    private func accessibilityLabel(for mode: ViewMode) -> String {
        switch mode {
        case .grid: appState.tr(.gridView)
        case .list: appState.tr(.listView)
        }
    }

    private var viewSwitcher: some View {
        HStack(spacing: 2) {
            if viewSwitcherExpanded {
                expandedViewModeButtons
            } else {
                collapsedViewModeButton
            }
        }
        .padding(2)
        .animation(MotionTokens.expandSpring, value: viewSwitcherExpanded)
        .background(Group {
            if viewSwitcherExpanded {
                ClickOutsideDetector { viewSwitcherExpanded = false }
            }
        })
    }

    private var expandedViewModeButtons: some View {
        ForEach(ViewMode.allCases) { mode in
            Button {
                withAnimation(MotionTokens.snappySpring) {
                    appState.preferences.viewMode = mode
                    viewSwitcherExpanded = false
                }
            } label: {
                Image(systemName: iconName(for: mode)).font(.system(size: 12))
                    .frame(width: 26, height: 24)
                    .background(appState.preferences.viewMode == mode ? Color.accentColor : Color.clear)
                    .foregroundColor(appState.preferences.viewMode == mode ? .white : .primary)
                    .cornerRadius(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(accessibilityID(for: mode))
            .accessibilityLabel(accessibilityLabel(for: mode))
            .accessibilityHint(appState.tr(.viewMode))
            .accessibilityAddTraits(appState.preferences.viewMode == mode ? [.isButton, .isSelected] : [.isButton])
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }

    private var collapsedViewModeButton: some View {
        Button {
            withAnimation(MotionTokens.snappySpring) {
                viewSwitcherExpanded = true
            }
        } label: {
            Image(systemName: iconName(for: appState.preferences.viewMode)).font(.system(size: 12))
                .frame(width: 26, height: 24)
                .background(Color.clear)
                .foregroundColor(.primary)
                .cornerRadius(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("View Mode")
        .accessibilityLabel(accessibilityLabel(for: appState.preferences.viewMode))
        .accessibilityHint(appState.tr(.viewMode))
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
