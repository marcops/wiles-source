@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct AppStateCoreTests {
    public static func run() {
        testAddFavorite()
        testRemoveFavorite()
        testIsFavorite()
        testTranslucentLevelGetterSetter()
        testSidebarOverlayOpacity()
        testContentOverlayOpacity()
        testGridColumnCount()
        testStatusText()
        testShowError()
        testAddSmartFolder()
        testRemoveSmartFolder()
        testFreeSpaceText()
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
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.favoriteURLs = []
        let target = dir.appendingPathComponent("fav.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)

        appState.addFavorite(target)
        report("AppState", "POS: addFavorite() appends a new URL to favoriteURLs", result: appState.favoriteURLs.contains { $0.path == target.standardizedFileURL.path } && appState.favoriteURLs.count == 1)

        appState.addFavorite(target)
        report("AppState", "NEG: addFavorite() does not add a duplicate for an already-favorited URL", result: appState.favoriteURLs.count == 1)
    }

    private static func testRemoveFavorite() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let target = dir.appendingPathComponent("removeme.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        appState.favoriteURLs = [target.standardizedFileURL]

        appState.removeFavorite(target)
        report("AppState", "POS: removeFavorite() removes a previously favorited URL", result: appState.favoriteURLs.isEmpty)

        appState.favoriteURLs = [target.standardizedFileURL]
        let other = dir.appendingPathComponent("other.txt")
        try? "x".write(to: other, atomically: true, encoding: .utf8)
        appState.removeFavorite(other)
        report("AppState", "NEG: removeFavorite() leaves other favorites untouched when the URL isn't favorited", result: appState.favoriteURLs.count == 1)
    }

    private static func testIsFavorite() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let target = dir.appendingPathComponent("isfav.txt")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        appState.favoriteURLs = [target.standardizedFileURL]

        report("AppState", "POS: isFavorite() returns true for a URL present in favoriteURLs", result: appState.isFavorite(target) == true)

        let notFav = dir.appendingPathComponent("notfav.txt")
        try? "x".write(to: notFav, atomically: true, encoding: .utf8)
        report("AppState", "NEG: isFavorite() returns false for a URL not present in favoriteURLs", result: appState.isFavorite(notFav) == false)
    }

    private static func testTranslucentLevelGetterSetter() {
        let appState = AppState()
        appState.sidebarTranslucentLevel = 10
        appState.contentTranslucentLevel = 90
        report("AppState", "POS: translucentLevel getter reflects sidebarTranslucentLevel", result: appState.translucentLevel == 10)

        appState.translucentLevel = 55
        report("AppState", "POS: translucentLevel setter updates both sidebarTranslucentLevel and contentTranslucentLevel", result: appState.sidebarTranslucentLevel == 55 && appState.contentTranslucentLevel == 55)

        report("AppState", "NEG: translucentLevel setter does not leave contentTranslucentLevel at its old distinct value", result: appState.contentTranslucentLevel != 90)
    }

    private static func testSidebarOverlayOpacity() {
        let appState = AppState()
        appState.appAppearance = .dark
        appState.sidebarTranslucentLevel = 0
        report("AppState", "POS: sidebarOverlayOpacity is 1.0 at translucency 0 in dark appearance", result: abs(appState.sidebarOverlayOpacity - 1.0) < 0.0001)

        appState.appAppearance = .light
        appState.sidebarTranslucentLevel = 0
        report("AppState", "POS: sidebarOverlayOpacity is halved (0.5) at translucency 0 in light appearance", result: abs(appState.sidebarOverlayOpacity - 0.5) < 0.0001)

        appState.appAppearance = .dark
        appState.sidebarTranslucentLevel = 100
        report("AppState", "NEG: sidebarOverlayOpacity is 0 at translucency 100, not still 1.0", result: abs(appState.sidebarOverlayOpacity - 0.0) < 0.0001)
    }

    private static func testContentOverlayOpacity() {
        let appState = AppState()
        appState.appAppearance = .dark
        appState.contentTranslucentLevel = 40
        report("AppState", "POS: contentOverlayOpacity computes 1 - level/100 in dark appearance", result: abs(appState.contentOverlayOpacity - 0.6) < 0.0001)

        appState.appAppearance = .light
        appState.contentTranslucentLevel = 40
        report("AppState", "NEG: contentOverlayOpacity in light mode is not equal to the unhalved dark-mode value", result: abs(appState.contentOverlayOpacity - 0.6) > 0.0001 && abs(appState.contentOverlayOpacity - 0.3) < 0.0001)
    }

    private static func testGridColumnCount() {
        let appState = AppState()
        appState.gridCellFrames = [:]
        report("AppState", "NEG: gridColumnCount is 1 when there are 0 or 1 cell frames", result: appState.gridColumnCount == 1)

        let urlA = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("a-\(UUID().uuidString)")
        let urlB = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("b-\(UUID().uuidString)")
        let urlC = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("c-\(UUID().uuidString)")
        appState.gridCellFrames = [
            urlA: CGRect(x: 0, y: 0, width: 50, height: 50),
            urlB: CGRect(x: 60, y: 0, width: 50, height: 50),
            urlC: CGRect(x: 0, y: 60, width: 50, height: 50)
        ]
        report("AppState", "POS: gridColumnCount counts cells sharing the same top row Y (within tolerance)", result: appState.gridColumnCount == 2)
    }

    private static func testStatusText() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir, contents: "hello")
        let itemB = makeItem(named: "b.txt", in: dir, contents: "world!!")
        appState.items = [itemA, itemB]
        appState.selectedURLs = []
        report("AppState", "POS: statusText with no selection shows total item count and formatted size", result: appState.statusText.hasPrefix("2 ") && appState.statusText.contains("("))

        appState.selectedURLs = [itemA.url]
        report("AppState", "POS: statusText with a selection shows 'selected / total'", result: appState.statusText.hasPrefix("1 / 2"))

        let appState2 = AppState()
        appState2.items = []
        appState2.selectedURLs = []
        report("AppState", "NEG: statusText with zero items omits the size suffix in parentheses", result: appState2.statusText == "0 item" || appState2.statusText == "0 itens")
    }

    private static func testShowError() {
        let appState = AppState()
        appState.errorMessage = nil
        appState.showErrorAlert = false

        appState.showError("Something failed")
        report("AppState", "POS: showError() sets errorMessage and flips showErrorAlert to true", result: appState.errorMessage == "Something failed" && appState.showErrorAlert == true)

        report("AppState", "NEG: showError() does not leave showErrorAlert false", result: appState.showErrorAlert != false)
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
        report("AppState", "POS: addSmartFolder() appends the folder to smartFolders", result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == folder.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report("AppState", "POS: addSmartFolder() persists the folder via SmartFolderService", result: persisted.contains { $0.id == folder.id })

        let other = SmartFolder(name: "Other", searchQuery: "x", scopePath: "/tmp")
        report("AppState", "NEG: addSmartFolder() does not add an unrelated folder that was never added", result: appState.smartFolders.contains { $0.id == other.id } == false)
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
        report("AppState", "POS: removeSmartFolder() removes only the matching folder by id", result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)

        let persisted = SmartFolderService.loadSavedSmartFolders()
        report("AppState", "POS: removeSmartFolder() persists the updated list without the removed folder", result: persisted.contains { $0.id == removeTarget.id } == false)

        appState.removeSmartFolder(removeTarget)
        report("AppState", "NEG: removeSmartFolder() is a no-op when the folder is already absent", result: appState.smartFolders.count == 1 && appState.smartFolders.first?.id == keep.id)
    }

    private static func testFreeSpaceText() {
        let appState = AppState()
        appState.currentURL = FileManager.default.homeDirectoryForCurrentUser
        report("AppState", "POS: freeSpaceText returns a non-nil formatted string for a valid, resolvable directory", result: appState.freeSpaceText != nil)

        let bogus = URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)/deeper/path")
        appState.currentURL = bogus
        report("AppState", "NEG: freeSpaceText is nil when volumeAvailableCapacity can't be resolved for the URL", result: appState.freeSpaceText == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
