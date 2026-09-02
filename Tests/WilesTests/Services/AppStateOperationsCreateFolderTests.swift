import AppKit
import Foundation
@testable import Wiles

/// Continuation of `AppStateOperationsExtraTests` — split out purely to stay under SwiftLint's
/// 500-line file-length limit (see `AppStateOperationsFailureTests` for the same precedent).
/// Still the same dedicated suite for `AppState+Operations.swift`, covering
/// `createNewFolderAndRename(in:windowUIState:)`.
extension AppStateOperationsExtraTests {
    static func runCreateFolderTests() async {
        await testCreateNewFolderAndRenameInCurrentDirectory()
        await testCreateNewFolderAndRenameInOtherFolder()
        await testCreateNewFolderAndRenameFailure()
        await testCreateNewFileAndRenameInCurrentDirectory()
        await testCreateNewFileAndRenameFailure()
    }

    /// M15/M16: `createNewFileAndRename()` now routes through `runDetachedFileOperation`
    /// (`refreshOnSuccess: false`, `onSuccess` -> `enterRenameForNewlyCreated`), so it dispatches
    /// via `Task{}` and the result must be polled for — same shape as the folder variant above.
    private static func testCreateNewFileAndRenameInCurrentDirectory() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.navigation.currentURL = dir
        appState.fileSystem.items = []
        appState.createNewFileAndRename(windowUIState: windowUIState)

        let entered = await pollUntilTrue { appState.fileSystem.renamingURL != nil }
        guard entered, let createdURL = appState.fileSystem.renamingURL else {
            report(
                "AppState+Operations",
                "POS: createNewFileAndRename() creates a new file in the current directory and enters rename mode",
                result: false)
            return
        }
        report(
            "AppState+Operations",
            "POS: createNewFileAndRename() creates a new file in the current directory and enters rename mode",
            result: FileManager.default.fileExists(atPath: createdURL.path)
                && appState.fileSystem.items.first?.url == createdURL.standardizedFileURL
                && windowUIState.renameItem?.url == createdURL.standardizedFileURL
                && appState.selection.selectedURLs == Set([createdURL]))
    }

    private static func testCreateNewFileAndRenameFailure() async {
        let readOnlyParent = makeTempDir()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyParent.path)
            try? FileManager.default.removeItem(at: readOnlyParent)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyParent.path)

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.modal.errorMessage = nil
        appState.navigation.currentURL = readOnlyParent
        appState.createNewFileAndRename(windowUIState: windowUIState)

        let errored = await pollUntilTrue { appState.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: createNewFileAndRename() reports an error when the file can't be created (read-only parent directory)",
            result: errored && windowUIState.renameItem == nil)
    }

    /// createNewFolderAndRename() dispatches via Task{}, so a synchronous check right after
    /// calling it is racy — poll like the other Task-backed operations in this file.
    private static func testCreateNewFolderAndRenameInCurrentDirectory() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.navigation.currentURL = dir
        appState.fileSystem.items = []
        appState.createNewFolderAndRename(windowUIState: windowUIState)

        let entered = await pollUntilTrue { appState.fileSystem.renamingURL != nil }
        guard entered, let createdURL = appState.fileSystem.renamingURL else {
            report(
                "AppState+Operations",
                "POS: createNewFolderAndRename() creates a new folder in the current directory and enters rename mode",
                result: false)
            return
        }
        report(
            "AppState+Operations",
            "POS: createNewFolderAndRename() creates a new folder in the current directory and enters rename mode",
            result: FileManager.default.fileExists(atPath: createdURL.path)
                && appState.fileSystem.items.first?.url == createdURL.standardizedFileURL
                && windowUIState.renameItem?.url == createdURL.standardizedFileURL
                && appState.selection.selectedURLs == Set([createdURL]))
    }

    /// `folder` may differ from `navigation.currentURL` — the folder still gets created, but the app
    /// must NOT enter rename mode for it (the item isn't on screen, and `renamingURL` would freeze
    /// the visible directory's refresh) and must not touch `fileSystem.items` — ML-072.
    private static func testCreateNewFolderAndRenameInOtherFolder() async {
        let currentDir = makeTempDir()
        let otherFolder = makeTempDir()
        defer {
            try? FileManager.default.removeItem(at: currentDir)
            try? FileManager.default.removeItem(at: otherFolder)
        }

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.navigation.currentURL = currentDir
        appState.fileSystem.items = []
        appState.createNewFolderAndRename(in: otherFolder, windowUIState: windowUIState)

        let created = await pollUntilTrue {
            !(((try? FileManager.default.contentsOfDirectory(atPath: otherFolder.path)) ?? []).isEmpty)
        }
        let noRenameSession = windowUIState.renameItem == nil && appState.fileSystem.renamingURL == nil
        report(
            "AppState+Operations",
            "NEG: createNewFolderAndRename(in:) targeting a non-current folder creates it without entering rename mode or touching fileSystem.items",
            result: created && noRenameSession && appState.fileSystem.items.isEmpty)
    }

    private static func testCreateNewFolderAndRenameFailure() async {
        let readOnlyParent = makeTempDir()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyParent.path)
            try? FileManager.default.removeItem(at: readOnlyParent)
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: readOnlyParent.path)

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)
        appState.modal.errorMessage = nil
        appState.navigation.currentURL = readOnlyParent
        appState.createNewFolderAndRename(windowUIState: windowUIState)

        let errored = await pollUntilTrue { appState.modal.errorMessage != nil }
        report(
            "AppState+Operations",
            "NEG: createNewFolderAndRename() reports an error when the folder can't be created (read-only parent directory)",
            result: errored && windowUIState.renameItem == nil)
    }
}
