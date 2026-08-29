import AppKit
import Foundation

/// `@unchecked Sendable`: `icon` is an `NSImage` reference, but it is never mutated after `init`
/// (only formatted once during construction); that post-init immutability is what makes this safe.
public struct FileItem: Identifiable, Hashable, @unchecked Sendable {
    private static let highResIconSize: CGFloat = 512

    public var id: URL {
        url
    }

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

    /// Pure value assembly — no disk access. `FileItem.load(url:)` is the disk-reading path;
    /// this initializer just stores already-resolved fields (used by `load` and by tests that
    /// want a deterministic item without touching the filesystem).
    public init(
        url: URL, name: String, isDirectory: Bool, size: Int64, dateModified: Date, dateCreated: Date,
        dateAccessed: Date?, ownerName: String, groupName: String, isHidden: Bool, fileExtension: String,
        icon: NSImage, tags: [String], tagColor: NSColor?, isUbiquitous: Bool,
        isUbiquitousNotDownloaded: Bool, isUbiquitousDownloading: Bool, isUbiquitousUploading: Bool) {
        self.url = url
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.dateModified = dateModified
        self.dateCreated = dateCreated
        self.dateAccessed = dateAccessed
        self.ownerName = ownerName
        self.groupName = groupName
        self.isHidden = isHidden
        self.fileExtension = fileExtension
        self.icon = icon
        self.tags = tags
        self.tagColor = tagColor
        self.isUbiquitous = isUbiquitous
        self.isUbiquitousNotDownloaded = isUbiquitousNotDownloaded
        self.isUbiquitousDownloading = isUbiquitousDownloading
        self.isUbiquitousUploading = isUbiquitousUploading
    }

    /// Reads every attribute for `url` from disk — up to three syscall batches (two
    /// `resourceValues` reads plus a `stat`/`getpwuid`/`getgrgid` for owner/group). This is
    /// blocking I/O; never call it from a SwiftUI `body` or other render-path code.
    ///
    /// `icon` is only needed when the caller already has one at hand (e.g. a bulk-prefetched
    /// `.effectiveIconKey` from the same `contentsOfDirectory` pass, or a spot-check on a single
    /// file elsewhere). Passing `nil` falls back to the resource-value read below (still cheap,
    /// since it's part of the same batch as the other keys) and finally to `NSWorkspace`, but the
    /// hot path — loading a whole directory — should always supply the prefetched icon directly to
    /// avoid a blocking LaunchServices IPC call per file.
    public static func load(url: URL, icon: NSImage? = nil, fetchTags: Bool = false, needsOwnerGroup: Bool = true) -> Self {
        let std = url.standardizedFileURL

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

        // Fetched in a separate call: requesting .tagNamesKey together with the
        // .isUbiquitousItemKey/.ubiquitousItem* keys in one resourceValues batch
        // silently returns an empty tag list for local (non-iCloud) files.
        let tagValues = fetchTags ? try? url.resourceValues(forKeys: [.tagNamesKey, .labelColorKey]) : nil

        let ubiquitous = ubiquitousStatus(from: values)
        // Separate stat/getpwuid/getgrgid syscall path — skip entirely when the caller knows the
        // Owner/Group columns aren't visible.
        let ownerGroup = needsOwnerGroup ? ownerAndGroup(atPath: std.path) : ("--", "--")

        return Self(
            url: std,
            name: std.lastPathComponent,
            isDirectory: values?.isDirectory ?? false,
            size: Int64(values?.fileSize ?? 0),
            dateModified: values?.contentModificationDate ?? Date(),
            dateCreated: values?.creationDate ?? Date(),
            dateAccessed: values?.contentAccessDate,
            ownerName: ownerGroup.0,
            groupName: ownerGroup.1,
            isHidden: values?.isHidden ?? url.lastPathComponent.hasPrefix("."),
            fileExtension: url.pathExtension.lowercased(),
            icon: resolveHighResIcon(icon, values: values, url: url),
            tags: fetchTags ? (tagValues?.tagNames ?? []) : [],
            tagColor: fetchTags ? tagValues?.labelColor : nil,
            isUbiquitous: ubiquitous.isUbiquitous,
            isUbiquitousNotDownloaded: ubiquitous.notDownloaded,
            isUbiquitousDownloading: ubiquitous.downloading,
            isUbiquitousUploading: ubiquitous.uploading)
    }

    private static func resolveHighResIcon(_ icon: NSImage?, values: URLResourceValues?, url: URL) -> NSImage {
        let resolvedIcon = icon ?? (values?.effectiveIcon as? NSImage) ?? NSWorkspace.shared.icon(forFile: url.path)
        return resolvedIcon.resizedCopy(to: NSSize(width: Self.highResIconSize, height: Self.highResIconSize))
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
            uploading: values?.ubiquitousItemIsUploading ?? false)
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
        if isDirectory {
            return "--"
        }
        return ByteFormat.fileSize(size)
    }

    // Keyed by resolved language code so switching the in-app language mid-session reformats
    // dates instead of sticking to whatever locale was captured on first use.
    private static let dateFormatterCacheLock = NSLock()
    private nonisolated(unsafe) static var dateFormatterCache: [String: DateFormatter] = [:]

    private static func dateFormatter(for language: AppLanguage) -> DateFormatter {
        let code = L10n.activeCode(language)
        dateFormatterCacheLock.lock()
        defer { dateFormatterCacheLock.unlock() }
        if let cached = dateFormatterCache[code] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: code)
        // Locale sets field order/separators/clock; widen every field to 2 digits for leading zeros
        // (01/01/12 01:02) — the skeleton honors that for date fields but not the hour, so pad it.
        formatter.setLocalizedDateFormatFromTemplate("ddMMyyjjmm")
        formatter.dateFormat = formatter.dateFormat?
            .replacingOccurrences(of: "h{1,2}", with: "hh", options: .regularExpression)
            .replacingOccurrences(of: "H{1,2}", with: "HH", options: .regularExpression)
        dateFormatterCache[code] = formatter
        return formatter
    }

    public func formattedDate(language: AppLanguage) -> String {
        Self.dateFormatter(for: language).string(from: dateModified)
    }

    public func formattedDateCreated(language: AppLanguage) -> String {
        Self.dateFormatter(for: language).string(from: dateCreated)
    }

    public func formattedDateAccessed(language: AppLanguage) -> String {
        guard let date = dateAccessed else { return "--" }
        return Self.dateFormatter(for: language).string(from: date)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.url == rhs.url &&
            lhs.isDirectory == rhs.isDirectory &&
            lhs.size == rhs.size &&
            lhs.dateModified == rhs.dateModified &&
            lhs.dateCreated == rhs.dateCreated &&
            lhs.dateAccessed == rhs.dateAccessed &&
            lhs.isHidden == rhs.isHidden &&
            lhs.tags == rhs.tags &&
            lhs.tagColor == rhs.tagColor &&
            lhs.ownerName == rhs.ownerName &&
            lhs.groupName == rhs.groupName &&
            lhs.isUbiquitous == rhs.isUbiquitous &&
            lhs.isUbiquitousNotDownloaded == rhs.isUbiquitousNotDownloaded &&
            lhs.isUbiquitousDownloading == rhs.isUbiquitousDownloading &&
            lhs.isUbiquitousUploading == rhs.isUbiquitousUploading
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
