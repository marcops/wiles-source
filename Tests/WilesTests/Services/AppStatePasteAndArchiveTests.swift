import AppKit
import Foundation
@testable import Wiles

/// `AppState` paste (internal clipboard + pasteboard + materialize-content), undo/redo, iCloud
/// download failure, and password-zip operations. Split out of `AppStateOperationsExtraTests` to
/// stay under the `file_length` / `type_body_length` limits.
@MainActor
public struct AppStatePasteAndArchiveTests {
    public static func run() async {
        await testPasteToCurrentDirectory()
        await testUndoRedoLastAction()
        await testCutPasteCollisionUndoRecording()
        await testDownloadFromiCloudFailure()
        await testCompressSelectedToZIPWithPassword()
        await testPasteToCurrentDirectoryEdgeCases()
        await testPasteClipboardContentAsFile()
    }

    private static func makeFile(named name: String, in dir: URL, content: String = "content") -> URL {
        let url = dir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Drains any undo records the tests leave on the AppState's own service before its temp dir is
    /// removed — a leftover record pointing at a vanished file hangs the suite under retry semantics.
    private static func drainUndoRedoService(_ appState: AppState) async {
        for _ in 0 ..< 10 where appState.undoRedoService.canUndo() {
            _ = try? await appState.undoRedoService.undo()
        }
    }

    private static func pollUntilTrue(_ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< 20 {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return condition()
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
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
        appState.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState.preferences))
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
        appState2.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState2.preferences))
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
        appState.undoRedoService.recordAction(.createFolder(url: createdDirURL))
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

    /// M23 / ML-101: a cut-paste whose destination already holds a same-named file records undo
    /// steps for the resolution. Both KeepBoth and Replace record exactly ONE undo step — KeepBoth
    /// a bare `.move`, Replace a grouped `.batch(.trash + .move)` so a single ⌘Z reverts the move
    /// and restores the file Replace displaced (HH-089).
    private static func testCutPasteCollisionUndoRecording() async {
        await assertCutPasteCollisionUndo(answer: .keepBoth, expectedUndoSteps: 1)
        await assertCutPasteCollisionUndo(answer: .replace, expectedUndoSteps: 1)
    }

    private static func assertCutPasteCollisionUndo(answer: MoveCollisionChoice.Action, expectedUndoSteps: Int) async {
        let sourceDir = makeTempDir()
        let destDir = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: destDir)
        }
        _ = makeFile(named: "clash.txt", in: destDir, content: "existing")
        let cutFile = makeFile(named: "clash.txt", in: sourceDir, content: "incoming")

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.navigateTo(destDir)
        appState.transient.clipboard = ClipboardState(urls: [cutFile], action: .cut)
        appState.pasteToCurrentDirectory(windowUIState: windowUIState)

        _ = await pollUntilTrue { windowUIState.moveCollisionPrompt != nil }
        windowUIState.moveCollisionPrompt?.resolve(MoveCollisionChoice(action: answer, applyToAll: false))
        _ = await pollUntilTrue { !FileManager.default.fileExists(atPath: cutFile.path) }

        var undoSteps = 0
        while appState.undoRedoService.canUndo(), undoSteps < 5 {
            _ = try? await appState.undoRedoService.undo()
            undoSteps += 1
        }
        report(
            "AppState+Operations",
            "\(expectedUndoSteps == 0 ? "NEG" : "POS"): cut-paste collision resolved as \(answer) records \(expectedUndoSteps) undo step(s)",
            result: undoSteps == expectedUndoSteps)
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
        emptyAppState.compressSelectedToZIPWithPassword("irrelevant", urls: [])
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
        appState.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState.preferences))
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
        appState2.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState2.preferences))
        let errorShown = await pollUntilTrue { appState2.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() reports an error when the clipboard's cut source no longer exists on disk",
            result: errorShown)
    }

    /// `pasteClipboardContentAsFile()` — reached only once both the internal clipboard and the
    /// system pasteboard have no file URLs on them at all. Now routed through
    /// `runDetachedFileOperation` (write moved off the main actor), so the assertions poll.
    private static func testPasteClipboardContentAsFile() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let pb = NSPasteboard.general
        defer { pb.clearContents() }

        // POS: no internal clipboard, no file URLs on the system pasteboard, but plain text is
        // present -> materializes a new "Pasted Text.txt" file in the current directory and
        // selects it.
        pb.clearContents()
        pb.setString("materialize me", forType: .string)
        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.transient.clipboard = nil
        appState.selection.selectedURLs = []
        appState.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState.preferences))
        let createdFile = dir.appendingPathComponent("Pasted Text.txt")
        let materialized = await pollUntilTrue {
            FileManager.default.fileExists(atPath: createdFile.path)
                && appState.selection.selectedURLs == Set([createdFile])
        }
        report(
            "AppState+Operations",
            "POS: pasteToCurrentDirectory() with no clipboard/pasteboard URLs materializes pasteboard text content as a new file",
            result: materialized)

        // NEG: nothing pasteable at all (empty pasteboard, no text/image) -> safe no-op.
        pb.clearContents()
        let appState2 = AppState()
        appState2.navigation.currentURL = dir
        appState2.transient.clipboard = nil
        appState2.selection.selectedURLs = []
        appState2.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState2.preferences))
        try? await Task.sleep(nanoseconds: 300_000_000)
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() with nothing on the clipboard or pasteboard is a safe no-op",
            result: appState2.selection.selectedURLs.isEmpty)

        // NEG: the operation's failure branch — the text write fails because the current
        // directory is read-only.
        let readOnlyDir = makeTempDir()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyDir.path)
            try? FileManager.default.removeItem(at: readOnlyDir)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyDir.path)
        pb.clearContents()
        pb.setString("cannot write me", forType: .string)
        let appState3 = AppState()
        appState3.modal.errorMessage = nil
        appState3.navigation.currentURL = readOnlyDir
        appState3.transient.clipboard = nil
        appState3.pasteToCurrentDirectory(windowUIState: WindowUIState(preferences: appState3.preferences))
        let errorShown = await pollUntilTrue { appState3.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: pasteToCurrentDirectory() reports an error when materializing pasteboard content fails (read-only current directory)",
            result: errorShown)
    }
}
