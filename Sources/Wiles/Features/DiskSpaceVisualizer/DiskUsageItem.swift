import Foundation

public struct DiskUsageItem: Identifiable, Sendable {
    public var id: URL {
        url
    }

    public let url: URL
    let name: String
    public let size: Int64
    public let formattedSize: String
    public let percentage: Double
    public let isDirectory: Bool
    public let colorHue: Double
    /// The aggregated "Others (N)" row — its `url` is a placeholder that doesn't exist on disk, so
    /// it must never be navigated to.
    public let isSynthetic: Bool

    public init(url: URL, name: String, size: Int64, percentage: Double, isDirectory: Bool, colorHue: Double, isSynthetic: Bool = false) {
        self.url = url
        self.name = name
        self.size = size
        formattedSize = ByteFormat.fileSize(size)
        self.percentage = percentage
        self.isDirectory = isDirectory
        self.colorHue = colorHue
        self.isSynthetic = isSynthetic
    }
}
