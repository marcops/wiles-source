import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct AppStateCoreTests {
    public static func run() async {
        testAddFavorite()
        testRemoveFavorite()
        testIsFavorite()
        AppStateFavoritesMoveTests.run()
        testMoveSelectedFavorite()
        testTranslucentLevelGetterSetter()
        testSidebarOverlayOpacity()
        testContentOverlayOpacity()
        testGridColumnCount()
        testStatusText()
        testShowError()
        AppStateCoreExtraTests.run()
        testAddSmartFolder()
        testRemoveSmartFolder()
        await testFreeSpaceText()
        testSearchScopeID()
        testStatusTextSelectedDirectoryHasNoSizeSuffix()
        await testCompressSelectedToZIP()
        await testCompressSelectedToZIPFailure()
        await testCompressSelectedToZIPWithPasswordFailure()
        await testExtractArchive()
    }

    private static func makeItem(named name: String, in dir: URL, contents: String = "content", isDirectory: Bool = false) -> FileItem {
        let url = dir.appendingPathComponent(name)
        if isDirectory {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        } else {
            try? contents.write(to: url, atomically: true, encoding: .utf8)
        }
        return FileItem(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    private static func testAddFavorite() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.preferences.favoriteURLs = []
        let target = dir.appendingPathComponent("fav.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)

        appState.addFavorite(target)
        report(
            "AppState",
            "POS: addFavorite() appends a new URL to favoriteURLs",
            result: appState.preferences.favoriteURLs.contains { $0.path == target.standardizedFileURL.path } && appState.preferences.favoriteURLs.count == 1)

        appState.addFavorite(target)
        report("AppState", "NEG: addFavorite() does not add a duplicate for an already-favorited URL", result: appState.preferences.favoriteURLs.count == 1)
    }

    private static func testRemoveFavorite() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let target = dir.appendingPathComponent("removeme.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        appState.preferences.favoriteURLs = [target.standardizedFileURL]

        appState.removeFavorite(target)
        report("AppState", "POS: removeFavorite() removes a previously favorited URL", result: appState.preferences.favoriteURLs.isEmpty)

        appState.preferences.favoriteURLs = [target.standardizedFileURL]
        let other = dir.appendingPathComponent("other.txt")
        try? "x".write(to: other, atomically: true, encoding: .utf8)
        appState.removeFavorite(other)
        report(
            "AppState",
            "NEG: removeFavorite() leaves other favorites untouched when the URL isn't favorited",
            result: appState.preferences.favoriteURLs.count == 1)
    }

    private static func testIsFavorite() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let target = dir.appendingPathComponent("isfav.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        appState.preferences.favoriteURLs = [target.standardizedFileURL]

        report("AppState", "POS: isFavorite() returns true for a URL present in favoriteURLs", result: appState.isFavorite(target) == true)

        let notFav = dir.appendingPathComponent("notfav.txt")
        try? "x".write(to: notFav, atomically: true, encoding: .utf8)
        report("AppState", "NEG: isFavorite() returns false for a URL not present in favoriteURLs", result: appState.isFavorite(notFav) == false)
    }

    private static func testMoveSelectedFavorite() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let favA = dir.appendingPathComponent("A")
        let favB = dir.appendingPathComponent("B")
        let favC = dir.appendingPathComponent("C")
        for url in [favA, favB, favC] {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }

        let appState = AppState()
        appState.preferences.favoriteURLs = [favA, favB, favC]
        appState.navigation.currentURL = favB
        let windowUIState = WindowUIState()
        windowUIState.selectedFavoriteURL = favB

        appState.moveSelectedFavorite(offset: -1, windowUIState: windowUIState)
        report(
            "AppState", "POS: moveSelectedFavorite(-1) swaps the selected favorite with the one before it",
            result: appState.preferences.favoriteURLs == [favB, favA, favC])

        appState.moveSelectedFavorite(offset: 1, windowUIState: windowUIState)
        report(
            "AppState", "POS: moveSelectedFavorite(1) swaps back, restoring original order",
            result: appState.preferences.favoriteURLs == [favA, favB, favC])

        testMoveSelectedFavoriteOutOfBoundsAndStaleSelection(appState: appState, windowUIState: windowUIState, favA: favA, favB: favB, favC: favC)
    }

    private static func testMoveSelectedFavoriteOutOfBoundsAndStaleSelection(
        appState: AppState,
        windowUIState: WindowUIState,
        favA: URL,
        favB: URL,
        favC: URL) {
        // NEG: moving the first favorite up (out of bounds) is a no-op.
        windowUIState.selectedFavoriteURL = favA
        appState.navigation.currentURL = favA
        appState.moveSelectedFavorite(offset: -1, windowUIState: windowUIState)
        report(
            "AppState", "NEG: moveSelectedFavorite(-1) on the first favorite does not change order (out of bounds)",
            result: appState.preferences.favoriteURLs == [favA, favB, favC])

        // NEG: moving the last favorite down (out of bounds) is a no-op.
        windowUIState.selectedFavoriteURL = favC
        appState.navigation.currentURL = favC
        appState.moveSelectedFavorite(offset: 1, windowUIState: windowUIState)
        report(
            "AppState", "NEG: moveSelectedFavorite(1) on the last favorite does not change order (out of bounds)",
            result: appState.preferences.favoriteURLs == [favA, favB, favC])

        // NEG: selectedFavoriteURL no longer matching currentURL (navigated away) blocks the move —
        // this is what stops a stale selection from reordering favorites after the user moved on.
        windowUIState.selectedFavoriteURL = favB
        appState.navigation.currentURL = favC
        appState.moveSelectedFavorite(offset: -1, windowUIState: windowUIState)
        report(
            "AppState", "NEG: moveSelectedFavorite() is a no-op when selectedFavoriteURL doesn't match currentURL",
            result: appState.preferences.favoriteURLs == [favA, favB, favC])

        // NEG: no favorite selected at all.
        windowUIState.selectedFavoriteURL = nil
        appState.moveSelectedFavorite(offset: 1, windowUIState: windowUIState)
        report(
            "AppState", "NEG: moveSelectedFavorite() is a no-op when selectedFavoriteURL is nil",
            result: appState.preferences.favoriteURLs == [favA, favB, favC])
    }

    private static func testTranslucentLevelGetterSetter() {
        let appState = AppState()
        appState.preferences.sidebarTranslucentLevel = 10
        appState.preferences.contentTranslucentLevel = 90
        report("AppState", "POS: translucentLevel getter reflects sidebarTranslucentLevel", result: appState.preferences.translucentLevel == 10)

        appState.preferences.translucentLevel = 55
        report(
            "AppState",
            "POS: translucentLevel setter updates both sidebarTranslucentLevel and contentTranslucentLevel",
            result: appState.preferences.sidebarTranslucentLevel == 55 && appState.preferences.contentTranslucentLevel == 55)

        report(
            "AppState", "NEG: translucentLevel setter does not leave contentTranslucentLevel at its old distinct value",
            result: appState.preferences.contentTranslucentLevel != 90)
    }

    private static func testSidebarOverlayOpacity() {
        let appState = AppState()
        appState.preferences.appAppearance = .dark
        appState.preferences.sidebarTranslucentLevel = 0
        report(
            "AppState",
            "POS: sidebarOverlayOpacity is 1.0 at translucency 0 in dark appearance",
            result: abs(appState.preferences.sidebarOverlayOpacity - 1.0) < 0.0001)

        appState.preferences.appAppearance = .light
        appState.preferences.sidebarTranslucentLevel = 0
        report(
            "AppState", "POS: sidebarOverlayOpacity is halved (0.5) at translucency 0 in light appearance",
            result: abs(appState.preferences.sidebarOverlayOpacity - 0.5) < 0.0001)

        appState.preferences.appAppearance = .dark
        appState.preferences.sidebarTranslucentLevel = 100
        report(
            "AppState",
            "NEG: sidebarOverlayOpacity is 0 at translucency 100, not still 1.0",
            result: abs(appState.preferences.sidebarOverlayOpacity - 0.0) < 0.0001)
    }

    private static func testContentOverlayOpacity() {
        let appState = AppState()
        appState.preferences.appAppearance = .dark
        appState.preferences.contentTranslucentLevel = 40
        report(
            "AppState",
            "POS: contentOverlayOpacity computes 1 - level/100 in dark appearance",
            result: abs(appState.preferences.contentOverlayOpacity - 0.6) < 0.0001)

        appState.preferences.appAppearance = .light
        appState.preferences.contentTranslucentLevel = 40
        report(
            "AppState",
            "NEG: contentOverlayOpacity in light mode is not equal to the unhalved dark-mode value",
            result: abs(appState.preferences.contentOverlayOpacity - 0.6) > 0.0001 && abs(appState.preferences.contentOverlayOpacity - 0.3) < 0.0001)
    }

    private static func testGridColumnCount() {
        let appState = AppState()
        appState.selection.gridCellFrames = [:]
        report("AppState", "NEG: gridColumnCount is 1 when there are 0 or 1 cell frames", result: appState.selection.gridColumnCount == 1)

        let urlA = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("a-\(UUID().uuidString)")
        let urlB = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("b-\(UUID().uuidString)")
        let urlC = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("c-\(UUID().uuidString)")
        appState.selection.gridCellFrames = [
            urlA: CGRect(x: 0, y: 0, width: 50, height: 50),
            urlB: CGRect(x: 60, y: 0, width: 50, height: 50),
            urlC: CGRect(x: 0, y: 60, width: 50, height: 50)
        ]
        report("AppState", "POS: gridColumnCount counts cells sharing the same top row Y (within tolerance)", result: appState.selection.gridColumnCount == 2)
    }

    private static func testStatusText() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir, contents: "hello")
        let itemB = makeItem(named: "b.txt", in: dir, contents: "world!!")
        appState.fileSystem.items = [itemA, itemB]
        appState.selectedURLs = []
        report(
            "AppState",
            "POS: statusText with no selection shows total item count and formatted size",
            result: appState.statusText.hasPrefix("2 ") && appState.statusText.contains("("))

        appState.selectedURLs = [itemA.url]
        report("AppState", "POS: statusText with a selection shows 'selected / total'", result: appState.statusText.hasPrefix("1 / 2"))

        let appState2 = AppState()
        appState2.fileSystem.items = []
        appState2.selectedURLs = []
        report(
            "AppState",
            "NEG: statusText with zero items omits the size suffix in parentheses",
            result: appState2.statusText == "0 item" || appState2.statusText == "0 itens")
    }

    private static func testShowError() {
        let appState = AppState()
        appState.modal.errorMessage = nil
        appState.modal.showErrorAlert = false

        appState.showError("Something failed")
        report(
            "AppState",
            "POS: showError() sets errorMessage and flips showErrorAlert to true",
            result: appState.modal.errorMessage == "Something failed" && appState.modal.showErrorAlert == true)

        report("AppState", "NEG: showError() does not leave showErrorAlert false", result: appState.modal.showErrorAlert != false)
    }

    private static func testAddSmartFolder() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        appState.smartFolders = []
        let folder = SmartFolder(name: "My Folder", searchQuery: "report", scopePath: "/tmp")

        appState.addSmartFolder(folder)
        report(
            "AppState",
            "POS: addSmartFolder() appends the folder to smartFolders",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == folder.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report("AppState", "POS: addSmartFolder() persists the folder via SmartFolderService", result: persisted.contains { $0.id == folder.id })

        let other = SmartFolder(name: "Other", searchQuery: "x", scopePath: "/tmp")
        report(
            "AppState",
            "NEG: addSmartFolder() does not add an unrelated folder that was never added",
            result: appState.smartFolders.contains { $0.id == other.id } == false)
    }

    private static func testRemoveSmartFolder() {
        let priorDefaultsData = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue)
        defer {
            if let priorDefaultsData {
                UserDefaults.standard.set(priorDefaultsData, forKey: DefaultsKey.smartFolders.rawValue)
            } else {
                UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)
            }
        }

        let appState = AppState()
        let keep = SmartFolder(name: "Keep", searchQuery: "a", scopePath: "/tmp")
        let removeTarget = SmartFolder(name: "Remove", searchQuery: "b", scopePath: "/tmp")
        appState.smartFolders = [keep, removeTarget]

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "POS: removeSmartFolder() removes only the matching folder by id",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report(
            "AppState",
            "POS: removeSmartFolder() persists the updated list without the removed folder",
            result: persisted.contains { $0.id == removeTarget.id } == false)

        appState.removeSmartFolder(removeTarget)
        report(
            "AppState",
            "NEG: removeSmartFolder() is a no-op when the folder is already absent",
            result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)
    }

    private static func testFreeSpaceText() async {
        let appState = AppState()
        appState.navigation.currentURL = FileManager.default.homeDirectoryForCurrentUser
        let validText = await appState.loadFreeSpaceText()
        report("AppState", "POS: loadFreeSpaceText() returns a non-nil formatted string for a valid, resolvable directory", result: validText != nil)

        let bogus = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/deeper/path")
        appState.navigation.currentURL = bogus
        let bogusText = await appState.loadFreeSpaceText()
        report("AppState", "NEG: loadFreeSpaceText() is nil when volumeAvailableCapacity can't be resolved for the URL", result: bogusText == nil)
    }

    private static func testSearchScopeID() {
        report(
            "AppState", "POS: SearchScope.id returns the case's rawValue for both cases",
            result: SearchScope.name.id == "name" && SearchScope.content.id == "content")
    }

    private static func testStatusTextSelectedDirectoryHasNoSizeSuffix() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let dirItem = makeItem(named: "subdir", in: dir, isDirectory: true)
        appState.fileSystem.items = [dirItem]
        appState.selectedURLs = [dirItem.url]
        report(
            "AppState",
            "NEG: statusText with a selected directory (zero file size) omits the parenthesized size suffix",
            result: appState.statusText == "1 / 1")
    }

    private static func testCompressSelectedToZIP() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.selectedURLs = []
        appState.compressSelectedToZIP()
        try? await Task.sleep(nanoseconds: 150_000_000)
        let contentsAfterEmptySelection = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        report("AppState", "NEG: compressSelectedToZIP() with an empty selection creates no archive", result: contentsAfterEmptySelection.isEmpty)

        let fileURL = dir.appendingPathComponent("toZip.txt")
        try? "content".write(to: fileURL, atomically: true, encoding: .utf8)
        appState.selectedURLs = [fileURL]
        appState.compressSelectedToZIP()

        let expectedZip = dir.appendingPathComponent("toZip.zip")
        let zipExists = await waitUntil { FileManager.default.fileExists(atPath: expectedZip.path) }
        report(
            "AppState", "POS: compressSelectedToZIP() creates a zip archive of the selected item in the current directory",
            result: zipExists)
    }

    private static func testCompressSelectedToZIPFailure() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // ditto -c (the single-file, no-password path compressSelectedToZIP() always takes) silently
        // creates any missing destination directory itself, so a missing destination folder can't be
        // used to force a failure here. A source URL that isn't backed by a real file on disk is what
        // actually makes ditto fail ("Cannot get the real path for source").
        let nonExistentSource = dir.appendingPathComponent("does-not-exist-\(UUID().uuidString).txt")

        let appState = AppState()
        appState.navigation.currentURL = dir
        appState.selectedURLs = [nonExistentSource]
        appState.modal.errorMessage = nil
        appState.compressSelectedToZIP()

        let gotError = await waitUntil { appState.modal.errorMessage != nil }
        report(
            "AppState",
            "NEG: compressSelectedToZIP() surfaces an error via showError() when the selected source doesn't exist on disk",
            result: gotError)
    }

    private static func testCompressSelectedToZIPWithPasswordFailure() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("source.txt")
        try? "x".write(to: fileURL, atomically: true, encoding: .utf8)
        let missingDestDir = dir.appendingPathComponent("missing-\(UUID().uuidString)")

        let appState = AppState()
        appState.navigation.currentURL = missingDestDir
        appState.modal.errorMessage = nil
        appState.compressSelectedToZIPWithPassword("hunter2", urls: [fileURL])

        let gotError = await waitUntil { appState.modal.errorMessage != nil }
        report(
            "AppState",
            "NEG: compressSelectedToZIPWithPassword() surfaces an error via showError() when the destination folder doesn't exist",
            result: gotError)
    }

    private static func testExtractArchive() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceFile = dir.appendingPathComponent("payload.txt")
        try? "payload".write(to: sourceFile, atomically: true, encoding: .utf8)
        let zipURL = dir.appendingPathComponent("payload.zip")
        try? ArchiveService.compressToZIP(urls: [sourceFile], in: dir)

        let extractDir = dir.appendingPathComponent("extracted")
        try? FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let appState = AppState()
        appState.navigation.currentURL = extractDir
        appState.modal.errorMessage = nil
        appState.extractArchive(url: zipURL)

        let expectedExtractedFile = extractDir.appendingPathComponent("payload.txt")
        let extracted = await waitUntil { FileManager.default.fileExists(atPath: expectedExtractedFile.path) }
        report("AppState", "POS: extractArchive() extracts the archive's contents into the current directory", result: extracted)

        appState.modal.errorMessage = nil
        let bogusZip = dir.appendingPathComponent("not-a-real-archive-\(UUID().uuidString).zip")
        appState.extractArchive(url: bogusZip)

        let gotError = await waitUntil { appState.modal.errorMessage != nil }
        report(
            "AppState", "NEG: extractArchive() with a nonexistent archive URL surfaces an error via showError()",
            result: gotError)
    }

    /// Polls `condition` every 100ms (up to `iterations` times) so tests exercising a fire-and-forget
    /// `Task.detached` in `AppState` (compress/extract) don't need to hand-roll a wait loop each time.
    private static func waitUntil(iterations: Int = 8, _ condition: () -> Bool) async -> Bool {
        for _ in 0 ..< iterations {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if condition() {
                return true
            }
        }
        return false
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
