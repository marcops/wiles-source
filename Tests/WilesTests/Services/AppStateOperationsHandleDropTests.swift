import AppKit
import Foundation
@testable import Wiles

/// Continuation of `AppStateOperationsExtraTests` — split out purely to stay under SwiftLint's
/// 500-line file-length limit (see `AppStateOperationsFailureTests` for the same precedent).
/// Still the same dedicated suite for `AppState+Operations.swift`, covering
/// `handleDrop(providers:targetFolder:windowUIState:)`; `run()` here is called alongside the main file's `run()`.
extension AppStateOperationsExtraTests {
    static func runHandleDropTests() async {
        await testHandleDropMovesFileIntoTargetFolder()
        await testHandleDropOntoItselfIsNoOp()
        await testHandleDropOntoOwnParentFolderShowsFriendlyError()
        await testHandleDropFailureReportsError()
    }

    private static func testHandleDropMovesFileIntoTargetFolder() async {
        let sourceDir = makeTempDir()
        let targetDir = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: targetDir)
        }

        let sourceFile = makeFile(named: "dropped.txt", in: sourceDir, content: "drop me")
        let provider = NSItemProvider()
        provider.registerObject(sourceFile as NSURL, visibility: .all)

        let appState = AppState()
        appState.handleDrop(providers: [provider], targetFolder: targetDir, windowUIState: WindowUIState())

        let destFile = targetDir.appendingPathComponent("dropped.txt")
        let moved = await pollUntilTrue { FileManager.default.fileExists(atPath: destFile.path) }
        report("AppState+Operations", "POS: handleDrop() moves the dropped file into the target folder", result: moved)
        report(
            "AppState+Operations",
            "NEG: handleDrop() removes the file from its original location",
            result: !FileManager.default.fileExists(atPath: sourceFile.path))
    }

    /// The early-return guard in `handleDrop` compares the dropped item's own URL to the drop
    /// target, not the dropped item's *parent* to the target — so it only short-circuits the
    /// "drag a folder onto its own row" case (target folder IS the dragged item).
    private static func testHandleDropOntoItselfIsNoOp() async {
        let parentDir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: parentDir) }

        let folderToMove = parentDir.appendingPathComponent("self-target")
        try? FileManager.default.createDirectory(at: folderToMove, withIntermediateDirectories: true)
        let provider = NSItemProvider()
        provider.registerObject(folderToMove as NSURL, visibility: .all)

        let appState = AppState()
        appState.handleDrop(providers: [provider], targetFolder: folderToMove, windowUIState: WindowUIState())

        // Give the async loadObject callback a moment to run; there's nothing to poll for since
        // the expected outcome is "nothing changes."
        try? await Task.sleep(nanoseconds: 300_000_000)
        report(
            "AppState+Operations",
            "NEG: handleDrop() dropping an item directly onto itself as the target is a no-op, not an error",
            result: FileManager.default.fileExists(atPath: folderToMove.path) && appState.modal.errorMessage == nil)
    }

    /// Unlike dropping onto itself (above), dropping a file back into the folder it's already
    /// sitting in does NOT hit the early-return guard (dropped file != target folder) — it falls
    /// through to `moveItem`, whose own same-destination guard throws `itemAlreadyInDestination`,
    /// which `showError` renders as a friendly (non-crashing) message.
    private static func testHandleDropOntoOwnParentFolderShowsFriendlyError() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = makeFile(named: "already-here.txt", in: dir, content: "stay put")
        let provider = NSItemProvider()
        provider.registerObject(file as NSURL, visibility: .all)

        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.handleDrop(providers: [provider], targetFolder: dir, windowUIState: WindowUIState())

        let errorShown = await pollUntilTrue { appState.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: handleDrop() dropping a file back into the folder it's already in surfaces a friendly error instead of crashing or losing the file",
            result: errorShown && FileManager.default.fileExists(atPath: file.path))
    }

    private static func testHandleDropFailureReportsError() async {
        let sourceDir = makeTempDir()
        let targetDir = makeTempDir()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetDir.path)
            try? FileManager.default.removeItem(at: sourceDir)
            try? FileManager.default.removeItem(at: targetDir)
        }

        let sourceFile = makeFile(named: "cant-land.txt", in: sourceDir, content: "blocked")
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: targetDir.path)

        let provider = NSItemProvider()
        provider.registerObject(sourceFile as NSURL, visibility: .all)

        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.handleDrop(providers: [provider], targetFolder: targetDir, windowUIState: WindowUIState())

        let errorShown = await pollUntilTrue { appState.modal.errorMessage != nil }
        report("AppState+Operations", "NEG: handleDrop() reports an error when the move fails (read-only target folder)", result: errorShown)
    }
}
