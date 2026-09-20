import SwiftUI

/// "General" tab of `SettingsView`: language and everyday behavior toggles that used to live in
/// the App menu (`appMenuCommands` in `WilesApp.swift`).
struct GeneralSettingsView: View {
    var appState: AppState

    var body: some View {
        @Bindable var appState = appState
        return Form {
            Section(appState.tr(.settingsLanguageSection)) {
                Picker(appState.tr(.language), selection: $appState.preferences.appearance.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName(in: appState.preferences.appearance.appLanguage)).tag(lang)
                    }
                }
            }

            Section(appState.tr(.settingsBehaviorSection)) {
                Toggle(appState.tr(.skipDeleteConfirmation), isOn: $appState.preferences.view.skipDeleteConfirmation)
                    .help(appState.tr(.skipDeleteConfirmationHint))
                    .accessibilityHint(Text(appState.tr(.skipDeleteConfirmationHint)))
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsGeneralTab)))
    }
}
