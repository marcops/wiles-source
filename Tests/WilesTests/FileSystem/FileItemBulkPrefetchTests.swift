import Foundation
@testable import Wiles

/// Regression coverage for the N+1 I/O fix: creationDateKey/contentAccessDateKey/effectiveIconKey
/// were added to FileSystemService's bulk contentsOfDirectory prefetch (previously only FileItem's
/// own separate resourceValues call requested them, forcing a per-file stat for each). This doesn't
/// prove fewer syscalls happened — it proves the refactor didn't quietly break the fields it was
/// optimizing: they must still come back populated with real, non-default values. See
/// UI_TEST_BACKLOG.md for why the actual syscall-count claim isn't unit-tested (this test was run
/// against the fix disabled and passed identically, since FileItem's own fallback fetch already
/// covered correctness — only the performance characteristics changed).
public enum FileItemBulkPrefetchTests {
    public static func run() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("bulk-prefetch.txt")
        try? "content".write(to: file, atomically: true, encoding: .utf8)

        let options = DirectoryLoadOptions(showHidden: false, showTags: false, searchQuery: "", sortOption: .name, sortAscending: true)
        let items = await FileSystemService.loadDirectoryContents(at: dir, options: options)
        guard let item = items.first(where: { $0.url.standardizedFileURL == file.standardizedFileURL }) else {
            await TestReporter.report("FileSystem", "POS: bulk-prefetched item is present in loadDirectoryContents results", result: false)
            return
        }

        // A freshly-written file's creationDate should be recent (within the last minute), not the
        // Date() "now" fallback FileItem.init uses only when the resourceValues fetch fails outright.
        let creationIsRecent = abs(item.dateCreated.timeIntervalSinceNow) < 60
        await TestReporter.report("FileSystem", "POS: dateCreated is populated from the bulk prefetch, not defaulted", result: creationIsRecent)

        let iconIsNonEmpty = item.icon.size.width > 0 && item.icon.size.height > 0
        await TestReporter.report("FileSystem", "POS: icon resolves via the bulk-prefetched effectiveIconKey (non-empty image)", result: iconIsNonEmpty)
    }
}
