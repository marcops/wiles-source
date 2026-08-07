import SwiftUI

/// Root of the native `Settings { }` scene (`⌘,`). Groups every preference that used to live
/// scattered across the menu bar (`WilesApp.swift`'s `appMenuCommands`/`viewMenuCommands`) into a
/// single tabbed window, following macOS System Settings / HIG conventions.
struct SettingsView: View {
    var appState: AppState

    private enum Tab: Hashable {
        case general, appearance, sidebar, advanced
    }

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem { Label(appState.tr(.settingsGeneralTab), systemImage: "gearshape") }
                .tag(Tab.general)

            AppearanceSettingsView(appState: appState)
                .tabItem { Label(appState.tr(.settingsAppearanceTab), systemImage: "paintbrush") }
                .tag(Tab.appearance)

            SidebarSettingsView(appState: appState)
                .tabItem { Label(appState.tr(.settingsSidebarTab), systemImage: "sidebar.left") }
                .tag(Tab.sidebar)

            AdvancedSettingsView(appState: appState)
                .tabItem { Label(appState.tr(.settingsAdvancedTab), systemImage: "slider.horizontal.3") }
                .tag(Tab.advanced)
        }
        .frame(width: 480, height: 360)
        .navigationTitle(appState.tr(.settingsWindowTitle))
    }
}
