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

    /// The "Large files" quick filter's search token — files bigger than this size.
    private static let largeFileFilterToken = "size:>100m"

    var appState: AppState
    @Environment(WindowUIState.self)
    private var windowUIState
    @FocusState private var isSearchFocused: Bool
    @State private var viewSwitcherExpanded = false

    var body: some View {
        HStack(spacing: 12) {
            historyButtons
            headerCenter.frame(maxWidth: .infinity)
            rightControls
        }
        .padding(.leading, sidebarProvidesSafeLeadingInset ? Self.defaultLeadingInset : Self.trafficLightsSafeLeadingInset)
        .padding(.trailing, Self.rightControlsTrailingInset)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(TrafficLightRepositioner())
        .background(
            // Spans the whole header row (search field + the search toggle button included) so
            // clicking the search button itself never counts as an "outside" click — it used to,
            // since this only wrapped the search field, racing the button's own toggle and making
            // a second click on the button re-open the search instead of closing it.
            Group {
                if appState.selection.isSearching {
                    ClickOutsideDetector {
                        // Editing an active smart folder's query: clicking away saves the edit back
                        // to the folder (same persistence the sidebar's "Update Search" menu item
                        // already uses) and collapses the field back to its name pill, rather than
                        // leaving the raw query exposed or requiring the manual menu item.
                        if windowUIState.isEditingSearch, let activeSmartFolder {
                            let trimmedQuery = appState.selection.searchQuery.trimmingCharacters(in: .whitespaces)
                            if !trimmedQuery.isEmpty {
                                appState.updateSmartFolderQuery(activeSmartFolder, to: appState.selection.searchQuery)
                            }
                            withAnimation(MotionTokens.quickEase) {
                                windowUIState.isEditingSearch = false
                            }
                        } else if appState.selection.searchQuery.isEmpty {
                            withAnimation(MotionTokens.quickEase) {
                                appState.selection.isSearching = false
                            }
                        }
                    }
                }
            })
        .doubleClickToZoom()
        // `isEditingSearch` is a transient "the field is open for typing" flag — it must not
        // outlive the search itself or a later smart-folder/tag activation would still render the
        // raw editable field instead of its name pill. Mirrors how `PathBarView` self-clears
        // `isEditingPath`.
        .onChange(of: appState.selection.isSearching) { _, searching in
            if !searching {
                windowUIState.isEditingSearch = false
            }
        }
        .onChange(of: appState.navigation.currentURL) { _, _ in
            windowUIState.isEditingSearch = false
        }
    }

    @ViewBuilder private var headerCenter: some View {
        switch headerCenterMode {
        case .breadcrumb:
            PathBarView(appState: appState)
        case .editableSearch:
            searchField
        case let .tagPill(tag):
            // No click-to-edit for a tag pill: a tag filter is refined only from the sidebar.
            let tagColor = SystemTagsService.color(forTagNamed: tag)
            searchContextPill {
                Circle()
                    .fill(tagColor?.displayColor ?? .secondary)
                    .frame(width: 10, height: 10)
                Text(tagColor.map { appState.tr($0.l10nKey) } ?? tag).font(.system(size: 12, weight: .medium))
            }
        case let .smartFolderPill(name):
            searchContextPill {
                Image(systemName: activeSmartFolder?.icon ?? "folder.badge.gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)
                Text(name).font(.system(size: 12, weight: .medium)).lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.smartFolder.suppressNextSearchFocus = false
                windowUIState.isEditingSearch = true
            }
        }
    }

    private var headerCenterMode: HeaderCenterMode {
        HeaderCenterMode.resolve(
            isSearching: appState.selection.isSearching,
            isEditingSearch: windowUIState.isEditingSearch,
            activeSmartFolderName: activeSmartFolder?.name,
            searchQuery: appState.selection.searchQuery)
    }

    private var activeSmartFolder: SmartFolder? {
        guard let id = appState.smartFolder.activeFolderID else { return nil }
        return appState.preferences.smartFolders.first { $0.id == id }
    }

    /// Non-editable name shown in the path-bar slot for a nameable search context. Styled like a
    /// `PathBarView` breadcrumb segment — no field chrome — so it reads as "where you are", not an
    /// input.
    private func searchContextPill(@ViewBuilder _ content: () -> some View) -> some View {
        HStack(spacing: 6) { content() }
            .foregroundColor(.primary)
            .padding(.horizontal, 6)
            .frame(height: 28)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// False whenever the sidebar isn't reserving enough leading width to clear the repositioned
    /// traffic-light buttons — fully hidden, or collapsed to its icon-only rail and not peeking.
    private var sidebarProvidesSafeLeadingInset: Bool {
        guard appState.hasVisibleSidebarContent else { return false }
        return !appState.preferences.view.isSidebarCollapsed || windowUIState.isSidebarPeeking
    }

    private var historyButtons: some View {
        HStack(spacing: 4) {
            TappableRow(
                accessibilityLabel: appState.tr(.back),
                isDisabled: appState.navigation.historyBack.isEmpty,
                action: { appState.goBack() },
                content: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                })
                .opacity(appState.navigation.historyBack.isEmpty ? 0.4 : 1.0)
                .help(appState.tr(.back))

            TappableRow(
                accessibilityLabel: appState.tr(.forward),
                isDisabled: appState.navigation.historyForward.isEmpty,
                action: { appState.goForward() },
                content: {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                })
                .opacity(appState.navigation.historyForward.isEmpty ? 0.4 : 1.0)
                .help(appState.tr(.forward))
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
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                searchTextField
                searchEverywhereToggle
                searchFilterMenu
                if !appState.selection.searchQuery.isEmpty {
                    searchQueryActionButtons
                }
            }
            .headerFieldChrome()
            if isContentSearchScope {
                Text(appState.tr(.contentSearchHint))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    /// The search-thresholds hint only makes sense when content is actually being searched.
    private var isContentSearchScope: Bool {
        appState.preferences.search.searchScope == .content || appState.preferences.search.searchScope == .both
    }

    private var searchTextField: some View {
        @Bindable var appState = appState
        return TextField("\(appState.tr(.searchPlaceholder)) \(appState.navigation.currentURL.lastPathComponent)...", text: $appState.selection.searchQuery)
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .focused($isSearchFocused)
            .accessibilityIdentifier("SearchTextField")
            .task {
                guard !appState.smartFolder.suppressNextSearchFocus else {
                    appState.smartFolder.suppressNextSearchFocus = false
                    return
                }
                try? await Task.sleep(for: AsyncDelayTokens.searchFieldFocusDelay)
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

    private var searchQueryActionButtons: some View {
        TappableRow(
            accessibilityLabel: appState.tr(.saveAsSmartFolder),
            accessibilityHint: appState.tr(.saveAsSmartFolderHint),
            action: { windowUIState.activeModal = .saveSmartFolder },
            content: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(.accentColor)
                    .frame(width: 20, height: 20)
            })
            .help(appState.tr(.saveAsSmartFolder))
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
        Picker(appState.tr(.searchScope), selection: $appState.preferences.search.searchScope) {
            Text(appState.tr(.searchByName)).tag(SearchScope.name)
            Text(appState.tr(.searchByContent)).tag(SearchScope.content)
            Text(appState.tr(.searchByBoth)).tag(SearchScope.both)
        }
        Toggle(appState.tr(.searchCaseSensitive), isOn: $appState.preferences.search.searchCaseSensitive)
        Toggle(appState.tr(.searchIncludeHiddenFolders), isOn: includeHiddenFoldersBinding)
        Divider()
        dateFilterButtons
        Divider()
        kindFilterButtons
        Divider()
        quickFilterButton(.filterLargeFiles, token: Self.largeFileFilterToken)
    }

    /// Toggles a quick-filter token (e.g. `date:today`, `kind:image`) in/out of the current search
    /// query — appended if absent, stripped if present — preserving any free text the user typed,
    /// and shows a checkmark while the token is active. Pass `exclusiveGroupPrefix` (`kind:`, `date:`)
    /// so activating one token in that group replaces the others instead of ANDing with them.
    @ViewBuilder
    private func quickFilterButton(_ titleKey: L10n.Key, token: String, exclusiveGroupPrefix: String? = nil) -> some View {
        let isActive = SearchFilterService.containsToken(token, in: appState.selection.searchQuery)
        Button {
            let query = appState.selection.searchQuery
            appState.selection.searchQuery = if let exclusiveGroupPrefix {
                SearchFilterService.toggleExclusiveToken(token, groupPrefix: exclusiveGroupPrefix, in: query)
            } else {
                SearchFilterService.toggleToken(token, in: query)
            }
        } label: {
            if isActive {
                Label(appState.tr(titleKey), systemImage: "checkmark")
            } else {
                Text(appState.tr(titleKey))
            }
        }
    }

    @ViewBuilder private var dateFilterButtons: some View {
        quickFilterButton(.filterModifiedToday, token: "date:today", exclusiveGroupPrefix: "date:")
        quickFilterButton(.filterModified7Days, token: "date:7d", exclusiveGroupPrefix: "date:")
        quickFilterButton(.filterModified30Days, token: "date:30d", exclusiveGroupPrefix: "date:")
    }

    @ViewBuilder private var kindFilterButtons: some View {
        quickFilterButton(.filterImages, token: "kind:image", exclusiveGroupPrefix: "kind:")
        quickFilterButton(.filterDocuments, token: "kind:doc", exclusiveGroupPrefix: "kind:")
        quickFilterButton(.filterCodeFiles, token: "kind:code", exclusiveGroupPrefix: "kind:")
        quickFilterButton(.filterPDFs, token: "kind:pdf", exclusiveGroupPrefix: "kind:")
        quickFilterButton(.filterFolders, token: "kind:folder", exclusiveGroupPrefix: "kind:")
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
        TappableRow(
            accessibilityLabel: appState.tr(.actSearch),
            accessibilityHint: appState.tr(.find),
            action: { withAnimation(MotionTokens.quickEase) { appState.toggleSearching(windowUIState: windowUIState) } },
            content: {
                Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .medium))
                    .frame(width: 30, height: 28)
                    .foregroundColor(appState.selection.isSearching ? .accentColor : .primary)
            })
            .help(appState.trWithShortcutHint(.actSearch, shortcut: ShortcutRegistry.label(.find)))
    }

    private var searchEverywhereToggle: some View {
        @Bindable var appState = appState
        return TappableRow(
            accessibilityLabel: appState.tr(.searchEverywhere),
            accessibilityHint: appState.tr(.searchEverywhereHelp),
            isSelected: appState.preferences.search.searchEverywhere,
            // The refresh is driven by `MainContentView`'s `.onChange(of: searchEverywhere)`, so it
            // also fires when the toggle is flipped from Settings, not just from here.
            action: { appState.preferences.search.searchEverywhere.toggle() },
            content: {
                Text(appState.tr(.searchEverywhere)).font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .frame(height: 22)
                    .foregroundColor(appState.preferences.search.searchEverywhere ? .white : .primary)
                    .background(appState.preferences.search.searchEverywhere ? Color.accentColor : Color(NSColor.controlColor))
                    .cornerRadius(5)
            })
            .help(appState.tr(.searchEverywhereHelp))
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
            TappableRow(
                accessibilityLabel: accessibilityLabel(for: mode),
                accessibilityHint: appState.tr(.viewMode),
                isSelected: appState.currentViewMode == mode,
                action: {
                    withAnimation(MotionTokens.snappySpring) {
                        appState.setViewModeForFolder(mode, for: appState.navigation.currentURL)
                        viewSwitcherExpanded = false
                    }
                },
                content: {
                    Image(systemName: iconName(for: mode)).font(.system(size: 12))
                        .frame(width: 26, height: 24)
                        .background(appState.currentViewMode == mode ? Color.accentColor : Color.clear)
                        .foregroundColor(appState.currentViewMode == mode ? .white : .primary)
                        .cornerRadius(4)
                })
                .accessibilityIdentifier(accessibilityID(for: mode))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        }
    }

    private var collapsedViewModeButton: some View {
        TappableRow(
            accessibilityLabel: accessibilityLabel(for: appState.currentViewMode),
            accessibilityHint: appState.tr(.viewMode),
            action: { withAnimation(MotionTokens.snappySpring) { viewSwitcherExpanded = true } },
            content: {
                Image(systemName: iconName(for: appState.currentViewMode)).font(.system(size: 12))
                    .frame(width: 26, height: 24)
                    .background(Color.clear)
                    .foregroundColor(.primary)
                    .cornerRadius(4)
            })
            .accessibilityIdentifier("View Mode")
            .transition(.scale(scale: 0.7).combined(with: .opacity))
    }
}
