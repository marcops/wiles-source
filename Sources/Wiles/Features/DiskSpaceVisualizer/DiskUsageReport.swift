import Foundation

public struct DiskUsageReport: Sendable {
    public let totalSize: Int64
    public let formattedTotalSize: String
    public let topItems: [DiskUsageItem]
    public let othersItem: DiskUsageItem?

    public init(totalSize: Int64, topItems: [DiskUsageItem], othersItem: DiskUsageItem?) {
        self.totalSize = totalSize
        formattedTotalSize = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        self.topItems = topItems
        self.othersItem = othersItem
    }
}
