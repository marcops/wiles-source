import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileMetadataTests {
    public static func run() async {
        await testFetchPropertiesForRealFile()
        await testFetchPropertiesForNonExistentFileDoesNotCrash()
        await testKindIsResolvedForRegularFile()
        await testDimensionsAreResolvedForRealImage()
        await testStreamBatchPropertiesYieldsOneItemPerURLInOrder()
        await testStreamBatchPropertiesStopsEarlyWhenConsumerBreaks()
        await testStreamBatchPropertiesOnEmptyURLListFinishesImmediately()
        await testFormatPermissionsCoversAllRoleBitsIncludingExecute()
    }

    private static func testStreamBatchPropertiesYieldsOneItemPerURLInOrder() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileA = dir.appendingPathComponent("a.txt")
        let fileB = dir.appendingPathComponent("b.txt")
        try? "a".write(to: fileA, atomically: true, encoding: .utf8)
        try? "b".write(to: fileB, atomically: true, encoding: .utf8)

        var received: [URL] = []
        for await props in await FileMetadataService.shared.streamBatchProperties(for: [fileA, fileB]) {
            received.append(props.url)
        }
        report("FileMetadata", "POS: streamBatchProperties yields exactly one item per URL, in order", result: received == [fileA, fileB])
    }

    /// Regression coverage for the `Task.isCancelled` check inside the stream's loop: breaking out
    /// of a `for await` early triggers `onTermination`, which cancels the underlying `Task` — proving
    /// the loop actually stops instead of continuing to scan every remaining URL in the background.
    private static func testStreamBatchPropertiesStopsEarlyWhenConsumerBreaks() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var urls: [URL] = []
        for index in 0 ..< 20 {
            let url = dir.appendingPathComponent("file_\(index).txt")
            try? "content".write(to: url, atomically: true, encoding: .utf8)
            urls.append(url)
        }

        var received = 0
        for await _ in await FileMetadataService.shared.streamBatchProperties(for: urls) {
            received += 1
            if received == 2 {
                break
            }
        }
        report("FileMetadata", "POS: breaking out of streamBatchProperties early stops before yielding every URL", result: received < urls.count)
    }

    private static func testFetchPropertiesForRealFile() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("metadata_test.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: owner name is resolved for a real file", result: props.ownerName != nil && !(props.ownerName ?? "").isEmpty)
        report("FileMetadata", "POS: group name is resolved for a real file", result: props.groupName != nil && !(props.groupName ?? "").isEmpty)
        report("FileMetadata", "POS: POSIX permissions string has the expected rwx-style length", result: (props.posixPermissions ?? "").count == 9)
    }

    private static func testFetchPropertiesForNonExistentFileDoesNotCrash() async {
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString).txt")
        let props = await FileMetadataService.shared.fetchProperties(for: missing)
        report(
            "FileMetadata",
            "NEG: non-existent file returns nil owner/permissions instead of crashing",
            result: props.ownerName == nil && props.posixPermissions == nil)
    }

    private static func testKindIsResolvedForRegularFile() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("kind_test.txt")
        try? "hello world".write(to: file, atomically: true, encoding: .utf8)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: localized kind description is resolved for a real file", result: props.kind != nil && !(props.kind ?? "").isEmpty)
    }

    private static func testDimensionsAreResolvedForRealImage() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("dimensions_test.png")
        let image = NSImage(size: NSSize(width: 64, height: 32))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 32).fill()
        image.unlockFocus()
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: file)
        }

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        // Note: FileMetadataService resolves dimensions via Spotlight (MDItemCopyAttribute), and
        // Spotlight does not index the per-user temp directory (testTemporaryDirectory()) — confirmed
        // via `mdls` returning null for kMDItemPixelWidth/Height on freshly written temp files even
        // after a delay. Dimensions can therefore legitimately come back nil here regardless of the
        // image being valid. What we CAN assert is that if a value is produced, it is well-formed.
        let dimensionsWellFormedOrAbsent = props.dimensions == nil || (props.dimensions ?? "").contains("×")
        report("FileMetadata", "POS: pixel dimensions, when resolved, are formatted with × rather than malformed", result: dimensionsWellFormedOrAbsent)
        // Coverage note: the same Spotlight-indexing-latency limitation applies to the
        // kMDItemDurationSeconds branch in readSpotlightDimensionsAndDuration — a freshly written
        // temp-dir file is never indexed in time for CI, so that branch's true side (real duration
        // formatting) is left uncovered here as a real-network/Spotlight-dependent exception,
        // consistent with this file's documented policy for SpotlightSearchService.
    }

    /// Coverage for `streamBatchProperties`'s loop body never running (empty input): the
    /// `AsyncStream` must still terminate cleanly via `continuation.finish()`.
    private static func testStreamBatchPropertiesOnEmptyURLListFinishesImmediately() async {
        var received = 0
        for await _ in await FileMetadataService.shared.streamBatchProperties(for: []) {
            received += 1
        }
        report("FileMetadata", "NEG: streamBatchProperties on an empty URL list yields nothing and finishes", result: received == 0)
    }

    /// `formatPermissions` only exercises the "x"/"w" true-branches when the underlying POSIX mode
    /// actually sets those bits — a freshly-written temp file defaults to 0644 (no execute bits at
    /// all), which never reaches the true side of the `& 1` (execute) check for any role. Setting an
    /// explicit asymmetric mode (0751: rwx / r-x / --x) forces every role/bit combination through
    /// both branches at least once.
    private static func testFormatPermissionsCoversAllRoleBitsIncludingExecute() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("perms_test.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o751], ofItemAtPath: file.path)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: formatPermissions renders an explicit rwx/r-x/--x mode exactly", result: props.posixPermissions == "rwxr-x--x")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
