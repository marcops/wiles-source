import SwiftUI

/// "Sidebar" tab of `SettingsView`: which sidebar sections are visible — previously five separate
/// `Toggle`/`Picker` rows buried in the View menu (`viewMenuCommands` in `WilesApp.swift`). The
/// Directory Tree used to be a mutually-exclusive alternative to the Places list (a `SidebarMode`
/// picker); it's now just another independent section toggle like the rest, so Places and the
/// Directory Tree can both be shown at once.
struct SidebarSettingsView: View {
    var appState: AppState

    var body: some View {
        @Bindable var appState = appState
        return Form {
            Section(appState.tr(.settingsSidebarSectionsSection)) {
                Toggle(appState.tr(.showFavorites), isOn: $appState.preferences.showFavorites)
                Toggle(appState.tr(.showPlaces), isOn: $appState.preferences.showPlaces)
                Toggle(appState.tr(.showRecents), isOn: $appState.preferences.showRecents)
                Toggle(appState.tr(.showNetworkAndCloud), isOn: $appState.preferences.showNetworkAndCloud)
                Toggle(appState.tr(.showDirectoryTree), isOn: $appState.preferences.showDirectoryTree)
                Toggle(appState.tr(.showSidebarSectionTitles), isOn: $appState.preferences.showSidebarSectionTitles)
                Toggle(appState.tr(.showTags), isOn: $appState.preferences.showTags)
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsSidebarTab)))
    }
}
