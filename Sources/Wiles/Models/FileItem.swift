import Foundation
import AppKit

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: URL { url }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let size: Int64
    public let dateModified: Date
    public let dateCreated: Date
    public let dateAccessed: Date?
    public let ownerName: String
    public let groupName: String
    public let isHidden: Bool
    public let fileExtension: String
    public let icon: NSImage
    public let tags: [String]
    public let tagColor: NSColor?

    public init(url: URL, icon: NSImage, fetchTags: Bool = false) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.icon = icon
        
        var keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, 
            .creationDateKey, .contentAccessDateKey,
            .isHiddenKey
        ]
        // groupNameKey doesn't exist as a native URLResourceKey, we can get it via POSIX attributes if needed,
        // but let's just stick to URL properties, we'll fetch POSIX for owner/group to be reliable.
        if fetchTags {
            keys.insert(.tagNamesKey)
            keys.insert(.labelColorKey)
        }
        let values = try? url.resourceValues(forKeys: keys)
        
        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate ?? Date()
        self.dateCreated = values?.creationDate ?? Date()
        self.dateAccessed = values?.contentAccessDate
        self.isHidden = values?.isHidden ?? url.lastPathComponent.hasPrefix(".")
        self.fileExtension = url.pathExtension.lowercased()
        
        // Fetch POSIX owner/group
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
            self.ownerName = (attrs[.ownerAccountName] as? String) ?? "--"
            self.groupName = (attrs[.groupOwnerAccountName] as? String) ?? "--"
        } else {
            self.ownerName = "--"
            self.groupName = "--"
        }
        
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

    public var formattedDateCreated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateCreated)
    }

    public var formattedDateAccessed: String {
        guard let date = dateAccessed else { return "--" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
