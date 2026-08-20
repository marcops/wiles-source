import SwiftUI

/// "General" tab of `SettingsView`: language and everyday behavior toggles that used to live in
/// the App menu (`appMenuCommands` in `WilesApp.swift`).
struct GeneralSettingsView: View {
    var appState: AppState

    var body: some View {
        @Bindable var appState = appState
        return Form {
            Section(appState.tr(.settingsLanguageSection)) {
                Picker(appState.tr(.language), selection: $appState.preferences.appLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(appState.tr(.settingsBehaviorSection)) {
                Picker(appState.tr(.shortcutMode), selection: $appState.preferences.navigationMode) {
                    ForEach(NavigationMode.allCases) { mode in
                        Text(appState.tr(mode.l10nKey)).tag(mode)
                    }
                }
                Toggle(appState.tr(.skipDeleteConfirmation), isOn: $appState.preferences.skipDeleteConfirmation)
                    .help(appState.tr(.skipDeleteConfirmationHint))
                    .accessibilityHint(Text(appState.tr(.skipDeleteConfirmationHint)))
            }
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsGeneralTab)))
    }
}
