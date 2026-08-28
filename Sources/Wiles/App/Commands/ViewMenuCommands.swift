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

    /// Falls back to the shared global `viewMode` when no window is focused.
    private var viewModeBinding: Binding<ViewMode> {
        Binding(
            get: { appState?.currentViewMode ?? sharedPreferences.viewMode },
            set: { newValue in
                if let appState {
                    appState.setViewModeForFolder(newValue, for: appState.navigation.currentURL)
                } else {
                    sharedPreferences.viewMode = newValue
                }
            })
    }

    @ViewBuilder private var sidebarViewMenuItems: some View {
        @Bindable var sharedPreferences = sharedPreferences
        Divider()
        Toggle(
            tr(windowUIState?.showTerminalDrawer ?? false ? .hideTerminal : .showTerminal),
            isOn: windowUIStateBinding(\.showTerminalDrawer))
            .keyboardShortcut("j", modifiers: .command)
        Toggle(
            tr(windowUIState?.showPreviewSidebar ?? false ? .hidePreview : .showPreviewSidebar),
            isOn: windowUIStateBinding(\.showPreviewSidebar))
            .keyboardShortcut("p", modifiers: [.command, .shift])
        Toggle(
            tr(windowUIState?.showDiskUsageSidebar ?? false ? .hideDiskUsageSidebar : .showDiskUsageSidebar),
            isOn: windowUIStateBinding(\.showDiskUsageSidebar))
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Menu(tr(.sidebarMenuTitle)) {
            Toggle(tr(.showFavorites), isOn: $sharedPreferences.showFavorites)
            Toggle(tr(.showPlaces), isOn: $sharedPreferences.showPlaces)
            Toggle(tr(.showRecents), isOn: $sharedPreferences.showRecents)
            Toggle(tr(.showNetworkAndCloud), isOn: $sharedPreferences.showNetworkAndCloud)
            Toggle(tr(.showDirectoryTree), isOn: $sharedPreferences.showDirectoryTree)
            Toggle(tr(.showSidebarSectionTitles), isOn: $sharedPreferences.showSidebarSectionTitles)
            Toggle(tr(.showTags), isOn: $sharedPreferences.showTags)
            Divider()
            Toggle(tr(.autoHideSidebar), isOn: $sharedPreferences.isSidebarCollapsed)
        }
        Divider()
        Picker(selection: viewModeBinding) {
            Text(tr(.gridView)).tag(ViewMode.grid)
            Text(tr(.listView)).tag(ViewMode.list)
        } label: {
            Label(tr(.viewMode), systemImage: "square.grid.2x2")
        }
        Menu {
            Picker(tr(.sortBy), selection: $sharedPreferences.sortOption) {
                ForEach(SortOption.allCases) { opt in Text(tr(opt.l10nKey)).tag(opt) }
            }
            Divider()
            Toggle(tr(.ascending), isOn: $sharedPreferences.sortAscending)
        } label: {
            Label(tr(.sortBy), systemImage: "arrow.up.arrow.down")
        }
    }
}
