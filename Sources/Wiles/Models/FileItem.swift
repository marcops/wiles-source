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
    public let isUbiquitous: Bool
    public let isUbiquitousNotDownloaded: Bool
    public let isUbiquitousDownloading: Bool
    public let isUbiquitousUploading: Bool

    public init(url: URL, icon: NSImage, fetchTags: Bool = false) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent
        self.icon = icon

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .creationDateKey, .contentAccessDateKey,
            .isHiddenKey, .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemIsUploadingKey
        ]
        let values = try? url.resourceValues(forKeys: keys)

        // Fetched in a separate call: requesting .tagNamesKey together with the
        // .isUbiquitousItemKey/.ubiquitousItem* keys in one resourceValues batch
        // silently returns an empty tag list for local (non-iCloud) files.
        let tagValues = fetchTags ? try? url.resourceValues(forKeys: [.tagNamesKey, .labelColorKey]) : nil

        self.isDirectory = values?.isDirectory ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate ?? Date()
        self.dateCreated = values?.creationDate ?? Date()
        self.dateAccessed = values?.contentAccessDate
        self.isHidden = values?.isHidden ?? url.lastPathComponent.hasPrefix(".")
        self.fileExtension = url.pathExtension.lowercased()

        self.isUbiquitous = values?.isUbiquitousItem ?? false
        let status = values?.ubiquitousItemDownloadingStatus
        self.isUbiquitousNotDownloaded = (status == .notDownloaded)
        self.isUbiquitousDownloading = values?.ubiquitousItemIsDownloading ?? false
        self.isUbiquitousUploading = values?.ubiquitousItemIsUploading ?? false

        // Fetch POSIX owner/group
        (self.ownerName, self.groupName) = Self.ownerAndGroup(atPath: url.path)

        if fetchTags {
            self.tags = tagValues?.tagNames ?? []
            self.tagColor = tagValues?.labelColor
        } else {
            self.tags = []
            self.tagColor = nil
        }
    }

    private static func ownerAndGroup(atPath path: String) -> (owner: String, group: String) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else {
            return ("--", "--")
        }
        let owner = (attrs[.ownerAccountName] as? String) ?? "--"
        let group = (attrs[.groupOwnerAccountName] as? String) ?? "--"
        return (owner, group)
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
