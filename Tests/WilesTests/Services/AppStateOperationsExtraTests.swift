@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct AppStateOperationsExtraTests {
    public static func run() async {
        testDeletePermanentlySelected()
        testCopyContentOfSelected()
        await testDeleteSelected()
        await testShredSelected()
        await testPasteToCurrentDirectory()
        await testUndoRedoLastAction()
        await testDownloadFromiCloudFailure()
        await testCompressSelectedToZIPWithPassword()
    }

    private static func makeFile(named name: String, in dir: URL, content: String = "content") -> URL {
        let url = dir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func testDeletePermanentlySelected() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.selectedURLs = []
        appState.deletePermanentlySelected()
        report("AppState+Operations", "NEG: deletePermanentlySelected() with empty selection is a no-op", result: appState.selectedURLs.isEmpty)

        let fileURL = makeFile(named: "to-shred.txt", in: dir)
        appState.selectedURLs = [fileURL]
        appState.deletePermanentlySelected()
        let stillExists = FileManager.default.fileExists(atPath: fileURL.path)
        report("AppState+Operations", "POS: deletePermanentlySelected() removes the file from disk and clears selection", result: !stillExists && appState.selectedURLs.isEmpty)
    }

    private static func testCopyContentOfSelected() {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("sentinel-before", forType: .string)

        let appState = AppState()
        appState.selectedURLs = []
        appState.copyContentOfSelected()
        let unchanged = pb.string(forType: .string) == "sentinel-before"
        report("AppState+Operations", "NEG: copyContentOfSelected() with empty selection leaves the pasteboard untouched", result: unchanged)

        let fileURL = makeFile(named: "content.txt", in: dir, content: "hello from wiles")
        appState.selectedURLs = [fileURL]
        appState.copyContentOfSelected()
        let copied = pb.string(forType: .string) == "hello from wiles"
        report("AppState+Operations", "POS: copyContentOfSelected() writes the first selected file's text content onto the pasteboard", result: copied)
    }

    private static func testDeleteSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.selectedURLs = []
        appState.deleteSelected()
        report("AppState+Operations", "NEG: deleteSelected() with empty selection leaves selection empty", result: appState.selectedURLs.isEmpty)

        // deleteSelected() internally calls refreshCurrentDirectory(), which reloads
        // appState.navigation.currentURL — without pointing it at our isolated temp dir, it defaults to
        // the real home directory, and list-view's "auto-select first item when selection is
        // empty" behavior then picks up some unrelated real file, breaking the assertion below.
        appState.navigation.currentURL = dir
        appState.preferences.viewMode = .grid

        let fileURL = makeFile(named: "to-trash.txt", in: dir)
        appState.selectedURLs = [fileURL]
        appState.deleteSelected()
        report(
            "AppState+Operations", "POS: deleteSelected() raises the confirmation alert without deleting yet",
            result: appState.showDeleteConfirmAlert && FileManager.default.fileExists(atPath: fileURL.path)
        )

        appState.performDeleteSelected()
        var stillExists = true
        for _ in 0..<20 {
            stillExists = FileManager.default.fileExists(atPath: fileURL.path)
            if !stillExists { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report("AppState+Operations", "POS: performDeleteSelected() moves the file to Trash and clears the selection", result: !stillExists && appState.selectedURLs.isEmpty)
    }

    private static func testShredSelected() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.selectedURLs = []
        appState.shredSelected()
        report("AppState+Operations", "NEG: shredSelected() with empty selection does nothing and does not crash", result: appState.selectedURLs.isEmpty)

        appState.navigation.currentURL = dir
        appState.preferences.viewMode = .grid
        let fileURL = makeFile(named: "to-shred.txt", in: dir, content: "secret data")
        appState.selectedURLs = [fileURL]
        appState.shredSelected()
        var stillExists = true
        for _ in 0..<20 {
            stillExists = FileManager.default.fileExists(atPath: fileURL.path)
            if !stillExists { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report("AppState+Operations", "POS: shredSelected() permanently removes the file and clears the selection", result: !stillExists && appState.selectedURLs.isEmpty)
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
        appState.clipboard = ClipboardState(urls: [sourceFile], action: .copy)
        appState.pasteToCurrentDirectory()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let destFile = destDir.appendingPathComponent("paste-me.txt")
        let copiedExists = FileManager.default.fileExists(atPath: destFile.path)
        let sourceStillExists = FileManager.default.fileExists(atPath: sourceFile.path)
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with a .copy clipboard duplicates the file into the current directory and preserves the source",
            result: copiedExists && sourceStillExists && appState.clipboard != nil
        )

        // NEG: cut-clipboard paste clears the clipboard synchronously (before the async move even completes).
        let cutFile = makeFile(named: "cut-me.txt", in: sourceDir, content: "cut content")
        let appState2 = AppState()
        appState2.navigateTo(destDir)
        appState2.clipboard = ClipboardState(urls: [cutFile], action: .cut)
        appState2.pasteToCurrentDirectory()
        let clipboardClearedImmediately = appState2.clipboard == nil
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() with a .cut clipboard clears the clipboard immediately, not waiting for the move to finish",
            result: clipboardClearedImmediately
        )

        try? await Task.sleep(nanoseconds: 400_000_000)
        let movedExists = FileManager.default.fileExists(atPath: destDir.appendingPathComponent("cut-me.txt").path)
        let originalGone = !FileManager.default.fileExists(atPath: cutFile.path)
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with a .cut clipboard eventually moves the file into the current directory",
            result: movedExists && originalGone
        )
    }

    private static func testUndoRedoLastAction() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Set up a directory that was "created" so undo can trash it, then redo can recreate it.
        let createdDirURL = dir.appendingPathComponent("created-dir")
        try? FileManager.default.createDirectory(at: createdDirURL, withIntermediateDirectories: true)
        UndoRedoService.shared.recordAction(.create(url: createdDirURL))

        let appState = AppState()
        appState.selectedURLs = []
        appState.undoLastAction()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let trashedAway = !FileManager.default.fileExists(atPath: createdDirURL.path)
        let selectionAfterUndo = appState.selectedURLs.first?.path == dir.standardizedFileURL.path
        report("AppState+Operations", "POS: undoLastAction() reverses the recorded action and selects the resulting URL", result: trashedAway && selectionAfterUndo)

        appState.redoLastAction()
        try? await Task.sleep(nanoseconds: 400_000_000)
        let recreated = FileManager.default.fileExists(atPath: createdDirURL.path)
        let selectionAfterRedo = appState.selectedURLs.first?.path == createdDirURL.standardizedFileURL.path
        report("AppState+Operations", "POS: redoLastAction() re-applies the reversed action and selects the resulting URL", result: recreated && selectionAfterRedo)

        // NEG: redoLastAction() with an empty redo stack is a no-op that doesn't clobber selection.
        // Note: UndoRedoService.shared is a process-wide singleton with no reset API, and undo()/redo()
        // always move a record to the OPPOSITE stack rather than discarding it — so alternately draining
        // "while canUndo" then "while canRedo" can never actually reach a truly empty undoStack for a
        // surviving record; it just ping-pongs it back. The one genuinely empty-and-testable state right
        // after the POS undo/redo pair above is the redo stack (redoLastAction was just consumed above).
        let appState2 = AppState()
        let sentinel = dir.appendingPathComponent("sentinel-selection.txt")
        appState2.selectedURLs = [sentinel]
        appState2.redoLastAction()
        try? await Task.sleep(nanoseconds: 300_000_000)
        report(
            "AppState+Operations",
            "NEG: redoLastAction() with an empty redo stack leaves the current selection untouched",
            result: appState2.selectedURLs.first?.path == sentinel.path
        )
    }

    private static func testDownloadFromiCloudFailure() async {
        let missingURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString).icloud")
        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.downloadFromiCloud(url: missingURL)
        try? await Task.sleep(nanoseconds: 500_000_000)
        report(
            "AppState+Operations",
            "NEG: downloadFromiCloud() with a URL that isn't a ubiquitous item reports an error instead of crashing",
            result: appState.modal.errorMessage != nil
        )
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
        appState.modal.passwordCompressURLs = [fileURL]

        appState.compressSelectedToZIPWithPassword("hunter2")

        let zipURL = dir.appendingPathComponent("secret.zip")
        var zipCreated = false
        for _ in 0..<20 {
            zipCreated = FileManager.default.fileExists(atPath: zipURL.path)
            if zipCreated { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        report(
            "AppState+Operations", "POS: compressSelectedToZIPWithPassword() creates the encrypted archive without the caller blocking",
            result: zipCreated
        )

        // NEG: no source URLs set — should be a safe no-op, no crash, nothing created.
        let emptyDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: emptyDir) }
        let emptyAppState = AppState()
        emptyAppState.navigation.currentURL = emptyDir
        emptyAppState.modal.passwordCompressURLs = nil
        emptyAppState.compressSelectedToZIPWithPassword("irrelevant")
        try? await Task.sleep(nanoseconds: 300_000_000)
        let emptyDirContents = (try? FileManager.default.contentsOfDirectory(atPath: emptyDir.path)) ?? ["unexpected-error"]
        report(
            "AppState+Operations", "NEG: compressSelectedToZIPWithPassword() with no passwordCompressURLs set is a safe no-op",
            result: emptyDirContents.isEmpty
        )
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
