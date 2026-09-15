import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateOperationsExtraTests {
    public static func run() async {
        await testDeletePermanentlySelected()
        await testCopyContentOfSelected()
        await testCopyContentOfSelectedDoesNotReloadDirectory()
        await testDeleteSelected()
        await testUndoLastActionWithEmptyUndoStack()
        await runHandleDropTests()
        await runFailureTests()
        await runCreateFolderTests()
    }

    static func makeFile(named name: String, in dir: URL, content: String = "content") -> URL {
        let url = dir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// AppState operations that succeed (paste, trash-delete, undo/redo) record on that AppState's
    /// own `undoRedoService`. Call this as the last statement in any test function that triggers
    /// one, before its `defer`-removal of the temp dir runs — otherwise the leftover record points
    /// at a file that's about to vanish, and undoing it later fails forever under that service's
    /// retry-on-failure semantics, hanging the suite.
    static func drainUndoRedoService(_ appState: AppState) async {
        for _ in 0 ..< 10 where appState.undoRedoService.canUndo() {
            _ = try? await appState.undoRedoService.undo()
        }
    }

    /// Shared bounded-polling helper matching the 20 x 200ms budget used throughout this file.
    static func pollUntilTrue(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 20 {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return condition()
    }

    /// Shared setup: a chmod 555 parent forces fm.removeItem to throw, with no system UI.
    static func expectErrorFromReadOnlyParent(fileName: String, action: (AppState) -> Void) async -> Bool {
        let dir = makeTempDir()
        let fileURL = makeFile(named: fileName, in: dir, content: "secret data")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
            try? FileManager.default.removeItem(at: dir)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.path)

        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.navigation.currentURL = dir
        appState.selection.selectedURLs = [fileURL]
        action(appState)

        return await pollUntilTrue { appState.modal.errorMessage != nil }
    }

    /// Permanent delete is irreversible and bypasses the Trash, so `deletePermanentlySelected`
    /// **always** asks for confirmation — `skipDeleteConfirmation` (a "move to Trash" preference)
    /// does not apply. The actual shred lives in `performDeletePermanentlySelected()`, which runs
    /// in a `Task.detached` — so that case polls with a bounded timeout.
    private static func testDeletePermanentlySelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let originalSkip = UserDefaults.standard.bool(forKey: DefaultsKey.skipDeleteConfirmation.rawValue)
        defer { UserDefaults.standard.set(originalSkip, forKey: DefaultsKey.skipDeleteConfirmation.rawValue) }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.selection.selectedURLs = []
        appState.deletePermanentlySelected(windowUIState: windowUIState)
        report(
            "AppState+Operations",
            "NEG: deletePermanentlySelected() with empty selection is a no-op and shows no alert",
            result: appState.selection.selectedURLs.isEmpty && !windowUIState.showDeletePermanentlyConfirmAlert)

        let guardedFile = makeFile(named: "guarded.txt", in: dir)
        appState.preferences.view.skipDeleteConfirmation = false
        appState.selection.selectedURLs = [guardedFile]
        appState.deletePermanentlySelected(windowUIState: windowUIState)
        report(
            "AppState+Operations",
            "POS: deletePermanentlySelected() asks for confirmation and leaves the file on disk when confirmation is not skipped",
            result: windowUIState.showDeletePermanentlyConfirmAlert && FileManager.default.fileExists(atPath: guardedFile.path))

        // Even with skipDeleteConfirmation on, permanent delete still only raises the alert — it
        // never shreds straight through (B2-1: that pref is for the reversible Trash path only).
        let guardedFile2 = makeFile(named: "guarded2.txt", in: dir)
        windowUIState.showDeletePermanentlyConfirmAlert = false
        appState.preferences.view.skipDeleteConfirmation = true
        appState.selection.selectedURLs = [guardedFile2]
        appState.deletePermanentlySelected(windowUIState: windowUIState)
        report(
            "AppState+Operations",
            "POS: deletePermanentlySelected() still only raises the alert even when skipDeleteConfirmation is on",
            result: windowUIState.showDeletePermanentlyConfirmAlert && FileManager.default.fileExists(atPath: guardedFile2.path))

        // The alert's confirm button calls performDeletePermanentlySelected(), which does the shred.
        let fileURL = makeFile(named: "to-shred.txt", in: dir)
        appState.selection.selectedURLs = [fileURL]
        appState.performDeletePermanentlySelected()
        var stillExists = true
        for _ in 0 ..< 20 {
            stillExists = FileManager.default.fileExists(atPath: fileURL.path)
            if !stillExists {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report(
            "AppState+Operations",
            "POS: performDeletePermanentlySelected() removes the file from disk and clears selection",
            result: !stillExists && appState.selection.selectedURLs.isEmpty)
    }

    /// copyFileContentToClipboard() (called by copyContentOfSelected()) now reads the file and
    /// writes to the pasteboard inside an internal Task.detached, keeping its own signature
    /// synchronous/fire-and-forget (see FileSystemService+Actions.swift). A synchronous check
    /// right after calling it is racy — poll with a bounded timeout for the positive case; the
    /// negative (empty-selection) case never spawns a task at all, so it's safe to check
    /// immediately.
    private static func testCopyContentOfSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("sentinel-before", forType: .string)

        let appState = AppState()
        appState.selection.selectedURLs = []
        appState.copyContentOfSelected()
        let unchanged = pb.string(forType: .string) == "sentinel-before"
        report("AppState+Operations", "NEG: copyContentOfSelected() with empty selection leaves the pasteboard untouched", result: unchanged)

        let fileURL = makeFile(named: "content.txt", in: dir, content: "hello from wiles")
        appState.selection.selectedURLs = [fileURL]
        await appState.copyContentOfSelected()?.value
        report(
            "AppState+Operations", "POS: copyContentOfSelected() writes the first selected file's text content onto the pasteboard",
            result: pb.string(forType: .string) == "hello from wiles")
    }

    /// M15: `copyContentOfSelected()` passes `refreshOnSuccess: false` to `runDetachedFileOperation`,
    /// so a successful content-copy must NOT reload the current directory listing. Observable here
    /// via `fileSystem.items`: seeded empty against a temp dir that holds real files, it stays empty
    /// unless a stray `refreshCurrentDirectory()` runs.
    private static func testCopyContentOfSelectedDoesNotReloadDirectory() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = makeFile(named: "payload.txt", in: dir, content: "payload body")
        _ = makeFile(named: "other-on-disk.txt", in: dir, content: "sibling")

        let pb = NSPasteboard.general
        pb.clearContents()

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.fileSystem.items = []
        appState.selection.selectedURLs = [fileURL]

        await appState.copyContentOfSelected()?.value
        report(
            "AppState+Operations",
            "NEG: copyContentOfSelected() with refreshOnSuccess:false does not reload fileSystem.items from the current directory",
            result: appState.fileSystem.items.isEmpty)
    }

    /// M15: `undoLastAction()`'s operation returns `URL?`; with an empty undo stack `undo()` returns
    /// nil, `onSuccess` selects nothing, and the selection is left untouched. (It still calls
    /// `refreshCurrentDirectory()` in this nil case — see the batch report.)
    private static func testUndoLastActionWithEmptyUndoStack() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sentinel = dir.appendingPathComponent("sentinel-\(UUID().uuidString).txt")

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.selection.selectedURLs = [sentinel]
        await appState.undoLastAction().value
        report(
            "AppState+Operations",
            "NEG: undoLastAction() with an empty undo stack leaves the current selection untouched",
            result: appState.selection.selectedURLs == [sentinel])
    }

    private static func testDeleteSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.selection.selectedURLs = []
        appState.deleteSelected(windowUIState: windowUIState)
        report("AppState+Operations", "NEG: deleteSelected() with empty selection leaves selection empty", result: appState.selection.selectedURLs.isEmpty)

        // deleteSelected() internally calls refreshCurrentDirectory(), which reloads
        // appState.navigation.currentURL — without pointing it at our isolated temp dir, it defaults to
        // the real home directory, and list-view's "auto-select first item when selection is
        // empty" behavior then picks up some unrelated real file, breaking the assertion below.
        appState.navigation.currentURL = dir
        appState.preferences.view.viewMode = .grid

        let fileURL = makeFile(named: "to-trash.txt", in: dir)
        appState.selection.selectedURLs = [fileURL]
        appState.deleteSelected(windowUIState: windowUIState)
        report(
            "AppState+Operations", "POS: deleteSelected() raises the confirmation alert without deleting yet",
            result: windowUIState.showDeleteConfirmAlert && FileManager.default.fileExists(atPath: fileURL.path))

        await appState.performDeleteSelected()?.value
        report(
            "AppState+Operations",
            "POS: performDeleteSelected() moves the file to Trash and clears the selection",
            result: !FileManager.default.fileExists(atPath: fileURL.path) && appState.selection.selectedURLs.isEmpty)
        await drainUndoRedoService(appState)

        await testDeleteSelectedSkipConfirmation(dir: dir)
    }

    /// UI_TEST_BACKLOG.md's `skipDeleteConfirmation` bypass branch, deferred until this file was
    /// touched again for a real reason (it now has been, for the WindowUIState migration above).
    private static func testDeleteSelectedSkipConfirmation(dir: URL) async {
        let bypassFile = makeFile(named: "bypass.txt", in: dir)
        let bypassAppState = AppState()
        let bypassWindowUIState = WindowUIState(preferences: bypassAppState.preferences)
        bypassAppState.navigation.currentURL = dir
        bypassAppState.preferences.view.skipDeleteConfirmation = true
        bypassAppState.selection.selectedURLs = [bypassFile]
        await bypassAppState.deleteSelected(windowUIState: bypassWindowUIState)?.value
        report(
            "AppState+Operations",
            "POS: deleteSelected() with skipDeleteConfirmation=true deletes directly without raising the confirm alert",
            result: !FileManager.default.fileExists(atPath: bypassFile.path) && !bypassWindowUIState.showDeleteConfirmAlert)
        await drainUndoRedoService(bypassAppState)

        let keepFile = makeFile(named: "keep.txt", in: dir)
        let keepAppState = AppState()
        let keepWindowUIState = WindowUIState(preferences: keepAppState.preferences)
        keepAppState.navigation.currentURL = dir
        keepAppState.preferences.view.skipDeleteConfirmation = false
        keepAppState.selection.selectedURLs = [keepFile]
        keepAppState.deleteSelected(windowUIState: keepWindowUIState)
        report(
            "AppState+Operations",
            "NEG: deleteSelected() with skipDeleteConfirmation=false only raises the confirm alert and never touches the file system",
            result: keepWindowUIState.showDeleteConfirmAlert && FileManager.default.fileExists(atPath: keepFile.path))
    }

    static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
