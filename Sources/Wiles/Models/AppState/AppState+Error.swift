public extension AppState {
    func showError(_ message: String) {
        modal.showError(message)
    }

    /// Prefer this over `showError(error.localizedDescription)` for errors that can come from
    /// `FileSystemService` operations: known `WilesError` cases get a real localized message via
    /// `appState.tr(...)` instead of surfacing an unlocalized system/English string.
    func showError(_ error: any Error) {
        showError(errorText(for: error))
    }

    /// The user-facing string for any error: a `WilesError` is re-localized in the in-app language,
    /// anything else falls back to its `localizedDescription`. Same mapping `showError(_:)` uses —
    /// exposed so a view (e.g. `AsyncResultView`'s failure slot) can render it inline.
    func errorText(for error: any Error) -> String {
        if let wilesError = error as? WilesError {
            return wilesError.localizedMessage(lang: preferences.appLanguage)
        }
        return error.localizedDescription
    }

    func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: preferences.appLanguage)
    }
}
