@testable import Wiles
import Foundation

/// Regression coverage for the shared function double-click funnels through in every view mode
/// (Grid/List/Column all call `appState.navigateTo(item.url)` on double-click — see
/// `FileGridView.swift`, `FileListView.swift`, `FileColumnView.swift`). The actual gesture wiring
/// that decides *whether* a double-click fires isn't unit-testable (it depends on live AppKit
/// event/gesture-recognizer competition, not pure logic), but the branch it calls into —
/// `completeNavigation`'s `guard isDirectory else { NSWorkspace.shared.open(url); return }` — is,
/// and a regression there (e.g. misclassifying a file as a directory) would silently break
/// double-click-to-open everywhere at once.
@MainActor
public struct AppStateNavigateToFileTests {
    public static func run() {
        let appState = AppState()
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("NavFileTest_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Extension with no registered app, so NSWorkspace.shared.open(url) is a safe no-op here
        // instead of actually launching an editor during the test run.
        let fileURL = tempDir.appendingPathComponent("sample.wilesnohandlertest")
        try? "content".write(to: fileURL, atomically: true, encoding: .utf8)

        appState.navigateTo(tempDir)
        let currentURLBeforeFileOpen = appState.navigation.currentURL
        let historyCountBeforeFileOpen = appState.navigation.historyBack.count
        appState.selectedURLs = [fileURL]

        appState.navigateTo(fileURL)

        TestReporter.report(
            "Navigation/OpenFile",
            "POS: navigateTo() on a non-directory file does not change currentURL (opens instead of navigating into it)",
            result: appState.navigation.currentURL.standardizedFileURL == currentURLBeforeFileOpen.standardizedFileURL
        )
        TestReporter.report(
            "Navigation/OpenFile",
            "POS: navigateTo() on a non-directory file does not push a history entry",
            result: appState.navigation.historyBack.count == historyCountBeforeFileOpen
        )
        TestReporter.report(
            "Navigation/OpenFile",
            "POS: navigateTo() on a non-directory file does not clear the current selection",
            result: appState.selectedURLs == [fileURL]
        )
    }
}
