import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateOperationsExtraTests {
    public static func run() async {
        await testDeletePermanentlySelected()
        await testCopyContentOfSelected()
        await testDeleteSelected()
        await testShredSelected()
        await testPasteToCurrentDirectory()
        await testUndoRedoLastAction()
        await testDownloadFromiCloudFailure()
        await testCompressSelectedToZIPWithPassword()
        await testPasteToCurrentDirectoryEdgeCases()
        await runHandleDropTests()
        await runFailureTests()
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

    /// deletePermanentlySelected() moved its shred call into a Task.detached (see
    /// AppState+Operations.swift) so the file removal and selection-clearing now happen
    /// asynchronously off @MainActor. A synchronous check right after calling it is racy —
    /// poll with a bounded timeout, matching the pattern already used by
    /// testDeleteSelected()/testShredSelected() below for the same reason.
    private static func testDeletePermanentlySelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.selection.selectedURLs = []
        appState.deletePermanentlySelected()
        report("AppState+Operations", "NEG: deletePermanentlySelected() with empty selection is a no-op", result: appState.selection.selectedURLs.isEmpty)

        let fileURL = makeFile(named: "to-shred.txt", in: dir)
        appState.selection.selectedURLs = [fileURL]
        appState.deletePermanentlySelected()
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
            "POS: deletePermanentlySelected() removes the file from disk and clears selection",
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
        appState.copyContentOfSelected()
        var copied = false
        for _ in 0 ..< 20 {
            copied = pb.string(forType: .string) == "hello from wiles"
            if copied {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report("AppState+Operations", "POS: copyContentOfSelected() writes the first selected file's text content onto the pasteboard", result: copied)
    }

    private static func testDeleteSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let windowUIState = WindowUIState()
        appState.selection.selectedURLs = []
        appState.deleteSelected(windowUIState: windowUIState)
        report("AppState+Operations", "NEG: deleteSelected() with empty selection leaves selection empty", result: appState.selection.selectedURLs.isEmpty)

        // deleteSelected() internally calls refreshCurrentDirectory(), which reloads
        // appState.navigation.currentURL — without pointing it at our isolated temp dir, it defaults to
        // the real home directory, and list-view's "auto-select first item when selection is
        // empty" behavior then picks up some unrelated real file, breaking the assertion below.
        appState.navigation.currentURL = dir
        appState.preferences.viewMode = .grid

        let fileURL = makeFile(named: "to-trash.txt", in: dir)
        appState.selection.selectedURLs = [fileURL]
        appState.deleteSelected(windowUIState: windowUIState)
        report(
            "AppState+Operations", "POS: deleteSelected() raises the confirmation alert without deleting yet",
            result: windowUIState.showDeleteConfirmAlert && FileManager.default.fileExists(atPath: fileURL.path))

        appState.performDeleteSelected()
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
            "POS: performDeleteSelected() moves the file to Trash and clears the selection",
            result: !stillExists && appState.selection.selectedURLs.isEmpty)
        await drainUndoRedoService(appState)

        await testDeleteSelectedSkipConfirmation(dir: dir)
    }

    /// UI_TEST_BACKLOG.md's `skipDeleteConfirmation` bypass branch, deferred until this file was
    /// touched again for a real reason (it now has been, for the WindowUIState migration above).
    private static func testDeleteSelectedSkipConfirmation(dir: URL) async {
        let bypassFile = makeFile(named: "bypass.txt", in: dir)
        let bypassAppState = AppState()
        let bypassWindowUIState = WindowUIState()
        bypassAppState.navigation.currentURL = dir
        bypassAppState.preferences.skipDeleteConfirmation = true
        bypassAppState.selection.selectedURLs = [bypassFile]
        bypassAppState.deleteSelected(windowUIState: bypassWindowUIState)
        var bypassFileStillExists = true
        for _ in 0 ..< 20 {
            bypassFileStillExists = FileManager.default.fileExists(atPath: bypassFile.path)
            if !bypassFileStillExists {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report(
            "AppState+Operations",
            "POS: deleteSelected() with skipDeleteConfirmation=true deletes directly without raising the confirm alert",
            result: !bypassFileStillExists && !bypassWindowUIState.showDeleteConfirmAlert)
        await drainUndoRedoService(bypassAppState)

        let keepFile = makeFile(named: "keep.txt", in: dir)
        let keepAppState = AppState()
        let keepWindowUIState = WindowUIState()
        keepAppState.navigation.currentURL = dir
        keepAppState.preferences.skipDeleteConfirmation = false
        keepAppState.selection.selectedURLs = [keepFile]
        keepAppState.deleteSelected(windowUIState: keepWindowUIState)
        report(
            "AppState+Operations",
            "NEG: deleteSelected() with skipDeleteConfirmation=false only raises the confirm alert and never touches the file system",
            result: keepWindowUIState.showDeleteConfirmAlert && FileManager.default.fileExists(atPath: keepFile.path))
    }

    private static func testShredSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.selection.selectedURLs = []
        appState.shredSelected()
        report(
            "AppState+Operations",
            "NEG: shredSelected() with empty selection does nothing and does not crash",
            result: appState.selection.selectedURLs.isEmpty)

        appState.navigation.currentURL = dir
        appState.preferences.viewMode = .grid
        let fileURL = makeFile(named: "to-shred.txt", in: dir, content: "secret data")
        appState.selection.selectedURLs = [fileURL]
        appState.shredSelected()
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
            "POS: shredSelected() permanently removes the file and clears the selection",
            result: !stillExists && appState.selection.selectedURLs.isEmpty)
    }

    private static func testPasteToCurrentDirectory() async {
        let sourceDir = makeTempDir()
        let destDir = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: destDir)
        }

        // POS: copy-clipboard paste duplicates the file into currentURL and keeps the clipboard.
        let sourceFile = makeFile(named: "paste-me.txt", in: sourceDir, content: "paste content")
        let appState = AppState()
        appState.navigateTo(destDir)
        appState.transient.clipboard = ClipboardState(urls: [sourceFile], action: .copy)
        appState.pasteToCurrentDirectory()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let destFile = destDir.appendingPathComponent("paste-me.txt")
        let copiedExists = FileManager.default.fileExists(atPath: destFile.path)
        let sourceStillExists = FileManager.default.fileExists(atPath: sourceFile.path)
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with a .copy clipboard duplicates the file into the current directory and preserves the source",
            result: copiedExists && sourceStillExists && appState.transient.clipboard != nil)

        // NEG: cut-clipboard paste clears the clipboard synchronously (before the async move even completes).
        let cutFile = makeFile(named: "cut-me.txt", in: sourceDir, content: "cut content")
        let appState2 = AppState()
        appState2.navigateTo(destDir)
        appState2.transient.clipboard = ClipboardState(urls: [cutFile], action: .cut)
        appState2.pasteToCurrentDirectory()
        let clipboardClearedImmediately = appState2.transient.clipboard == nil
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() with a .cut clipboard clears the clipboard immediately, not waiting for the move to finish",
            result: clipboardClearedImmediately)

        try? await Task.sleep(nanoseconds: 400_000_000)
        let movedExists = FileManager.default.fileExists(atPath: destDir.appendingPathComponent("cut-me.txt").path)
        let originalGone = !FileManager.default.fileExists(atPath: cutFile.path)
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with a .cut clipboard eventually moves the file into the current directory",
            result: movedExists && originalGone)
        await drainUndoRedoService(appState)
        await drainUndoRedoService(appState2)
    }

    private static func testUndoRedoLastAction() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Set up a directory that was "created" so undo can trash it, then redo can recreate it.
        let createdDirURL = dir.appendingPathComponent("created-dir")
        try? FileManager.default.createDirectory(at: createdDirURL, withIntermediateDirectories: true)

        let appState = AppState()
        appState.undoRedoService.recordAction(.create(url: createdDirURL))
        appState.selection.selectedURLs = []
        appState.undoLastAction()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let trashedAway = !FileManager.default.fileExists(atPath: createdDirURL.path)
        let selectionAfterUndo = appState.selection.selectedURLs.first?.path == dir.standardizedFileURL.path
        report(
            "AppState+Operations",
            "POS: undoLastAction() reverses the recorded action and selects the resulting URL",
            result: trashedAway && selectionAfterUndo)

        appState.redoLastAction()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let recreated = FileManager.default.fileExists(atPath: createdDirURL.path)
        let selectionAfterRedo = appState.selection.selectedURLs.first?.path == createdDirURL.standardizedFileURL.path
        report(
            "AppState+Operations",
            "POS: redoLastAction() re-applies the reversed action and selects the resulting URL",
            result: recreated && selectionAfterRedo)

        // NEG: redoLastAction() with an empty redo stack is a no-op that doesn't clobber selection.
        // Note: undo()/redo() always move a record to the OPPOSITE stack rather than discarding it —
        // so alternately draining "while canUndo" then "while canRedo" can never actually reach a
        // truly empty undoStack for a surviving record; it just ping-pongs it back. The one
        // genuinely empty-and-testable state right after the POS undo/redo pair above is the redo
        // stack (redoLastAction was just consumed above). A separate `appState2` also guarantees its
        // own `undoRedoService` starts genuinely empty.
        let appState2 = AppState()
        let sentinel = dir.appendingPathComponent("sentinel-selection.txt")
        appState2.selection.selectedURLs = [sentinel]
        appState2.redoLastAction()
        try? await Task.sleep(nanoseconds: 300_000_000)
        report(
            "AppState+Operations",
            "NEG: redoLastAction() with an empty redo stack leaves the current selection untouched",
            result: appState2.selection.selectedURLs.first?.path == sentinel.path)
        await drainUndoRedoService(appState)
    }

    private static func testDownloadFromiCloudFailure() async {
        let missingURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString).icloud")
        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.downloadFromiCloud(url: missingURL)
        try? await Task.sleep(nanoseconds: 500_000_000)
        report(
            "AppState+Operations",
            "NEG: downloadFromiCloud() with a URL that isn't a ubiquitous item reports an error instead of crashing",
            result: appState.modal.errorMessage != nil)
    }

    /// Regression coverage for the beachball fix: PasswordCompressSheetView's "OK" button used to
    /// call ArchiveService.compressToZIP synchronously on @MainActor, blocking the whole UI for as
    /// long as `zip` took to run. compressSelectedToZIPWithPassword() mirrors the already-async
    /// compressSelectedToZIP()/extractArchive() pattern: fire-and-forget from the caller's
    /// perspective, actual work happens in a detached Task.
    private static func testCompressSelectedToZIPWithPassword() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = makeFile(named: "secret.txt", in: dir, content: "classified")
        let appState = AppState()
        appState.navigation.currentURL = dir

        appState.compressSelectedToZIPWithPassword("hunter2", urls: [fileURL])

        let zipURL = dir.appendingPathComponent("secret.zip")
        var zipCreated = false
        for _ in 0 ..< 20 {
            zipCreated = FileManager.default.fileExists(atPath: zipURL.path)
            if zipCreated {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report(
            "AppState+Operations", "POS: compressSelectedToZIPWithPassword() creates the encrypted archive without the caller blocking",
            result: zipCreated)

        // NEG: no source URLs set — should be a safe no-op, no crash, nothing created.
        let emptyDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: emptyDir) }
        let emptyAppState = AppState()
        emptyAppState.navigation.currentURL = emptyDir
        emptyAppState.compressSelectedToZIPWithPassword("irrelevant", urls: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
        let emptyDirContents = (try? FileManager.default.contentsOfDirectory(atPath: emptyDir.path)) ?? ["unexpected-error"]
        report(
            "AppState+Operations", "NEG: compressSelectedToZIPWithPassword() with no passwordCompressURLs set is a safe no-op",
            result: emptyDirContents.isEmpty)
    }

    /// Nil-clipboard pasteboard fallback + executePaste()'s catch branch (missing cut source).
    private static func testPasteToCurrentDirectoryEdgeCases() async {
        let sourceDir = makeTempDir()
        let destDir = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: destDir)
        }
        let pb = NSPasteboard.general
        defer { pb.clearContents() }

        let sourceFile = makeFile(named: "fallback-paste.txt", in: sourceDir, content: "fallback content")
        PasteboardService.writeToPasteboard(urls: [sourceFile])
        let appState = AppState()
        appState.navigateTo(destDir)
        appState.transient.clipboard = nil
        appState.pasteToCurrentDirectory()
        let destFile = destDir.appendingPathComponent("fallback-paste.txt")
        let copied = await pollUntilTrue { FileManager.default.fileExists(atPath: destFile.path) }
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with a nil clipboard falls back to copying URLs found on the system pasteboard",
            result: copied)
        await drainUndoRedoService(appState)

        let missingFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("missing-cut-\(UUID().uuidString).txt")
        let appState2 = AppState()
        appState2.modal.errorMessage = nil
        appState2.navigateTo(destDir)
        appState2.transient.clipboard = ClipboardState(urls: [missingFile], action: .cut)
        appState2.pasteToCurrentDirectory()
        let errorShown = await pollUntilTrue { appState2.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() reports an error when the clipboard's cut source no longer exists on disk",
            result: errorShown)
    }

    static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
