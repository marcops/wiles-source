import SwiftUI

/// "Sidebar" tab of `SettingsView`: which sidebar sections are visible and whether it displays as
/// a flat Places list or a full Directory Tree — previously five separate `Toggle`/`Picker` rows
/// buried in the View menu (`viewMenuCommands` in `WilesApp.swift`).
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
                Toggle(appState.tr(.showSidebarSectionTitles), isOn: $appState.preferences.showSidebarSectionTitles)
            }

            Section(appState.tr(.settingsSidebarDisplaySection)) {
                Picker(appState.tr(.sidebarMode), selection: $appState.preferences.sidebarMode) {
                    ForEach(SidebarMode.allCases) { mode in
                        Text(appState.tr(mode.menuL10nKey)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsSidebarTab)))
    }
}
