import Foundation
import AppKit

public final class DiskSpaceVisualizerService {
    /// Guardrail: stop enumerating a folder's contents after this many files to keep scans fast.
    private static let maxScannedFileCount = 5000

    private struct RawItem {
        let url: URL
        let name: String
        let size: Int64
        let isDir: Bool
    }

    public static func calculateDiskUsage(for folderURL: URL) async -> DiskUsageReport {
        // `.task(id:)` cancellation on the calling side does NOT automatically cancel a
        // `Task.detached` — detached tasks are unlinked from their creator, so the scan
        // would otherwise become a zombie that keeps recursively walking a folder the user
        // already navigated away from. `withTaskCancellationHandler` explicitly forwards
        // cancellation to the detached task, and the detached task now throws
        // `CancellationError` promptly instead of running to completion.
        let scanTask = Task.detached(priority: .userInitiated) { () throws -> DiskUsageReport in
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
                return DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
            }

            let rawItems = try collectRawItems(in: contents, fm: fm)
            let grandTotal = rawItems.reduce(0) { $0 + $1.size }
            guard grandTotal > 0 else {
                return DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
            }

            return buildReport(from: rawItems, grandTotal: grandTotal, folderURL: folderURL)
        }

        return await withTaskCancellationHandler {
            (try? await scanTask.value) ?? DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
        } onCancel: {
            scanTask.cancel()
        }
    }

    private static func collectRawItems(in contents: [URL], fm: FileManager) throws -> [RawItem] {
        var rawItems: [RawItem] = []
        for itemURL in contents {
            try Task.checkCancellation()
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let size: Int64
            if isDir {
                size = try computeFolderSizeFast(folderURL: itemURL)
            } else {
                let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey])
                size = Int64(values?.fileSize ?? 0)
            }
            rawItems.append(RawItem(url: itemURL, name: itemURL.lastPathComponent, size: size, isDir: isDir))
        }
        return rawItems
    }

    private static func buildReport(from rawItems: [RawItem], grandTotal: Int64, folderURL: URL) -> DiskUsageReport {
        let sorted = rawItems.sorted { $0.size > $1.size }
        let maxTop = 10
        let topSlice = sorted.prefix(maxTop)
        let othersSlice = sorted.dropFirst(maxTop)

        var formattedTopItems: [DiskUsageItem] = []
        let hues = [0.60, 0.38, 0.08, 0.85, 0.50, 0.15, 0.75, 0.95, 0.28, 0.45]

        for (index, item) in topSlice.enumerated() {
            let pct = (Double(item.size) / Double(grandTotal)) * 100.0
            let hue = hues[index % hues.count]
            formattedTopItems.append(DiskUsageItem(url: item.url, name: item.name, size: item.size, percentage: pct, isDirectory: item.isDir, colorHue: hue))
        }

        var othersItem: DiskUsageItem?
        if !othersSlice.isEmpty {
            let othersTotalSize = othersSlice.reduce(0) { $0 + $1.size }
            let pct = (Double(othersTotalSize) / Double(grandTotal)) * 100.0
            let dummyURL = folderURL.appendingPathComponent("Others (\(othersSlice.count))")
            othersItem = DiskUsageItem(url: dummyURL, name: "Others (\(othersSlice.count) items)", size: othersTotalSize, percentage: pct, isDirectory: true, colorHue: 0.0)
        }

        return DiskUsageReport(totalSize: grandTotal, topItems: formattedTopItems, othersItem: othersItem)
    }

    private static func computeFolderSizeFast(folderURL: URL) throws -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        var total: Int64 = 0
        var count = 0
        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
                total += Int64(fileSize)
            }
            count += 1
            if count > maxScannedFileCount { break }
        }
        return total
    }
}
