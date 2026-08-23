import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct StateAndTaskModelsTests {
    public static func run() {
        testWilesErrorRemainingCases()
        testClipboardStateBeyondIsCut()
        testFileOperationTaskState()
        testDirectoryCacheEntryAndLoadResult()
        testDuplicateGroupReclaimableBytes()
    }

    // MARK: - WilesError (cases not already covered in MiscModelTests)

    private static func testWilesErrorRemainingCases() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let busyPath = dir.appendingPathComponent("busy-file.txt").path

        let fileInUse = WilesError.fileInUse(path: busyPath)
        report("WilesError", "POS: fileInUse description includes the offending path", result: (fileInUse.errorDescription ?? "").contains(busyPath))
        report("WilesError", "NEG: fileInUse description is not a generic placeholder", result: (fileInUse.errorDescription ?? "") != "File in Use")

        let missingPath = dir.appendingPathComponent("missing-file.txt").path
        let notFound = WilesError.itemNotFound(path: missingPath)
        report("WilesError", "POS: itemNotFound description includes the offending path", result: (notFound.errorDescription ?? "").contains(missingPath))

        // Sanity: every case has a non-empty description.
        let allCases: [WilesError] = [
            .permissionDenied(path: busyPath),
            .diskFull(path: busyPath),
            .fileInUse(path: busyPath),
            .itemNotFound(path: busyPath),
            .operationFailed(reason: "disk unmounted"),
            .invalidZipPassword
        ]
        let allNonEmpty = allCases.allSatisfy { !($0.errorDescription ?? "").isEmpty }
        report("WilesError", "POS: every WilesError case produces a non-empty errorDescription", result: allNonEmpty)

        // NEG: distinct associated values on the same case are not equal.
        report(
            "WilesError",
            "NEG: itemNotFound with different paths is not equal",
            result: WilesError.itemNotFound(path: busyPath) != WilesError.itemNotFound(path: missingPath))
    }

    // MARK: - ClipboardState (beyond isCut)

    private static func testClipboardStateBeyondIsCut() {
        let tempBase = URL(fileURLWithPath: testTemporaryDirectory())
        let raw = tempBase.appendingPathComponent("Clip-\(UUID().uuidString)")
        // Deliberately construct a non-standardized URL (trailing slash quirks etc.) to
        // exercise the standardizedFileURL normalization performed in init.
        let messy = URL(fileURLWithPath: raw.path + "/./")

        let state = ClipboardState(urls: [messy], action: .cut)
        report(
            "ClipboardState",
            "POS: init standardizes stored URLs so equivalent messy paths match",
            result: state.urls.first?.path == raw.standardizedFileURL.path)

        let empty = ClipboardState(urls: [], action: .cut)
        report("ClipboardState", "NEG: an empty clipboard is never isCut for any URL", result: !empty.isCut(url: raw))

        let multi = ClipboardState(urls: [raw, tempBase.appendingPathComponent("other-\(UUID().uuidString)")], action: .cut)
        report("ClipboardState", "POS: isCut(url:) is true for any URL among multiple cut URLs", result: multi.isCut(url: raw))

        report("ClipboardState", "POS: action is preserved as given (.copy)", result: ClipboardState(urls: [raw], action: .copy).action == .copy)
    }

    // MARK: - FileOperationTask

    private static func testFileOperationTaskState() {
        var task = FileOperationTask(title: "Copying files", totalBytes: 1000)
        report("FileOperationTask", "POS: default progress starts at 0", result: task.progress == 0.0)

        task.bytesTransferred = 250
        report("FileOperationTask", "POS: progress derives from bytesTransferred/totalBytes", result: abs(task.progress - 0.25) < 0.0001)

        let idBefore = task.id
        task.bytesTransferred = 900
        report("FileOperationTask", "NEG: mutating bytesTransferred does not change identity (id)", result: task.id == idBefore)

        let generated1 = FileOperationTask(title: "A")
        let generated2 = FileOperationTask(title: "A")
        report("FileOperationTask", "NEG: two tasks with the same title get distinct auto-generated ids", result: generated1.id != generated2.id)
    }

    // MARK: - DirectoryCacheEntry / DirectoryLoadResult

    private static func testDirectoryCacheEntryAndLoadResult() {
        let emptyResult = DirectoryLoadResult(items: [])
        report("DirectoryLoadResult", "POS: holds the items passed in", result: emptyResult.items.isEmpty)

        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fileURL = dir.appendingPathComponent("item.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("hello".utf8))
        let item = FileItem(url: fileURL, icon: NSImage())
        let populated = DirectoryLoadResult(items: [item])
        report("DirectoryLoadResult", "POS: items are preserved as passed in", result: populated.items.count == 1 && populated.items.first?.url == item.url)

        let entryBefore = Date()
        let entry = DirectoryCacheEntry(result: populated)
        let entryAfter = Date()
        report(
            "DirectoryCacheEntry",
            "POS: timestamp is stamped at construction time (between before/after)",
            result: entry.timestamp >= entryBefore && entry.timestamp <= entryAfter)
        report("DirectoryCacheEntry", "POS: stored result is the one passed to init", result: entry.result.items.count == 1)

        // Constructing a second entry slightly later should have a timestamp >= the first,
        // exercising that timestamp actually reflects real elapsed time rather than being fixed.
        Thread.sleep(forTimeInterval: 0.01)
        let laterEntry = DirectoryCacheEntry(result: emptyResult)
        report("DirectoryCacheEntry", "POS: later-constructed entry has a timestamp >= earlier entry's", result: laterEntry.timestamp >= entry.timestamp)
    }

    // MARK: - DuplicateGroup

    private static func testDuplicateGroupReclaimableBytes() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        func makeItem(_ name: String) -> FileItem {
            let url = dir.appendingPathComponent(name)
            FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
            return FileItem(url: url, icon: NSImage())
        }

        let singleItemGroup = DuplicateGroup(hash: "abc", fileSize: 500, items: [makeItem("a.txt")])
        report(
            "DuplicateGroup",
            "NEG: reclaimableBytes is 0 when the group has only a single item (nothing to reclaim)",
            result: singleItemGroup.reclaimableBytes == 0)

        let emptyGroup = DuplicateGroup(hash: "def", fileSize: 500, items: [])
        report("DuplicateGroup", "NEG: reclaimableBytes is 0 when the group has no items", result: emptyGroup.reclaimableBytes == 0)

        let threeItemGroup = DuplicateGroup(hash: "ghi", fileSize: 500, items: [makeItem("b.txt"), makeItem("c.txt"), makeItem("d.txt")])
        report("DuplicateGroup", "POS: reclaimableBytes is fileSize * (count - 1) for a group of 3 duplicates", result: threeItemGroup.reclaimableBytes == 1000)

        report("DuplicateGroup", "POS: id is derived from hash", result: threeItemGroup.id == "ghi")

        let scanResult = DuplicateScanResult(groups: [singleItemGroup, threeItemGroup], totalReclaimableBytes: threeItemGroup.reclaimableBytes)
        report(
            "DuplicateScanResult",
            "POS: totalReclaimableBytes reflects sum passed in, ignoring the zero-reclaim single-item group",
            result: scanResult.totalReclaimableBytes == 1000)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
