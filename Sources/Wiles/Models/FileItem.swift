import Foundation
import AppKit

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let dateModified: Date
    public let isHidden: Bool
    public let fileExtension: String
    public let icon: NSImage
    public let tags: [String]
    public let tagColor: NSColor?

    public init(url: URL, icon: NSImage, fetchTags: Bool = false) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.icon = icon
        
        var keys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
        if fetchTags {
            keys.insert(.tagNamesKey)
            keys.insert(.labelColorKey)
        }
        let values = try? url.resourceValues(forKeys: keys)
        
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate ?? Date()
        self.isHidden = values?.isHidden ?? url.lastPathComponent.hasPrefix(".")
        self.fileExtension = url.pathExtension.lowercased()
        
        if fetchTags {
            self.tags = values?.tagNames ?? []
            self.tagColor = values?.labelColor
        } else {
            self.tags = []
            self.tagColor = nil
        }
    }

    public var formattedSize: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateModified)
    }
}
