@testable import Wiles
import Foundation

/// Continuation of `AppStateCoreTests` — split out purely to stay under SwiftLint's 500-line
/// file-length limit (see `AppStateOperationsExtraTests`/`AppStateOperationsFailureTests` for the
/// same precedent). Still the same dedicated suite for `AppState.swift`; `run()` here is called
/// alongside the main file's `run()`.
@MainActor
public struct AppStateCoreExtraTests {
    public static func run() {
        testShowErrorWithErrorType()
    }

    // Regression coverage for the "moved a folder to the folder it's already in" bug report,
    // where the raw NSError message was shown untranslated to every user regardless of language.
    private static func testShowErrorWithErrorType() {
        let appState = AppState()

        appState.modal.errorMessage = nil
        appState.showError(WilesError.itemAlreadyInDestination)
        TestReporter.report(
            "AppState",
            "POS: showError(Error) localizes WilesError.itemAlreadyInDestination via appState.tr(...)",
            result: appState.modal.errorMessage == appState.tr(.itemAlreadyInDestination)
        )

        appState.modal.errorMessage = nil
        struct SomeOtherError: LocalizedError { var errorDescription: String? { "some other failure" } }
        appState.showError(SomeOtherError())
        TestReporter.report(
            "AppState",
            "NEG: showError(Error) falls back to localizedDescription for a non-WilesError",
            result: appState.modal.errorMessage == "some other failure"
        )
    }
}
