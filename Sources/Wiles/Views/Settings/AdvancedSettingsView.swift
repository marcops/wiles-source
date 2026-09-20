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
                Toggle(appState.tr(showHiddenFilesKey), isOn: $appState.preferences.view.showHiddenFiles)
                    .help(appState.tr(.showHiddenFilesHint))
                    .accessibilityHint(Text(appState.tr(.showHiddenFilesHint)))
                Toggle(appState.tr(.compactDensity), isOn: $appState.preferences.view.isCompactMode)
                    .help(appState.tr(.compactDensityHint))
                    .accessibilityHint(Text(appState.tr(.compactDensityHint)))
                Toggle(appState.tr(.middleTruncateNames), isOn: $appState.preferences.view.middleTruncateNames)
                    .help(appState.tr(.middleTruncateNamesHint))
                    .accessibilityHint(Text(appState.tr(.middleTruncateNamesHint)))
                Toggle(appState.tr(.alwaysShowFullPathBar), isOn: $appState.preferences.view.alwaysShowFullPathBar)
                    .help(appState.tr(.alwaysShowFullPathBarHint))
                    .accessibilityHint(Text(appState.tr(.alwaysShowFullPathBarHint)))
                Toggle(appState.tr(.autoHideSidebar), isOn: $appState.preferences.view.isSidebarCollapsed)
                    .help(appState.tr(.autoHideSidebarHint))
                    .accessibilityHint(Text(appState.tr(.autoHideSidebarHint)))
                Toggle(appState.tr(.perFolderViewMode), isOn: $appState.preferences.view.perFolderViewModeEnabled)
                    .help(appState.tr(.perFolderViewModeHint))
                    .accessibilityHint(Text(appState.tr(.perFolderViewModeHint)))
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

    /// Windows mode toggles hidden files with Ctrl+H, macOS mode with Cmd+Shift+. — the label
    /// communicates the currently-active shortcut for the currently-active navigation mode.
    /// `.toggleHiddenFiles` itself isn't one of Custom mode's mode-paired actions (same key in
    /// every mode), so this is purely cosmetic wording; Custom defaults to the Windows-flavored copy.
    private var showHiddenFilesKey: L10n.Key {
        appState.preferences.view.navigationMode == .macOS ? .showHiddenFilesMac : .showHiddenFilesWindows
    }
}
