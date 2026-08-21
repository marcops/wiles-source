import SwiftUI

/// Everyday, frequently-toggled panels/actions stay here for quick keyboard access. Lower-
/// frequency display preferences (hidden files, tags, compact density, sidebar sections/mode)
/// moved into the `Settings` scene (⌘,) — see `Views/Settings/*.swift` — to declutter the menu bar
/// per the redesign; those bindings still live on the same `PreferencesStore`, so toggling them in
/// Settings updates the UI live with zero behavior change.
///
/// Split out of `WilesApp.swift` — pure code motion, no behavior change.
struct ViewMenuCommands: Commands {
    let sharedPreferences: PreferencesStore

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            sidebarViewMenuItems
        }
    }

    @ViewBuilder private var sidebarViewMenuItems: some View {
        @Bindable var sharedPreferences = sharedPreferences
        Divider()
        Toggle(tr(sharedPreferences.showTerminalDrawer ? .hideTerminal : .showTerminal), isOn: $sharedPreferences.showTerminalDrawer)
            .keyboardShortcut("j", modifiers: .command)
        Toggle(tr(sharedPreferences.showPreviewSidebar ? .hidePreview : .showPreviewSidebar), isOn: $sharedPreferences.showPreviewSidebar)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        Toggle(
            tr(sharedPreferences.showDiskUsageSidebar ? .hideDiskUsageSidebar : .showDiskUsageSidebar),
            isOn: $sharedPreferences.showDiskUsageSidebar)
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Menu(tr(.sidebarMenuTitle)) {
            Toggle(tr(.showFavorites), isOn: $sharedPreferences.showFavorites)
            Toggle(tr(.showPlaces), isOn: $sharedPreferences.showPlaces)
            Toggle(tr(.showRecents), isOn: $sharedPreferences.showRecents)
            Toggle(tr(.showNetworkAndCloud), isOn: $sharedPreferences.showNetworkAndCloud)
            Toggle(tr(.showDirectoryTree), isOn: $sharedPreferences.showDirectoryTree)
            Toggle(tr(.showSidebarSectionTitles), isOn: $sharedPreferences.showSidebarSectionTitles)
            Toggle(tr(.showTags), isOn: $sharedPreferences.showTags)
        }
        Divider()
        Picker(selection: $sharedPreferences.viewMode) {
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
