import Foundation
@testable import Wiles

/// Coverage notes for `AppState+Trash.swift`:
///
/// - `performEmptyTrash()` and the private `removeTrashContents(_:using:)` it calls operate directly
///   on the real `~/.Trash` via `FileManager.default` with no injectable seam (no trash-directory
///   parameter, no `FileManager` protocol abstraction). There is no way to exercise them here without
///   actually deleting whatever is in the developer's or CI runner's real Trash, which is exactly the
///   kind of real-user-persistence mutation "Strict Test Isolation & Zero Side-Effects" forbids. Left
///   intentionally uncovered.
/// - The `.noTrash` early-return branches inside the private `computeTrashSize()` (no trash directory
///   resolved, or `FileManager.enumerator` returns nil) can't be forced deterministically either — on
///   every real macOS account `~/.Trash` exists and is enumerable, and there's no seam to fake its
///   absence. Left intentionally uncovered.
/// - The "found a non-directory item, add its size" line inside `computeTrashSize()`'s enumeration loop
///   only executes if the real `~/.Trash` happens to contain at least one file at test time, which is
///   host-dependent and can't be forced without writing into (and risking not being able to fully
///   clean up) the user's real Trash. Left intentionally uncovered for the same reason.
@MainActor
public struct AppStateTrashTests {
    public static func run() async {
        await testUpdateTrashSizeSetsUpdatingFlagAndResolves()
        await testUpdateTrashSizeSupersedesInFlightTask()
    }

    private static func testUpdateTrashSizeSetsUpdatingFlagAndResolves() async {
        let appState = AppState()
        // Let the updateTrashSize() triggered by AppState.init() settle first so it can't race this test.
        await appState.transient.trashSizeTask?.value

        appState.updateTrashSize()
        report(
            "AppState+Trash",
            "POS: updateTrashSize() synchronously flips isTrashUpdating to true before the background enumeration runs",
            result: appState.transient.isTrashUpdating == true)

        await appState.transient.trashSizeTask?.value
        report(
            "AppState+Trash",
            "POS: updateTrashSize() flips isTrashUpdating back to false once the enumeration task resolves",
            result: appState.transient.isTrashUpdating == false)
        report(
            "AppState+Trash",
            "POS: updateTrashSize() leaves trashSizeBytes non-negative after resolving",
            result: appState.transient.trashSizeBytes >= 0)
    }

    private static func testUpdateTrashSizeSupersedesInFlightTask() async {
        let appState = AppState()
        await appState.transient.trashSizeTask?.value

        appState.updateTrashSize()
        let firstTask = appState.transient.trashSizeTask
        // Called again immediately, before the first detached enumeration task has any real chance to
        // run — this exercises the "cancel any enumeration already in flight" superseding logic and the
        // `.cancelled` outcome branch of computeTrashSize()/updateTrashSize()'s switch.
        appState.updateTrashSize()
        let secondTask = appState.transient.trashSizeTask

        await firstTask?.value
        report(
            "AppState+Trash",
            "POS: calling updateTrashSize() again cancels a still-in-flight enumeration task instead of piling another one on top of it",
            result: firstTask?.isCancelled == true)

        await secondTask?.value
        report(
            "AppState+Trash",
            "POS: the superseding updateTrashSize() call's own task is left uncancelled and resolves isTrashUpdating back to false",
            result: appState.transient.isTrashUpdating == false && secondTask?.isCancelled == false)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
