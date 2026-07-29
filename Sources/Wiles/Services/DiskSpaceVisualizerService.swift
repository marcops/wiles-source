import Foundation
import AppKit

public struct DiskUsageItem: Identifiable, Sendable {
    public var id: URL { url }
    public let url: URL
    let name: String
    public let size: Int64
    public let formattedSize: String
    public let percentage: Double
    public let isDirectory: Bool
    public let colorHue: Double
    
    public init(url: URL, name: String, size: Int64, percentage: Double, isDirectory: Bool, colorHue: Double) {
        self.url = url
        self.name = name
        self.size = size
        self.formattedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        self.percentage = percentage
        self.isDirectory = isDirectory
        self.colorHue = colorHue
    }
}

public struct DiskUsageReport: Sendable {
    public let totalSize: Int64
    public let formattedTotalSize: String
    public let topItems: [DiskUsageItem]
    public let othersItem: DiskUsageItem?
    
    public init(totalSize: Int64, topItems: [DiskUsageItem], othersItem: DiskUsageItem?) {
        self.totalSize = totalSize
        self.formattedTotalSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        self.topItems = topItems
        self.othersItem = othersItem
    }
}

public final class DiskSpaceVisualizerService {
    public static func calculateDiskUsage(for folderURL: URL) async -> DiskUsageReport {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else {
                return DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
            }
            
            var rawItems: [(url: URL, name: String, size: Int64, isDir: Bool)] = []
            
            for itemURL in contents {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: itemURL.path, isDirectory: &isDir) {
                    let size: Int64
                    if isDir.boolValue {
                        size = computeFolderSizeFast(folderURL: itemURL)
                    } else {
                        let values = try? itemURL.resourceValues(forKeys: [.fileSizeKey])
                        size = Int64(values?.fileSize ?? 0)
                    }
                    rawItems.append((url: itemURL, name: itemURL.lastPathComponent, size: size, isDir: isDir.boolValue))
                }
            }
            
            let grandTotal = rawItems.reduce(0) { $0 + $1.size }
            guard grandTotal > 0 else {
                return DiskUsageReport(totalSize: 0, topItems: [], othersItem: nil)
            }
            
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
            
            var othersItem: DiskUsageItem? = nil
            if !othersSlice.isEmpty {
                let othersTotalSize = othersSlice.reduce(0) { $0 + $1.size }
                let pct = (Double(othersTotalSize) / Double(grandTotal)) * 100.0
                let dummyURL = folderURL.appendingPathComponent("Others (\(othersSlice.count))")
                othersItem = DiskUsageItem(url: dummyURL, name: "Others (\(othersSlice.count) items)", size: othersTotalSize, percentage: pct, isDirectory: true, colorHue: 0.0)
            }
            
            return DiskUsageReport(totalSize: grandTotal, topItems: formattedTopItems, othersItem: othersItem)
        }.value
    }
    
    private static func computeFolderSizeFast(folderURL: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return 0
        }
        var total: Int64 = 0
        var count = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let s = values.fileSize {
                total += Int64(s)
            }
            count += 1
            if count > 5000 { break } // Performance cap guardrail
        }
        return total
    }
}
