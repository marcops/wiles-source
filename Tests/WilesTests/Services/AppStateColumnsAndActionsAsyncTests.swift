import AppKit
import CoreGraphics
import UniformTypeIdentifiers
import XCTest
@testable import Wiles

/// Companion coverage for the `Task.detached`-driven members of `AppState+ColumnsAndActions.swift`
/// (`performImageConversion`, `performBatchRename`) plus `performRename()`'s success path.
///
/// `AppStateColumnsAndSelectionTests.swift` is the dedicated 1-to-1 test file for this source file
/// (per AGENTS.md rule 16) and covers every synchronous member. These three specific members either
/// kick off async work via `Task.detached` (requiring a polling wait that only an `async` test method
/// can express) or record onto that `AppState`'s own `undoRedoService` (requiring an `async` drain
/// per AGENTS.md rule 17 - see `AppStateOperationsExtraTests.swift` for the identical,
/// pre-existing pattern of a "sync dedicated file + async companion file" split for one source file).
/// A standalone `XCTestCase` (same precedent as `SpotlightSearchTests.swift`) needs no wiring into
/// `WilesAutomatedXCTestCase.swift`, so it's discoverable without touching that shared file.
@MainActor
final class AppStateColumnsAndActionsAsyncTests: XCTestCase {
    private func makeTempDir() -> URL {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeItem(named name: String, in dir: URL, content: String = "content") -> FileItem {
        let url = dir.appendingPathComponent(name)
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return FileItem.load(url: url, icon: NSImage(size: NSSize(width: 16, height: 16)))
    }

    /// Builds a tiny real PNG on disk (mirrors `ImageConverterCoverageTests.makeTestImage`) so
    /// `ImageConverterService.convertImage()` has real, readable image bytes to decode.
    private func makeTestImage(named name: String, in dir: URL, width: Int = 8, height: Int = 8) -> FileItem {
        let url = dir.appendingPathComponent(name)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), let cgImage: CGImage = {
            context.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            return context.makeImage()
        }() else {
            XCTFail("Failed to build test fixture image")
            return FileItem.load(url: url, icon: NSImage(size: NSSize(width: 16, height: 16)))
        }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            XCTFail("Failed to create CGImageDestination for test fixture")
            return FileItem.load(url: url, icon: NSImage(size: NSSize(width: 16, height: 16)))
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return FileItem.load(url: url, icon: NSImage(size: NSSize(width: 16, height: 16)))
    }

    /// Repeatedly drains `appState.undoRedoService` (undo() is async - see the file-level doc
    /// comment for why this can't happen in the synchronous dedicated test file) so a rename
    /// recorded by this test never lingers to break a later assertion once its temp dir is removed.
    private func drainUndoRedoService(_ appState: AppState) async {
        for _ in 0 ..< 10 where appState.undoRedoService.canUndo() {
            _ = try? await appState.undoRedoService.undo()
        }
    }

    /// L20 end-to-end: a per-folder view mode set for a folder must follow that folder to its new
    /// location when it's moved in-app through `AppState.moveItem(at:toFolder:)`, and the stale
    /// old-path key must be gone afterward.
    func testMoveItemFollowsPerFolderViewModeToNewLocation() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sourceParent = dir.appendingPathComponent("Source")
        let destParent = dir.appendingPathComponent("Dest")
        try? FileManager.default.createDirectory(at: sourceParent, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: destParent, withIntermediateDirectories: true)
        let folder = sourceParent.appendingPathComponent("Projects")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let appState = AppState()
        let priorModes = appState.preferences.perFolderViewModes
        let priorEnabled = appState.preferences.perFolderViewModeEnabled
        let priorViewMode = appState.preferences.viewMode
        defer {
            appState.preferences.perFolderViewModes = priorModes
            appState.preferences.perFolderViewModeEnabled = priorEnabled
            appState.preferences.viewMode = priorViewMode
        }
        appState.preferences.perFolderViewModeEnabled = true
        appState.preferences.viewMode = .grid
        appState.preferences.perFolderViewModes = [folder.standardizedFileURL.path: ViewMode.list.rawValue]

        guard let destURL = try? await appState.moveItem(at: folder, toFolder: destParent) else {
            XCTFail("moveItem should have moved the folder")
            return
        }

