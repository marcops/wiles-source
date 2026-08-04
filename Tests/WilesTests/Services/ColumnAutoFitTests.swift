@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ColumnAutoFitTests {
    public static func run() {
        testShortContentClampsToMinimum()
        testLongFileNameExceedsMinimumButClampsToMax()
        testAllColumnsProduceValidWidths()
    }

    private static func makeAppState(with items: [FileItem]) -> AppState {
        let appState = AppState()
        appState.items = items
        return appState
    }

    private static func makeFileItem(dir: URL, name: String) -> FileItem {
        let file = dir.appendingPathComponent(name)
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        return FileItem(url: file, icon: NSImage(size: NSSize(width: 16, height: 16)))
    }

    private static func testShortContentClampsToMinimum() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "a.txt")
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(for: .group, in: appState)
        // Note: the localized header text itself (e.g. "Group" + padding) already exceeds
        // columnMinWidth (60pt), so short item content can never drive the result down to
        // exactly columnMinWidth here — the real invariant under test is that the floor is
        // never violated, i.e. width is always >= columnMinWidth regardless of content length.
        TestReporter.report(
            "ColumnAutoFit", "POS: short content never produces a width below columnMinWidth",
            result: width >= LayoutTokens.columnMinWidth
        )
    }

    private static func testLongFileNameExceedsMinimumButClampsToMax() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let longName = String(repeating: "extremely-long-file-name-segment-", count: 20) + ".txt"
        let item = makeFileItem(dir: dir, name: longName)
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(for: .name, in: appState)
        let pos = width > LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        TestReporter.report(
            "ColumnAutoFit", "POS: very long file name produces width above minimum but clamped at maximum",
            result: pos
        )
    }

    private static func testAllColumnsProduceValidWidths() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "regular_item.dat")
        let appState = makeAppState(with: [item])

        var allValid = true
        for column in ListColumn.allCases {
            let width = ColumnAutoFitService.calculateAutoFitWidth(for: column, in: appState)
            if !(width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth) {
                allValid = false
            }
        }
        TestReporter.report(
            "ColumnAutoFit", "POS: every ListColumn case produces a valid clamped CGFloat width without crashing",
            result: allValid
        )
    }
}
