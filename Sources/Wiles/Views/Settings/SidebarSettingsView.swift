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
                Toggle(appState.tr(.showFavorites), isOn: $appState.preferences.sidebar.showFavorites)
                    .help(appState.tr(.showFavoritesHint))
                    .accessibilityHint(Text(appState.tr(.showFavoritesHint)))
                Toggle(appState.tr(.showPlaces), isOn: $appState.preferences.sidebar.showPlaces)
                    .help(appState.tr(.showPlacesHint))
                    .accessibilityHint(Text(appState.tr(.showPlacesHint)))
                Toggle(appState.tr(.showRecents), isOn: $appState.preferences.sidebar.showRecents)
                    .help(appState.tr(.showRecentsHint))
                    .accessibilityHint(Text(appState.tr(.showRecentsHint)))
                Toggle(appState.tr(.showNetworkAndCloud), isOn: $appState.preferences.sidebar.showNetworkAndCloud)
                    .help(appState.tr(.showNetworkAndCloudHint))
                    .accessibilityHint(Text(appState.tr(.showNetworkAndCloudHint)))
                Toggle(appState.tr(.showDirectoryTree), isOn: $appState.preferences.sidebar.showDirectoryTree)
                    .help(appState.tr(.showDirectoryTreeHint))
                    .accessibilityHint(Text(appState.tr(.showDirectoryTreeHint)))
                Toggle(appState.tr(.showSidebarSectionTitles), isOn: $appState.preferences.sidebar.showSidebarSectionTitles)
                    .help(appState.tr(.showSidebarSectionTitlesHint))
                    .accessibilityHint(Text(appState.tr(.showSidebarSectionTitlesHint)))
                Toggle(appState.tr(.showTags), isOn: $appState.preferences.sidebar.showTags)
                    .help(appState.tr(.showTagsHint))
                    .accessibilityHint(Text(appState.tr(.showTagsHint)))
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsSidebarTab)))
    }
}
