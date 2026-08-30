import AppKit
import Foundation
@testable import Wiles

/// Continuation of `AppStateCoreTests` — split out purely to stay under SwiftLint's 500-line
/// file-length limit (see `AppStateOperationsExtraTests`/`AppStateOperationsFailureTests` for the
/// same precedent). Still the same dedicated suite for `AppState.swift`; `run()` here is called
/// alongside the main file's `run()`.
@MainActor
public struct AppStateCoreExtraTests {
    public static func run() {
        testShowErrorWithErrorType()
        testStatusTextResultsTruncatedNotice()
        testSelectedFileSizeBytesCaching()
    }

    /// Regression coverage for the "moved a folder to the folder it's already in" bug report,
    /// where the raw NSError message was shown untranslated to every user regardless of language.
    private static func testShowErrorWithErrorType() {
        let appState = AppState()

        appState.modal.errorMessage = nil
        appState.showError(WilesError.itemAlreadyInDestination)
        TestReporter.report(
            "AppState",
            "POS: showError(Error) localizes WilesError.itemAlreadyInDestination via appState.tr(...)",
            result: appState.modal.errorMessage == appState.tr(.itemAlreadyInDestination))

        appState.modal.errorMessage = nil
        struct SomeOtherError: LocalizedError { var errorDescription: String? {
            "some other failure"
        } }
        appState.showError(SomeOtherError())
        TestReporter.report(
            "AppState",
            "NEG: showError(Error) falls back to localizedDescription for a non-WilesError",
            result: appState.modal.errorMessage == "some other failure")
    }

    /// B5-2 / B9-2: a capped search / smart-folder result set appends a "showing the first N" clause
    /// to statusText so it isn't read as the complete match set. A plain load clears the flag.
    private static func testStatusTextResultsTruncatedNotice() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        appState.fileSystem.items = [makeItem(named: "a.txt", in: dir)]
        appState.selection.selectedURLs = []

        appState.fileSystem.resultsTruncated = false
        let plain = appState.statusText
        TestReporter.report(
            "AppState",
            "NEG: statusText has no truncation clause when resultsTruncated is false",
            result: !plain.contains(String(format: appState.tr(.resultsTruncatedNotice), 1)))

        appState.fileSystem.resultsTruncated = true
        TestReporter.report(
            "AppState",
            "POS: statusText appends the localized truncation notice when resultsTruncated is true",
            result: appState.statusText.hasPrefix(plain)
                && appState.statusText.contains(String(format: appState.tr(.resultsTruncatedNotice), 1)))
    }

    /// B3b-3: the selected-size total is summed from the (small) selection set via `itemsByURL`,
    /// cached on `SelectionStore`, and invalidated when the selection changes.
    private static func testSelectedFileSizeBytesCaching() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let appState = AppState()
        let itemA = makeItem(named: "a.txt", in: dir, contents: "12345")
        let itemB = makeItem(named: "b.txt", in: dir, contents: "1234567890")
        appState.fileSystem.items = [itemA, itemB]

        appState.selection.selectedURLs = [itemA.url]
        TestReporter.report(
            "AppState",
            "POS: selectedFileSizeBytes sums only the selected item's size",
            result: appState.selectedFileSizeBytes == itemA.size && appState.selection.cachedSelectedFileSizeBytes == itemA.size)

        appState.selection.selectedURLs = [itemA.url, itemB.url]
        TestReporter.report(
            "AppState",
            "POS: changing the selection invalidates the cache and re-sums",
            result: appState.selectedFileSizeBytes == itemA.size + itemB.size)
    }

    private static func makeItem(named name: String, in dir: URL, contents: String = "content") -> FileItem {
        let url = dir.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return FileItem.load(url: url, icon: NSWorkspace.shared.icon(forFile: url.path))
    }
}
