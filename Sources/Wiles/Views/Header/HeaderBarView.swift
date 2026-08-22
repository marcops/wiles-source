import AppKit
import SwiftUI

struct HeaderBarView: View {
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
                .padding(.trailing, -2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(TrafficLightRepositioner(offsetX: 6, offsetY: 6))
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
            .accessibilityHint(appState.tr(.back))

            Button { appState.goForward() } label: {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(appState.navigation.historyForward.isEmpty)
            .opacity(appState.navigation.historyForward.isEmpty ? 0.4 : 1.0)
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
            searchTextField
            searchEverywhereToggle
            searchFilterMenu
            if !appState.selection.searchQuery.isEmpty {
                searchQueryActionButtons
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color(NSColor.controlBackgroundColor)).cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.6), lineWidth: 1.5))
    }

    private var searchTextField: some View {
        @Bindable var appState = appState
        return TextField("\(appState.tr(.searchPlaceholder)) \(appState.navigation.currentURL.lastPathComponent)...", text: $appState.selection.searchQuery)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focused($isSearchFocused)
            .onAppear {
                guard !appState.smartFolder.suppressNextSearchFocus else {
                    appState.smartFolder.suppressNextSearchFocus = false
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.searchFieldFocusDelay) {
                    isSearchFocused = true
                }
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
        }
        .buttonStyle(.plain)
        .help(appState.tr(.saveAsSmartFolder))
        .accessibilityLabel(appState.tr(.saveAsSmartFolder))
        .accessibilityHint(appState.tr(.saveAsSmartFolderHint))

        Button { appState.selection.searchQuery = "" } label: {
            Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
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
        appState.refreshCurrentDirectory()
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
            withAnimation { appState.toggleSearching() }
        } label: {
            Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .foregroundColor(appState.selection.isSearching ? .accentColor : .primary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain).help("\(appState.tr(.searchPlaceholder)) (Cmd+F)")
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
        .background(ClickOutsideDetector {
            if viewSwitcherExpanded {
                viewSwitcherExpanded = false
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
