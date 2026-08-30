import AppKit
import Foundation

public enum DiskSpaceVisualizerService {
    /// Guardrail: stop enumerating a folder's contents after this many files to keep scans fast.
    private static let maxScannedFileCount = 5000

    /// At most this many largest items get their own chart slice; the rest fold into "Others".
    private static let maxTopItems = 10

    /// Distinct, well-spaced hues (0...1) assigned round-robin to the top items so adjacent slices
    /// stay visually separable. Count matches `maxTopItems`.
    private static let sliceHues = [0.60, 0.38, 0.08, 0.85, 0.50, 0.15, 0.75, 0.95, 0.28, 0.45]

    /// Hue for the synthetic "Others" slice.
    private static let othersSliceHue = 0.0

    private struct RawItem {
        let url: URL
        let name: String
        let size: Int64
        let isDir: Bool
        let wasTruncated: Bool
    }

    public static func calculateDiskUsage(for folderURL: URL, language: AppLanguage = .system) async throws -> DiskUsageReport {
        // `.task(id:)` cancellation on the calling side does NOT automatically cancel a
        // `Task.detached` — detached tasks are unlinked from their creator, so the scan
        // would otherwise become a zombie that keeps recursively walking a folder the user
        // already navigated away from. `withTaskCancellationHandler` explicitly forwards
        // cancellation to the detached task, and the detached task now throws
        // `CancellationError` promptly instead of running to completion.
        let scanTask = Task.detached(priority: .userInitiated) { () throws -> DiskUsageReport in
            let fm = FileManager.default
            // A read failure here (no access to the folder) must surface, not read as "0 bytes".
            let contents = try fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                options: [.skipsHiddenFiles])

            let rawItems = try collectRawItems(in: contents, fm: fm)
            let grandTotal = rawItems.reduce(0) { $0 + $1.size }
            guard grandTotal > 0 else {
                return DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
            }

            let isApproximate = rawItems.contains { $0.wasTruncated }
            return buildReport(
                from: rawItems, grandTotal: grandTotal, folderURL: folderURL,
                isApproximate: isApproximate, language: language)
        }

        return try await withTaskCancellationHandler {
            try await scanTask.value
        } onCancel: {
            scanTask.cancel()
        }
    }

    private static func collectRawItems(in contents: [URL], fm _: FileManager) throws -> [RawItem] {
        var rawItems: [RawItem] = []
        for itemURL in contents {
            try Task.checkCancellation()
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let size: Int64
            var wasTruncated = false
            if isDir {
                (size, wasTruncated) = try computeFolderSizeFast(folderURL: itemURL)
            } else {
                let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey])
                size = Int64(values?.fileSize ?? 0)
            }
            rawItems.append(RawItem(url: itemURL, name: itemURL.lastPathComponent, size: size, isDir: isDir, wasTruncated: wasTruncated))
        }
        return rawItems
    }

    private static func buildReport(
        from rawItems: [RawItem], grandTotal: Int64, folderURL: URL,
        isApproximate: Bool, language: AppLanguage) -> DiskUsageReport {
        let sorted = rawItems.sorted { $0.size > $1.size }
        let topSlice = sorted.prefix(maxTopItems)
        let othersSlice = sorted.dropFirst(maxTopItems)

        var formattedTopItems: [DiskUsageItem] = []

        for (index, item) in topSlice.enumerated() {
            let pct = (Double(item.size) / Double(grandTotal)) * 100.0
            let hue = sliceHues[index % sliceHues.count]
            formattedTopItems.append(DiskUsageItem(url: item.url, name: item.name, size: item.size, percentage: pct, isDirectory: item.isDir, colorHue: hue))
        }

        var othersItem: DiskUsageItem?
        if !othersSlice.isEmpty {
            let othersTotalSize = othersSlice.reduce(0) { $0 + $1.size }
            let pct = (Double(othersTotalSize) / Double(grandTotal)) * 100.0
            let dummyURL = folderURL.appendingPathComponent("Others (\(othersSlice.count))")
            othersItem = DiskUsageItem(
                url: dummyURL,
                name: String(format: L10n.string(.diskUsageOthersItemsFormat, lang: language), othersSlice.count),
                size: othersTotalSize,
                percentage: pct,
                isDirectory: true,
                colorHue: othersSliceHue,
                isSynthetic: true)
        }

        return DiskUsageReport(totalSize: grandTotal, topItems: formattedTopItems, othersItem: othersItem, isApproximate: isApproximate)
    }

    private static func computeFolderSizeFast(folderURL: URL) throws -> (total: Int64, wasTruncated: Bool) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            // Skip an unreadable subdirectory instead of aborting the whole walk (→ undercounted
            // folder size shown as exact). R1 / BA-509.
            errorHandler: { _, _ in true })
        else {
            return (0, false)
        }
        var total: Int64 = 0
        var count = 0
        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let fileSize = values.fileSize {
                total += Int64(fileSize)
            }
            count += 1
            if count > maxScannedFileCount {
                return (total, true)
            }
        }
        return (total, false)
    }
}
