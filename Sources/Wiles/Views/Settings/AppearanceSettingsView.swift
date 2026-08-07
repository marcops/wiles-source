import SwiftUI

/// "Appearance" tab of `SettingsView`: theme and the sidebar/content translucency levels that used
/// to live nested three menus deep under the App menu's "Translucency" submenu.
struct AppearanceSettingsView: View {
    var appState: AppState

    /// The discrete translucency levels offered by the sidebar/content pickers below.
    private static let translucencyLevels = [0, 20, 40, 50, 60, 80, 100]

    var body: some View {
        @Bindable var appState = appState
        return Form {
            Section(appState.tr(.settingsThemeSection)) {
                Picker(appState.tr(.theme), selection: $appState.preferences.appAppearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appState.tr(appearance.l10nKey)).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(appState.tr(.settingsTranslucencySection)) {
                translucencyPicker(appState.tr(.sidebarTranslucentLevel), level: $appState.preferences.sidebarTranslucentLevel)
                translucencyPicker(appState.tr(.contentTranslucentLevel), level: $appState.preferences.contentTranslucentLevel)
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsAppearanceTab)))
    }

    private func translucencyPicker(_ title: String, level: Binding<Int>) -> some View {
        Picker(title, selection: level) {
            ForEach(Self.translucencyLevels, id: \.self) { value in
                Text("\(value)%").tag(value)
            }
        }
    }
}
