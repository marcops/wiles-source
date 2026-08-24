public extension AppState {
    func showError(_ message: String) {
        modal.showError(message)
    }

    /// Prefer this over `showError(error.localizedDescription)` for errors that can come from
    /// `FileSystemService` operations: known `WilesError` cases get a real localized message via
    /// `appState.tr(...)` instead of surfacing an unlocalized system/English string.
    func showError(_ error: any Error) {
        if let wilesError = error as? WilesError {
            showError(wilesError.localizedMessage(lang: preferences.appLanguage))
        } else {
            showError(error.localizedDescription)
        }
    }

    func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: preferences.appLanguage)
    }
}
