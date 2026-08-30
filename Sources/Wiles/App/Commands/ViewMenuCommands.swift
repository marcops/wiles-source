import SwiftUI

/// Everyday, frequently-toggled panels/actions stay here for quick keyboard access. Lower-
/// frequency display preferences (hidden files, tags, compact density, sidebar sections/mode)
/// moved into the `Settings` scene (⌘,) — see `Views/Settings/*.swift` — to declutter the menu bar
/// per the redesign; those bindings still live on the same `PreferencesStore`, so toggling them in
/// Settings updates the UI live with zero behavior change.
///
/// Split out of `WilesApp.swift` — pure code motion, no behavior change.
struct ViewMenuCommands: LocalizedCommands {
    let sharedPreferences: PreferencesStore

    @FocusedValue(\.windowUIState)
    private var windowUIState
    @FocusedValue(\.appState)
    private var appState

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            sidebarViewMenuItems
        }
    }

    /// Binds through the focused window's `WindowUIState` (falling back to a static `false` when no
    /// window is focused) since terminal/preview/disk-usage visibility is per-window, not shared.
    private func windowUIStateBinding(_ keyPath: ReferenceWritableKeyPath<WindowUIState, Bool>) -> Binding<Bool> {
        Binding(
            get: { windowUIState?[keyPath: keyPath] ?? false },
            set: { windowUIState?[keyPath: keyPath] = $0 })
    }

    /// Toggle binding for a trailing inspector: on → that inspector, off → none.
    private func inspectorBinding(_ kind: TrailingInspector) -> Binding<Bool> {
        Binding(
            get: { windowUIState?.trailingInspector == kind },
            set: { windowUIState?.trailingInspector = $0 ? kind : .none })
    }

    /// Falls back to the shared global `viewMode` when no window is focused.
    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { appState?.currentViewMode ?? sharedPreferences.view.viewMode },
            set: { newValue in
                if let appState {
                    appState.setViewModeForFolder(newValue, for: appState.navigation.currentURL)
                } else {
                    sharedPreferences.view.viewMode = newValue
                }
            })
    }

    @ViewBuilder private var sidebarViewMenuItems: some View {
        @Bindable var sharedPreferences = sharedPreferences
        Divider()
        Toggle(
            tr(windowUIState?.showTerminalDrawer ?? false ? .hideTerminal : .showTerminal),
            isOn: windowUIStateBinding(\.showTerminalDrawer))
            .keyboardShortcut(.toggleTerminal)
        Toggle(
            tr(windowUIState?.trailingInspector == .preview ? .hidePreview : .showPreviewSidebar),
            isOn: inspectorBinding(.preview))
            .keyboardShortcut(.togglePreview)
        Toggle(
            tr(windowUIState?.trailingInspector == .diskUsage ? .hideDiskUsageSidebar : .showDiskUsageSidebar),
            isOn: inspectorBinding(.diskUsage))
            .keyboardShortcut(.toggleDiskUsage)
        Menu(tr(.sidebarMenuTitle)) {
            Toggle(tr(.showFavorites), isOn: $sharedPreferences.sidebar.showFavorites)
            Toggle(tr(.showPlaces), isOn: $sharedPreferences.sidebar.showPlaces)
            Toggle(tr(.showRecents), isOn: $sharedPreferences.sidebar.showRecents)
            Toggle(tr(.showNetworkAndCloud), isOn: $sharedPreferences.sidebar.showNetworkAndCloud)
            Toggle(tr(.showDirectoryTree), isOn: $sharedPreferences.sidebar.showDirectoryTree)
            Toggle(tr(.showSidebarSectionTitles), isOn: $sharedPreferences.sidebar.showSidebarSectionTitles)
            Toggle(tr(.showTags), isOn: $sharedPreferences.sidebar.showTags)
            Divider()
            Toggle(tr(.autoHideSidebar), isOn: $sharedPreferences.view.isSidebarCollapsed)
        }
        Divider()
        Picker(selection: viewModeBinding) {
            Text(tr(.gridView)).tag(ViewMode.grid)
            Text(tr(.listView)).tag(ViewMode.list)
        } label: {
            Label(tr(.viewMode), systemImage: "square.grid.2x2")
        }
        Menu {
            Picker(tr(.sortBy), selection: $sharedPreferences.view.sortOption) {
                ForEach(SortOption.allCases) { opt in Text(tr(opt.l10nKey)).tag(opt) }
            }
            Divider()
            Toggle(tr(.ascending), isOn: $sharedPreferences.view.sortAscending)
        } label: {
            Label(tr(.sortBy), systemImage: "arrow.up.arrow.down")
        }
    }
}
