import SwiftUI

/// "Advanced" tab of `SettingsView`: lower-frequency display toggles (hidden files,
/// compact row density) that used to be plain `Toggle`s scattered in the View menu
/// (`viewMenuCommands` in `WilesApp.swift`).
struct AdvancedSettingsView: View {
    var appState: AppState
    @State private var registrationStatus: String?

    var body: some View {
        @Bindable var appState = appState
        return Form {
            Section(appState.tr(.settingsViewSection)) {
                Toggle(appState.tr(showHiddenFilesKey), isOn: $appState.preferences.showHiddenFiles)
                    .onChange(of: appState.preferences.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
                Toggle(appState.tr(.compactDensity), isOn: $appState.isCompactMode)
                Toggle(appState.tr(.middleTruncateNames), isOn: $appState.preferences.middleTruncateNames)
                Toggle(appState.tr(.alwaysShowFullPathBar), isOn: $appState.preferences.alwaysShowFullPathBar)
            }

            defaultAppSection
        }
        .formStyle(.grouped)
        .accessibilityLabel(Text(appState.tr(.settingsAdvancedTab)))
    }

    private var defaultAppSection: some View {
        Section(appState.tr(.settingsDefaultAppSection)) {
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.tr(.defaultAppExplanation))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(appState.tr(.defaultAppRegisterButton)) {
                    DefaultFolderHandlerService.registerAsFolderHandlerOption { success in
                        Task { @MainActor in
                            registrationStatus = appState.tr(success ? .defaultAppRegisteredConfirmation : .defaultAppRegistrationFailed)
                        }
                    }
                }
                .accessibilityLabel(appState.tr(.defaultAppRegisterButton))
                .accessibilityHint(appState.tr(.defaultAppExplanation))
                if let registrationStatus {
                    Text(registrationStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// GNOME mode toggles hidden files with Ctrl+H, macOS mode with Cmd+Shift+. — the label
    /// communicates the currently-active shortcut for the currently-active navigation mode.
    private var showHiddenFilesKey: L10n.Key {
        appState.navigationMode == .gnome ? .showHiddenFilesGnome : .showHiddenFilesMac
    }
}
