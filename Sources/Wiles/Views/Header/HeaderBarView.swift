import SwiftUI
import AppKit

struct HeaderBarView: View {
    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
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
        .background(
            // Spans the whole header row (search field + the search toggle button included) so
            // clicking the search button itself never counts as an "outside" click — it used to,
            // since this only wrapped the search field, racing the button's own toggle and making
            // a second click on the button re-open the search instead of closing it.
            Group {
                if appState.isSearching {
                    ClickOutsideDetector {
                        if appState.searchQuery.isEmpty {
                            withAnimation(MotionTokens.quickEase) {
                                appState.isSearching = false
                            }
                        }
                    }
                }
            }
        )
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
            if !appState.searchQuery.isEmpty {
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
        return TextField("\(appState.tr(.searchPlaceholder)) \(appState.navigation.currentURL.lastPathComponent)...", text: $appState.searchQuery)
            .textFieldStyle(.plain)
            .focused($isSearchFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.searchFieldFocusDelay) {
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
    }

    @ViewBuilder private var searchQueryActionButtons: some View {
        Button { windowUIState.showSaveSmartFolderSheet = true } label: {
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
    }

    @ViewBuilder private var searchFilterMenuContent: some View {
        @Bindable var appState = appState
        Picker(appState.tr(.searchScope), selection: $appState.preferences.searchScope) {
            Text(appState.tr(.searchByName)).tag(SearchScope.name)
            Text(appState.tr(.searchByContent)).tag(SearchScope.content)
        }
        Toggle(appState.tr(.searchIncludeHiddenFolders), isOn: includeHiddenFoldersBinding)
        Divider()
        dateFilterButtons
        Divider()
        kindFilterButtons
        Divider()
        Button(appState.tr(.filterLargeFiles)) {
            appState.searchQuery = "size:>100m"
            appState.refreshCurrentDirectory()
        }
    }

    @ViewBuilder private var dateFilterButtons: some View {
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
    }

    @ViewBuilder private var kindFilterButtons: some View {
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
    }

    /// Mirrors the `hidden:true` token in `appState.searchQuery` — same query-language convention
    /// as `date:`/`kind:`/`size:` used elsewhere in this menu, defaulting off (hidden folders are
    /// excluded from search unless explicitly requested).
    private var includeHiddenFoldersBinding: Binding<Bool> {
        Binding(
            get: { SearchFilterService.extractHiddenFlag(from: appState.searchQuery).includeHidden },
            set: { newValue in
                let (strippedQuery, _) = SearchFilterService.extractHiddenFlag(from: appState.searchQuery)
                if newValue {
                    appState.searchQuery = strippedQuery.isEmpty ? "hidden:true" : "\(strippedQuery) hidden:true"
                } else {
                    appState.searchQuery = strippedQuery
                }
            }
        )
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
                expandedViewModeButtons
            } else {
                collapsedViewModeButton
            }
        }
        .padding(2)
        .animation(MotionTokens.expandSpring, value: viewSwitcherExpanded)
        .background(ClickOutsideDetector {
            if viewSwitcherExpanded { viewSwitcherExpanded = false }
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
        .transition(.scale(scale: 0.7).combined(with: .opacity))
    }

}
