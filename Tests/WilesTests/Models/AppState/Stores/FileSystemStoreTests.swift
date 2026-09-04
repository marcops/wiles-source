import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileSystemStoreTests {
    public static func run() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: FileSystemStore items initially empty", result: store.items.isEmpty)
        report("Store/FileSystemStore", "POS: FileSystemStore isLoading initially false", result: !store.isLoading)

        testTotalFileSizeBytesTracksItemsAssignment()
        testItemsByURLIndexTracksItemsAssignment()
        testIndexByURLTracksItemsAssignment()
        testBatchStreamingDefersDerivedRebuildUntilSettled()
        testOverlappingStreamsKeepRebuildDeferredUntilAllSettle()
        testIsStreamingBatchesReflectsBeginEndDepth()
        testStopDirectoryMonitoringClearsAndAllowsReWiring()
    }

    /// MM-177: `stopDirectoryMonitoring()` (used while "search everywhere" is active) must clear
    /// `monitoredURL` so a later `startDirectoryMonitoring(for:)` for the *same* folder actually
    /// re-wires — the `guard std != monitoredURL` fast-path would otherwise silently skip it.
    private static func testStopDirectoryMonitoringClearsAndAllowsReWiring() {
        let store = FileSystemStore()
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let std = dir.standardizedFileURL

        report("Store/FileSystemStore", "NEG (MM-177): monitoredURL nil before monitoring", result: store.monitoredURL == nil)

        store.startDirectoryMonitoring(for: dir) { }
        report("Store/FileSystemStore", "POS (MM-177): startDirectoryMonitoring sets monitoredURL", result: store.monitoredURL == std)

        store.stopDirectoryMonitoring()
        report("Store/FileSystemStore", "POS (MM-177): stopDirectoryMonitoring clears monitoredURL", result: store.monitoredURL == nil)

        // A no-op when already stopped.
        store.stopDirectoryMonitoring()
        report("Store/FileSystemStore", "POS (MM-177): stopDirectoryMonitoring is idempotent", result: store.monitoredURL == nil)

        // Re-wiring the same folder now takes effect (would be skipped if stop hadn't cleared it).
        store.startDirectoryMonitoring(for: dir) { }
        report("Store/FileSystemStore", "POS (MM-177): the same folder can be re-monitored after a stop", result: store.monitoredURL == std)

        store.tearDown()
    }

    /// LP-040: `ResetPaginationAndPrefetchThumbnails` gates its ~8×/s prefetch on
    /// `isStreamingBatches` — so this flag must be `true` for the whole crawl (any nesting depth)
    /// and back to `false` only once every stream has ended.
    private static func testIsStreamingBatchesReflectsBeginEndDepth() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "NEG: isStreamingBatches is false with no stream open", result: !store.isStreamingBatches)

        store.beginBatchStreaming()
        report("Store/FileSystemStore", "POS: isStreamingBatches is true while a stream is open", result: store.isStreamingBatches)

        store.beginBatchStreaming()
        store.endBatchStreaming()
        report(
            "Store/FileSystemStore",
            "POS: isStreamingBatches stays true while an outer stream is still open (nesting)",
            result: store.isStreamingBatches)

        store.endBatchStreaming()
        report(
            "Store/FileSystemStore",
            "POS: isStreamingBatches returns to false once every stream has ended (prefetch can run — LP-040)",
            result: !store.isStreamingBatches)
    }

    /// A superseded crawl's `endBatchStreaming()` must not re-enable per-batch rebuilds while a
    /// newer crawl is still streaming.
    private static func testOverlappingStreamsKeepRebuildDeferredUntilAllSettle() {
        let store = FileSystemStore()
        let itemA = makeItem(name: "a.txt", size: 10, isDirectory: false)
        let itemB = makeItem(name: "b.txt", size: 20, isDirectory: false)

        store.beginBatchStreaming()
        store.beginBatchStreaming()
        store.endBatchStreaming()

        store.items = [itemA, itemB]
        report(
            "Store/FileSystemStore",
            "NEG: an outer stream still open keeps mid-batch assignments from rebuilding derived indexes",
            result: store.totalFileSizeBytes == 0 && store.itemsByURL.isEmpty)

        store.endBatchStreaming()
        report(
            "Store/FileSystemStore",
            "POS: the final endBatchStreaming() rebuilds every derived index once",
            result: store.totalFileSizeBytes == 30 && store.indexByURL[itemB.url] == 1)
    }

    /// B3-4: while streaming cumulative recursive-search batches, `items` assignments must NOT rebuild
    /// the derived indexes on each batch — only `endBatchStreaming()` rebuilds them once.
    private static func testBatchStreamingDefersDerivedRebuildUntilSettled() {
        let store = FileSystemStore()
        let itemA = makeItem(name: "a.txt", size: 10, isDirectory: false)
        let itemB = makeItem(name: "b.txt", size: 20, isDirectory: false)
        store.items = [itemA]

        store.beginBatchStreaming()
        store.items = [itemA, itemB]
        report(
            "Store/FileSystemStore",
            "NEG: mid-stream batch assignment leaves derived indexes stale",
            result: store.totalFileSizeBytes == 10 && store.itemsByURL[itemB.url] == nil && store.indexByURL[itemB.url] == nil)

        store.endBatchStreaming()
        report(
            "Store/FileSystemStore",
            "POS: endBatchStreaming() rebuilds every derived index once from the final list",
            result: store.totalFileSizeBytes == 30 && store.itemsByURL[itemB.url]?.name == "b.txt" && store.indexByURL[itemB.url] == 1)

        store.items = [itemA]
        report(
            "Store/FileSystemStore",
            "POS: after streaming ends, a plain assignment rebuilds derived indexes again",
            result: store.totalFileSizeBytes == 10 && store.itemsByURL[itemB.url] == nil)
    }

    private static func testIndexByURLTracksItemsAssignment() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: indexByURL starts empty", result: store.indexByURL.isEmpty)

        let itemA = makeItem(name: "a.txt", size: 1, isDirectory: false)
        let itemB = makeItem(name: "b.txt", size: 2, isDirectory: false)
        let itemC = makeItem(name: "c.txt", size: 3, isDirectory: false)
        store.items = [itemA, itemB, itemC]
        report(
            "Store/FileSystemStore",
            "POS: assigning items builds a URL -> position index matching array order",
            result: store.indexByURL[itemA.url] == 0 && store.indexByURL[itemB.url] == 1 && store.indexByURL[itemC.url] == 2)

        store.items = [itemC, itemA]
        report(
            "Store/FileSystemStore",
            "POS: reordering items rebuilds indexByURL positions and drops stale keys",
            result: store.indexByURL[itemC.url] == 0 && store.indexByURL[itemA.url] == 1 && store.indexByURL[itemB.url] == nil)

        store.items = []
        report("Store/FileSystemStore", "POS: clearing items empties indexByURL", result: store.indexByURL.isEmpty)
    }

    private static func testItemsByURLIndexTracksItemsAssignment() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: itemsByURL starts empty", result: store.itemsByURL.isEmpty)

        let itemA = makeItem(name: "a.txt", size: 1, isDirectory: false)
        let itemB = makeItem(name: "b.txt", size: 2, isDirectory: false)
        store.items = [itemA, itemB]
        report(
            "Store/FileSystemStore",
            "POS: assigning items builds a URL -> item index matching every entry",
            result: store.itemsByURL.count == 2 && store.itemsByURL[itemA.url]?.name == "a.txt" && store.itemsByURL[itemB.url]?.name == "b.txt")

        store.items = [makeItem(name: "c.txt", size: 3, isDirectory: false)]
        report(
            "Store/FileSystemStore",
            "POS: reassigning items rebuilds itemsByURL and drops stale keys",
            result: store.itemsByURL.count == 1 && store.itemsByURL[itemA.url] == nil)

        store.items = []
        report("Store/FileSystemStore", "POS: clearing items empties itemsByURL", result: store.itemsByURL.isEmpty)
    }

    private static func makeItem(name: String, size: Int64, isDirectory: Bool) -> FileItem {
        FileItem(
            url: URL(fileURLWithPath: "/tmp/\(name)"), name: name, isDirectory: isDirectory, size: size,
            dateModified: Date(timeIntervalSinceReferenceDate: 0), dateCreated: Date(timeIntervalSinceReferenceDate: 0),
            dateAccessed: nil, ownerName: "--", groupName: "--", isHidden: false, fileExtension: "",
            icon: NSImage(), tags: [], tagColor: nil, isUbiquitous: false,
            isUbiquitousNotDownloaded: false, isUbiquitousDownloading: false, isUbiquitousUploading: false)
    }

    private static func testTotalFileSizeBytesTracksItemsAssignment() {
        let store = FileSystemStore()
        report("Store/FileSystemStore", "POS: totalFileSizeBytes starts at 0", result: store.totalFileSizeBytes == 0)

        store.items = [makeItem(name: "a.txt", size: 100, isDirectory: false), makeItem(name: "b.txt", size: 250, isDirectory: false)]
        report(
            "Store/FileSystemStore",
            "POS: assigning items sets totalFileSizeBytes to the sum of non-directory sizes",
            result: store.totalFileSizeBytes == 350)

        store.items = [makeItem(name: "a.txt", size: 100, isDirectory: false), makeItem(name: "sub", size: 999, isDirectory: true)]
        report("Store/FileSystemStore", "NEG: directory items do not contribute to totalFileSizeBytes", result: store.totalFileSizeBytes == 100)

        store.items = [makeItem(name: "c.txt", size: 42, isDirectory: false)]
        report("Store/FileSystemStore", "POS: reassigning items recomputes totalFileSizeBytes", result: store.totalFileSizeBytes == 42)

        store.items = []
        report("Store/FileSystemStore", "POS: clearing items resets totalFileSizeBytes to 0", result: store.totalFileSizeBytes == 0)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