        XCTAssertEqual(appState.viewModeForFolder(destURL), .list, "the per-folder view mode should now apply at the folder's new path")
        XCTAssertNil(
            appState.preferences.perFolderViewModes[folder.standardizedFileURL.path],
            "the stale old-path per-folder view mode key should be removed")
        XCTAssertEqual(appState.viewModeForFolder(folder), .grid, "the old path should fall back to the global view mode")
    }

    func testPerformRenameSuccessPath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        let item = makeItem(named: "before.txt", in: dir)

        appState.performRename(item: item, newName: "after.txt")

        let renamedURL = dir.appendingPathComponent("after.txt")
        var renamed = false
        for _ in 0 ..< 6 {
            renamed = FileManager.default.fileExists(atPath: renamedURL.path)
            if renamed {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(renamed, "performRename() should move the file on disk to the new name")
        XCTAssertFalse(FileManager.default.fileExists(atPath: item.url.path), "performRename() should leave nothing behind at the old path")
        XCTAssertEqual(appState.selection.selectedURLs, [renamedURL], "performRename() should select the freshly renamed URL")
        XCTAssertTrue(appState.undoRedoService.canUndo(), "performRename() should record an undoable .rename action")

        // runDetachedURLOperation's onSuccess must record exactly one undo action, not several.
        _ = try? await appState.undoRedoService.undo()
        XCTAssertFalse(appState.undoRedoService.canUndo(), "performRename() via runDetachedURLOperation should record exactly one undo action")

        await drainUndoRedoService(appState)
    }

    func testPerformRenameFailurePath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.modal.errorMessage = nil
        let item = makeItem(named: "source.txt", in: dir)
        _ = makeItem(named: "taken.txt", in: dir)

        appState.performRename(item: item, newName: "taken.txt")

        var errored = false
        for _ in 0 ..< 6 {
            errored = appState.modal.errorMessage != nil
            if errored {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(errored, "performRename() should surface an error via showError() when renameItem() throws")
        XCTAssertTrue(FileManager.default.fileExists(atPath: item.url.path), "performRename() should leave the source file untouched on failure")
    }

    func testPerformImageConversionSuccessPath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        let item = makeTestImage(named: "source.png", in: dir)

        appState.performImageConversion(item: item, targetFormat: .jpeg, preset: .original, cropPreset: .none, quality: 0.9)

        let expectedDest = dir.appendingPathComponent("source_converted.jpg")
        var created = false
        for _ in 0 ..< 6 {
            created = FileManager.default.fileExists(atPath: expectedDest.path)
            if created {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(created, "performImageConversion() should write the converted file to disk without the caller blocking")
        XCTAssertEqual(
            appState.selection.selectedURLs,
            [expectedDest],
            "performImageConversion() should select the newly converted file once the detached Task finishes")
    }

    func testPerformImageConversionFailurePath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.modal.errorMessage = nil
        // Not a real image: ImageConverterService.convertImage() will fail to decode it, taking the
        // `catch` branch that calls `showError()`.
        let item = makeItem(named: "not-an-image.png", in: dir, content: "this is plain text, not PNG bytes")

        appState.performImageConversion(item: item, targetFormat: .png, preset: .original, cropPreset: .none, quality: 0.9)

        var errored = false
        for _ in 0 ..< 6 {
            errored = appState.modal.errorMessage != nil
            if errored {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(errored, "performImageConversion() should surface a decode failure via showError() instead of crashing")
    }

    func testPerformBatchRenameSuccessPath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        let itemA = makeItem(named: "a.txt", in: dir)
        let itemB = makeItem(named: "b.txt", in: dir)

        appState.performBatchRename(items: [itemA, itemB], mode: .addPrefixSuffix(prefix: "renamed_", suffix: ""))

        let expectedA = dir.appendingPathComponent("renamed_a.txt")
        let expectedB = dir.appendingPathComponent("renamed_b.txt")
        var bothRenamed = false
        for _ in 0 ..< 6 {
            bothRenamed = FileManager.default.fileExists(atPath: expectedA.path) && FileManager.default.fileExists(atPath: expectedB.path)
            if bothRenamed {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(bothRenamed, "performBatchRename() should rename every item on disk without the caller blocking")
        XCTAssertEqual(
            appState.selection.selectedURLs,
            Set([expectedA, expectedB]),
            "performBatchRename() should select the full set of renamed URLs once the detached Task finishes")
    }

    func testPerformBatchRenameFailurePath() async {
        let dir = makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.modal.errorMessage = nil
        let itemA = makeItem(named: "a.txt", in: dir)
        // A pre-existing file at the rename target makes FileSystemService.renameItem() throw
        // partway through performBatchRename()'s loop, exercising its `catch` -> `showError()` branch.
        _ = makeItem(named: "renamed_a.txt", in: dir)

        appState.performBatchRename(items: [itemA], mode: .addPrefixSuffix(prefix: "renamed_", suffix: ""))

        var errored = false
        for _ in 0 ..< 6 {
            errored = appState.modal.errorMessage != nil
            if errored {
                break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertTrue(errored, "performBatchRename() should surface a rename failure via showError() instead of crashing")
    }
}
