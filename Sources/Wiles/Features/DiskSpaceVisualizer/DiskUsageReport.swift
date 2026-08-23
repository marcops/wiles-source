import Foundation

public struct DiskUsageReport: Sendable {
    public let totalSize: Int64
    public let formattedTotalSize: String
    public let topItems: [DiskUsageItem]
    public let othersItem: DiskUsageItem?
    /// True if a subfolder scan hit `maxScannedFileCount` — `totalSize` is then a lower bound, not exact.
    public let isApproximate: Bool

    public init(totalSize: Int64, topItems: [DiskUsageItem], othersItem: DiskUsageItem?, isApproximate: Bool = false) {
        self.totalSize = totalSize
        formattedTotalSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        self.topItems = topItems
        self.othersItem = othersItem
        self.isApproximate = isApproximate
    }
}
