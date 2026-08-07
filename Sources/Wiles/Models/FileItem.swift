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

    /// `icon` is only needed when the caller already has one at hand (e.g. a bulk-prefetched
    /// `.effectiveIconKey` from the same `contentsOfDirectory` pass, or a spot-check on a single
    /// file elsewhere). Passing `nil` falls back to the resource-value read below (still cheap,
    /// since it's part of the same batch as the other keys) and finally to `NSWorkspace`, but the
    /// hot path — loading a whole directory — should always supply the prefetched icon directly to
    /// avoid a blocking LaunchServices IPC call per file.
    public init(url: URL, icon: NSImage? = nil, fetchTags: Bool = false, needsOwnerGroup: Bool = true) {
        self.url = url.standardizedFileURL
        self.name = url.lastPathComponent

        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .fileSizeKey, .contentModificationDateKey,
            .creationDateKey, .contentAccessDateKey,
            .isHiddenKey, .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemIsDownloadingKey,
            .ubiquitousItemIsUploadingKey,
            .effectiveIconKey
        ]
        let values = try? url.resourceValues(forKeys: keys)
        self.icon = Self.resolveHighResIcon(icon, values: values, url: url)

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

        let ubiquitous = Self.ubiquitousStatus(from: values)
        self.isUbiquitous = ubiquitous.isUbiquitous
        self.isUbiquitousNotDownloaded = ubiquitous.notDownloaded
        self.isUbiquitousDownloading = ubiquitous.downloading
        self.isUbiquitousUploading = ubiquitous.uploading

        // Fetch POSIX owner/group. This is a separate stat/getpwuid/getgrgid syscall path that
        // doesn't share the bulk-prefetched URLResourceValues above, so skip it entirely when the
        // caller knows the Owner/Group columns aren't visible.
        if needsOwnerGroup {
            (self.ownerName, self.groupName) = Self.ownerAndGroup(atPath: url.path)
        } else {
            (self.ownerName, self.groupName) = ("--", "--")
        }

        if fetchTags {
            self.tags = tagValues?.tagNames ?? []
            self.tagColor = tagValues?.labelColor
        } else {
            self.tags = []
            self.tagColor = nil
        }
    }

    private static func resolveHighResIcon(_ icon: NSImage?, values: URLResourceValues?, url: URL) -> NSImage {
        let resolvedIcon = icon ?? (values?.effectiveIcon as? NSImage) ?? NSWorkspace.shared.icon(forFile: url.path)
        let highResIcon = (resolvedIcon.copy() as? NSImage) ?? resolvedIcon
        highResIcon.size = NSSize(width: 512, height: 512)
        return highResIcon
    }

    private struct UbiquitousStatus {
        let isUbiquitous: Bool
        let notDownloaded: Bool
        let downloading: Bool
        let uploading: Bool
    }

    private static func ubiquitousStatus(from values: URLResourceValues?) -> UbiquitousStatus {
        UbiquitousStatus(
            isUbiquitous: values?.isUbiquitousItem ?? false,
            notDownloaded: values?.ubiquitousItemDownloadingStatus == .notDownloaded,
            downloading: values?.ubiquitousItemIsDownloading ?? false,
            uploading: values?.ubiquitousItemIsUploading ?? false
        )
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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public var formattedDate: String {
        Self.shortDateFormatter.string(from: dateModified)
    }

    public var formattedDateCreated: String {
        Self.shortDateFormatter.string(from: dateCreated)
    }

    public var formattedDateAccessed: String {
        guard let date = dateAccessed else { return "--" }
        return Self.shortDateFormatter.string(from: date)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url &&
        lhs.isDirectory == rhs.isDirectory &&
        lhs.size == rhs.size &&
        lhs.dateModified == rhs.dateModified &&
        lhs.isHidden == rhs.isHidden &&
        lhs.tags == rhs.tags &&
        lhs.isUbiquitousNotDownloaded == rhs.isUbiquitousNotDownloaded
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(isDirectory)
        hasher.combine(size)
        hasher.combine(dateModified)
        hasher.combine(isHidden)
        hasher.combine(tags)
    }
}
