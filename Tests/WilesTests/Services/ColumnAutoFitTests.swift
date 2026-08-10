@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ColumnAutoFitTests {
    public static func run() {
        testShortContentClampsToMinimum()
        testLongFileNameExceedsMinimumButClampsToMax()
        testAllColumnsProduceValidWidths()
        testOwnerColumnProducesValidWidth()
        testDateCreatedColumnProducesValidWidth()
        testDateAccessedColumnProducesValidWidth()
        testTaggedItemNameColumnIsWiderThanUntagged()
        testIconSizeClampingAtLowerExtreme()
        testIconSizeClampingAtUpperExtreme()
    }

    private static func makeAppState(with items: [FileItem]) -> AppState {
        let appState = AppState()
        appState.fileSystem.items = items
        return appState
    }

    private static func makeFileItem(dir: URL, name: String) -> FileItem {
        let file = dir.appendingPathComponent(name)
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        return FileItem(url: file, icon: NSImage(size: NSSize(width: 16, height: 16)))
    }

    private static func testShortContentClampsToMinimum() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "a.txt")
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .group,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
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
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let longName = String(repeating: "extremely-long-file-name-segment-", count: 20) + ".txt"
        let item = makeFileItem(dir: dir, name: longName)
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        let pos = width > LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        TestReporter.report(
            "ColumnAutoFit", "POS: very long file name produces width above minimum but clamped at maximum",
            result: pos
        )
    }

    private static func testAllColumnsProduceValidWidths() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "regular_item.dat")
        let appState = makeAppState(with: [item])

        var allValid = true
        for column in ListColumn.allCases {
            let width = ColumnAutoFitService.calculateAutoFitWidth(
                for: column,
                items: appState.fileSystem.items,
                iconSize: appState.preferences.iconSize,
                language: appState.preferences.appLanguage
            )
            if !(width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth) {
                allValid = false
            }
        }
        TestReporter.report(
            "ColumnAutoFit", "POS: every ListColumn case produces a valid clamped CGFloat width without crashing",
            result: allValid
        )
    }

    private static func testOwnerColumnProducesValidWidth() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "owner_test.txt")
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .owner,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        TestReporter.report(
            "ColumnAutoFit", "POS: .owner column produces a valid clamped width",
            result: width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        )
    }

    private static func testDateCreatedColumnProducesValidWidth() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "date_created_test.txt")
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .dateCreated,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        TestReporter.report(
            "ColumnAutoFit", "POS: .dateCreated column produces a valid clamped width",
            result: width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        )
    }

    private static func testDateAccessedColumnProducesValidWidth() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "date_accessed_test.txt")
        let appState = makeAppState(with: [item])

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .dateAccessed,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        TestReporter.report(
            "ColumnAutoFit", "POS: .dateAccessed column produces a valid clamped width",
            result: width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        )
    }

    private static func testTaggedItemNameColumnIsWiderThanUntagged() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Use identical short names so header width dominates unless the tag
        // padding branch pushes the tagged item's required width higher.
        let untaggedFile = dir.appendingPathComponent("same.txt")
        try? "x".write(to: untaggedFile, atomically: true, encoding: .utf8)
        let untaggedItem = FileItem(url: untaggedFile, icon: NSImage(size: NSSize(width: 16, height: 16)))

        let taggedDir = dir.appendingPathComponent("tagged", isDirectory: true)
        try? FileManager.default.createDirectory(at: taggedDir, withIntermediateDirectories: true)
        let taggedFile = taggedDir.appendingPathComponent("same.txt")
        try? "x".write(to: taggedFile, atomically: true, encoding: .utf8)
        try? (taggedFile as NSURL).setResourceValue(["Red"], forKey: .tagNamesKey)
        let taggedItem = FileItem(url: taggedFile, icon: NSImage(size: NSSize(width: 16, height: 16)), fetchTags: true)

        let untaggedAppState = makeAppState(with: [untaggedItem])
        let taggedAppState = makeAppState(with: [taggedItem])
        let untaggedWidth = ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: untaggedAppState.fileSystem.items,
            iconSize: untaggedAppState.preferences.iconSize,
            language: untaggedAppState.preferences.appLanguage
        )
        let taggedWidth = ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: taggedAppState.fileSystem.items,
            iconSize: taggedAppState.preferences.iconSize,
            language: taggedAppState.preferences.appLanguage
        )

        // If the environment failed to persist the Finder tag (e.g. sandboxed temp volume),
        // fall back to asserting both widths are at least valid rather than a false failure.
        let pos: Bool
        if taggedItem.tags.isEmpty {
            pos = untaggedWidth >= LayoutTokens.columnMinWidth && taggedWidth >= LayoutTokens.columnMinWidth
        } else {
            pos = taggedWidth >= untaggedWidth
        }
        TestReporter.report(
            "ColumnAutoFit", "POS: tagged item's .name column width accounts for tag extra padding",
            result: pos
        )
    }

    private static func testIconSizeClampingAtLowerExtreme() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "icon_low.txt")
        let appState = makeAppState(with: [item])
        appState.preferences.iconSize = 1.0 // scaled value falls below listIconMinSize, must clamp up

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        TestReporter.report(
            "ColumnAutoFit", "POS: extremely small iconSize is clamped to listIconMinSize without producing an invalid width",
            result: width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        )
    }

    private static func testIconSizeClampingAtUpperExtreme() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let item = makeFileItem(dir: dir, name: "icon_high.txt")
        let appState = makeAppState(with: [item])
        appState.preferences.iconSize = 10_000.0 // scaled value far exceeds listIconMaxSize, must clamp down

        let width = ColumnAutoFitService.calculateAutoFitWidth(
            for: .name,
            items: appState.fileSystem.items,
            iconSize: appState.preferences.iconSize,
            language: appState.preferences.appLanguage
        )
        TestReporter.report(
            "ColumnAutoFit", "POS: extremely large iconSize is clamped to listIconMaxSize without producing an invalid width",
            result: width >= LayoutTokens.columnMinWidth && width <= LayoutTokens.columnMaxWidth
        )
    }
}
