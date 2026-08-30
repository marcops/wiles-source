import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileSystemRecursiveSearchTests {
    public static func run() async {
        await testRecursiveSearchFindsNestedMatchingFiles()
        await testRecursiveSearchExcludesHiddenByDefault()
        await testRecursiveSearchIncludesHiddenWhenRequested()
        await testRecursiveSearchExcludesNonMatchingFiles()
        await testRecursiveSearchInvokesOnBatchMidWalk()
        await testRecursiveSearchCapsAtResultLimit()
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("FileSystem/SearchAndSort", name, result: result)
    }

    // MARK: - loadRecursiveSearchResults

    // Not covered here, documented rather than silently skipped (see WILES_RULES.md's
    // "100% is a target, not a floor"):
    // - `makeRecursiveSearchEnumerator`'s `guard let enumerator = ... else { throw }` branch
    //   (FileSystemService.swift ~L177-186): `FileManager.enumerator(at:)` was verified (both with a
    //   nonexistent file URL and a non-file `https://` URL) to never actually return nil on macOS —
    //   this is a defensive branch with no known reachable trigger, not a real code path to exercise.
    // - The three `if Task.isCancelled { break }` checks (L30, L97, L192): `loadRecursiveSearchResults`
    //   wraps the walk in `Task.detached`, which is NOT a child of the caller's Task, so cancelling the
    //   caller's Task has no way to reach the detached Task's cancellation flag — structurally
    //   unreachable through the public API.
    // - `URL.userTrash`'s `?? URL(fileURLWithPath: ...)` fallback (L8): only used if
    //   `FileManager.default.urls(for: .trashDirectory, ...)` returns empty, which does not happen on
    //   a normal macOS user account (dev machine and CI both have a real Trash).

    private final class BatchCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [[FileItem]] = []
        func append(_ batch: [FileItem]) {
            lock.lock()
            storage.append(batch)
            lock.unlock()
        }

        var batches: [[FileItem]] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }
    }

    private static func recursiveSearchResults(
        at root: URL, query: String = "", includeHidden: Bool = false, showTags: Bool = false) async -> [[FileItem]] {
        let collector = BatchCollector()
        try? await FileSystemService.loadRecursiveSearchResults(
            at: root,
            options: DirectoryLoadOptions(showHidden: true, showTags: showTags, searchQuery: query, sortOption: .name, sortAscending: true),
            includeHidden: includeHidden,
            onBatch: { batch in collector.append(batch) })
        return collector.batches
    }

    private static func testRecursiveSearchFindsNestedMatchingFiles() async {
        let dir = tempDir()
        let nested = dir.appendingPathComponent("nested/deeper")
        try? FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("top_target.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: nested.appendingPathComponent("deep_target.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: nested.appendingPathComponent("unrelated.txt"), atomically: true, encoding: .utf8)

        let batches = await recursiveSearchResults(at: dir, query: "target")
        let names = Set(batches.last?.map(\.name) ?? [])
        report("POS: loadRecursiveSearchResults walks nested subfolders and matches by name", result: names == ["top_target.txt", "deep_target.txt"])
    }

    private static func testRecursiveSearchExcludesHiddenByDefault() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent(".hidden_target.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("visible_target.txt"), atomically: true, encoding: .utf8)

        let batches = await recursiveSearchResults(at: dir, query: "target", includeHidden: false)
        let names = batches.last?.map(\.name) ?? []
        report("NEG: loadRecursiveSearchResults excludes dotfiles when includeHidden is false", result: names == ["visible_target.txt"])
    }

    private static func testRecursiveSearchIncludesHiddenWhenRequested() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent(".hidden_target.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("visible_target.txt"), atomically: true, encoding: .utf8)

        let batches = await recursiveSearchResults(at: dir, query: "target", includeHidden: true)
        let names = Set(batches.last?.map(\.name) ?? [])
        report("POS: loadRecursiveSearchResults includes dotfiles when includeHidden is true", result: names == [".hidden_target.txt", "visible_target.txt"])
    }

    private static func testRecursiveSearchExcludesNonMatchingFiles() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("keep_me.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("skip_this.txt"), atomically: true, encoding: .utf8)

        let batches = await recursiveSearchResults(at: dir, query: "keep")
        let names = batches.last?.map(\.name) ?? []
        report("NEG: loadRecursiveSearchResults omits files whose name doesn't match the query", result: names == ["keep_me.txt"])
    }

    /// With several matches, `onBatch` fires at least twice — once immediately on the first match
    /// (so results stream in fast) and once more with the final full set.
    private static func testRecursiveSearchInvokesOnBatchMidWalk() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileCount = 45
        for index in 0 ..< fileCount {
            try? "x".write(to: dir.appendingPathComponent("batch_target_\(index).txt"), atomically: true, encoding: .utf8)
        }

        let batches = await recursiveSearchResults(at: dir, query: "batch_target")
        report(
            "POS: loadRecursiveSearchResults streams results — onBatch fires more than once, final call has every match",
            result: batches.count > 1 && batches.last?.count == fileCount)
    }

    /// Creates more matching files than `FileSystemService.recursiveSearchResultLimit` (2000) to prove the
    /// walk stops early instead of growing the result list without bound.
    private static func testRecursiveSearchCapsAtResultLimit() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileCount = FileSystemService.recursiveSearchResultLimit + 5
        for index in 0 ..< fileCount {
            try? Data().write(to: dir.appendingPathComponent("limit_target_\(index).bin"))
        }

        let batches = await recursiveSearchResults(at: dir, query: "limit_target")
        report(
            "POS: loadRecursiveSearchResults caps results at recursiveSearchResultLimit instead of matching every file",
            result: batches.last?.count == FileSystemService.recursiveSearchResultLimit)
    }
}
