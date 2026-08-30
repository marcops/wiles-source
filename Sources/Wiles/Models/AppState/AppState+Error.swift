import GitBeacon

public extension AppState {
    func showError(_ message: String) {
        modal.showError(message)
    }

    /// Prefer this over passing a raw `localizedDescription` string for errors that can come from
    /// `FileSystemService` operations: known `WilesError` cases get a real localized message via
    /// `appState.tr(...)` instead of surfacing an unlocalized system/English string.
    func showError(_ error: any Error) {
        showError(errorText(for: error))
    }

    /// Reports `error` to `ErrorReporter` for diagnostics AND surfaces it to the user — the
    /// report-then-show pair that a user-initiated action's `catch` almost always wants.
    func showError(_ error: any Error, context: String) {
        ErrorReporter.report(error, context: context)
        showError(error)
    }

    /// The user-facing string for any error: a `WilesError` is re-localized in the in-app language,
    /// anything else falls back to its `localizedDescription`. Same mapping `showError(_:)` uses —
    /// exposed so a view (e.g. `AsyncResultView`'s failure slot) can render it inline.
    func errorText(for error: any Error) -> String {
        if let wilesError = error as? WilesError {
            return wilesError.localizedMessage(lang: preferences.appearance.appLanguage)
        }
        return error.localizedDescription
    }

    func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: preferences.appearance.appLanguage)
    }

    /// One way to surface an "N of M failed" outcome from a bulk operation, so paste / trash /
    /// shred / tag / duplicate-clean don't each hand-roll `String(format:)` vs `WilesError.localized`.
    /// `key` is the operation's own `{0} of {1}` template.
    func showPartialFailure(_ key: L10n.Key, failed: Int, total: Int) {
        showError(WilesError.localized(key: key, arguments: ["\(failed)", "\(total)"]))
    }
}
