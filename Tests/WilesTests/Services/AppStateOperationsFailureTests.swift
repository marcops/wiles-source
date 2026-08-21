import Foundation
@testable import Wiles

/// Continuation of `AppStateOperationsExtraTests` — split out purely to stay under SwiftLint's
/// 500-line file-length limit (see `AppStateNavigationExtraTests`/`AppStateColumnsAndActionsAsyncTests`
/// for the same precedent). Still the same dedicated suite for `AppState+Operations.swift`'s error
/// paths; `run()` here is called alongside the main file's `run()`.
extension AppStateOperationsExtraTests {
    static func runFailureTests() async {
        await testPerformDeleteSelectedFailureReportsError()
        await testDeletePermanentlySelectedFailureReportsError()
        await testShredSelectedFailureReportsError()
        await testUndoLastActionFailureReportsError()
        await testRedoLastActionFailureReportsError()
    }

    private static func testPerformDeleteSelectedFailureReportsError() async {
        let errorShown = await expectErrorFromReadOnlyParent(fileName: "locked.txt") { $0.performDeleteSelected() }
        report(
            "AppState+Operations",
            "NEG: performDeleteSelected() reports an error when moveToTrash fails (read-only parent directory)",
            result: errorShown)
    }

    private static func testDeletePermanentlySelectedFailureReportsError() async {
        let errorShown = await expectErrorFromReadOnlyParent(fileName: "locked-permanent.txt") { $0.deletePermanentlySelected() }
        report(
            "AppState+Operations",
            "NEG: deletePermanentlySelected() reports an error when fm.removeItem fails (read-only parent directory)",
            result: errorShown)
    }

    private static func testShredSelectedFailureReportsError() async {
        let errorShown = await expectErrorFromReadOnlyParent(fileName: "locked-shred.txt") { $0.shredSelected() }
        report(
            "AppState+Operations",
            "NEG: shredSelected() reports an error when fm.removeItem fails (read-only parent directory)",
            result: errorShown)
    }

    /// undo()'s catch: a .create record for a never-created URL makes moveToTrash() throw;
    /// materialize the path afterward before draining (failed records go back onto undoStack).
    private static func testUndoLastActionFailureReportsError() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let neverCreatedURL = dir.appendingPathComponent("never-created-\(UUID().uuidString)")

        let appState = AppState()
        appState.undoRedoService.recordAction(.create(url: neverCreatedURL))
        appState.modal.errorMessage = nil
        appState.selectedURLs = []
        appState.undoLastAction()
        let errorShown = await pollUntilTrue { appState.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: undoLastAction() reports an error when the reverse action fails (moveToTrash on a URL that was never created)",
            result: errorShown)

        try? FileManager.default.createDirectory(at: neverCreatedURL, withIntermediateDirectories: true)
        await drainUndoRedoService(appState)
    }

    /// redo()'s catch: get a record onto redoStack via undo(), then make the forward createDirectory
    /// fail by recreating that path first; retry redo() after clearing the conflict so the failed
    /// record (pushed back onto redoStack, unreachable by drainUndoRedoService()) drains too. Uses a
    /// single `appState` throughout — undo()/redo() must run against the exact instance that
    /// recorded the action, since each `AppState` now owns its own `undoRedoService`.
    private static func testRedoLastActionFailureReportsError() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let createdDirURL = dir.appendingPathComponent("redo-fail-dir")
        try? FileManager.default.createDirectory(at: createdDirURL, withIntermediateDirectories: true)

        let appState = AppState()
        appState.undoRedoService.recordAction(.create(url: createdDirURL))
        appState.selectedURLs = []
        appState.undoLastAction()
        let trashedAway = await pollUntilTrue { !FileManager.default.fileExists(atPath: createdDirURL.path) }
        guard trashedAway else {
            report("AppState+Operations", "NEG: redoLastAction() reports an error when the forward action fails (setup: undo did not complete)", result: false)
            return
        }
        try? FileManager.default.createDirectory(at: createdDirURL, withIntermediateDirectories: true)

        appState.modal.errorMessage = nil
        appState.redoLastAction()
        let errorShown = await pollUntilTrue { appState.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: redoLastAction() reports an error when the forward action fails (createDirectory on a path that already exists)",
            result: errorShown)

        try? FileManager.default.removeItem(at: createdDirURL)
        _ = try? await appState.undoRedoService.redo()
        await drainUndoRedoService(appState)
    }
}
