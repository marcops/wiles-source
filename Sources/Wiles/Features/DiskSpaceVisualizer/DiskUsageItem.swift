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

    public init(url: URL, name: String, size: Int64, percentage: Double, isDirectory: Bool, colorHue: Double) {
        self.url = url
        self.name = name
        self.size = size
        formattedSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        self.percentage = percentage
        self.isDirectory = isDirectory
        self.colorHue = colorHue
    }
}
