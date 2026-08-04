import Foundation
import AppKit

extension URL {
    public static let userHome: URL = FileManager.default.homeDirectoryForCurrentUser
    public static let userTrash: URL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/Users/\(NSUserName())/.Trash")
}

public struct DirectoryLoadOptions: Sendable {
    public let showHidden: Bool
    public let showTags: Bool
    public let searchQuery: String
    public let sortOption: SortOption
    public let sortAscending: Bool

    public init(showHidden: Bool, showTags: Bool, searchQuery: String, sortOption: SortOption, sortAscending: Bool) {
        self.showHidden = showHidden
        self.showTags = showTags
        self.searchQuery = searchQuery
        self.sortOption = sortOption
        self.sortAscending = sortAscending
    }
}

public struct FileSystemService: Sendable {
    public static func loadDirectoryContents(at url: URL, options: DirectoryLoadOptions) async -> [FileItem] {
        if url.path == "/virtual/recents" {
            return await loadRecentsVirtualDirectory(options: options)
        }
        return await loadRealDirectoryContents(at: url, options: options)
    }

    private static func loadRecentsVirtualDirectory(options: DirectoryLoadOptions) async -> [FileItem] {
        await Task.detached(priority: .userInitiated) {
            let defaults = UserDefaults.standard
            let paths = defaults.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) ?? []
            let fm = FileManager.default
            var items: [FileItem] = []
            for path in paths {
                let fileURL = URL(fileURLWithPath: path)
                guard fm.fileExists(atPath: fileURL.path) else { continue }

                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                items.append(FileItem(url: fileURL, icon: icon, fetchTags: options.showTags))
            }
            if !options.searchQuery.isEmpty {
                let regex = parseSearchRegex(query: options.searchQuery)
                items = items.filter { matchesSearch(fileURL: $0.url, query: options.searchQuery, regex: regex) }
            }
            return items
        }.value
    }

    private static func loadRealDirectoryContents(at url: URL, options: DirectoryLoadOptions) async -> [FileItem] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var keys: [URLResourceKey] = [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
                .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
                .ubiquitousItemIsDownloadingKey, .ubiquitousItemIsUploadingKey
            ]
            if options.showTags {
                keys.append(.tagNamesKey)
                keys.append(.labelColorKey)
            }
            guard let fileURLs = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants]) else {
                return []
            }

            let regex = parseSearchRegex(query: options.searchQuery)
            var items: [FileItem] = []
            for fileURL in fileURLs {
                if isFileHidden(fileURL: fileURL, showHidden: options.showHidden) { continue }
                if !matchesSearch(fileURL: fileURL, query: options.searchQuery, regex: regex) { continue }

                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                items.append(FileItem(url: fileURL, icon: icon, fetchTags: options.showTags))
            }
            let sortedItems = sortItems(items, by: options.sortOption, ascending: options.sortAscending)
            if options.searchQuery.isEmpty {
                DirectoryCacheService.shared.cacheDirectory(DirectoryLoadResult(items: sortedItems), for: url)
            }
            return sortedItems
        }.value
    }

    private static func isFileHidden(fileURL: URL, showHidden: Bool) -> Bool {
        if showHidden { return false }
        if fileURL.lastPathComponent.hasPrefix(".") { return true }
        return (try? fileURL.resourceValues(forKeys: [.isHiddenKey]).isHidden) == true
    }

    private static func parseSearchRegex(query: String) -> NSRegularExpression? {
        guard !query.isEmpty else { return nil }
        let pattern: String
        if query.hasPrefix("r:") {
            pattern = String(query.dropFirst(2))
        } else if query.contains("*") || query.contains("^") || query.contains("$") {
            pattern = query
        } else {
            return nil
        }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static func matchesSearch(fileURL: URL, query: String, regex: NSRegularExpression?) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let tokens = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for token in tokens {
            let lowerToken = token.lowercased()
            if lowerToken.hasPrefix("date:") {
                if !matchesDateFilter(fileURL: fileURL, token: String(token.dropFirst(5))) { return false }
            } else if lowerToken.hasPrefix("size:") {
                if !matchesSizeFilter(fileURL: fileURL, token: String(token.dropFirst(5))) { return false }
            } else if lowerToken.hasPrefix("kind:") || lowerToken.hasPrefix("ext:") {
                let prefix = lowerToken.hasPrefix("kind:") ? 5 : 4
                if !matchesKindFilter(fileURL: fileURL, token: String(token.dropFirst(prefix))) { return false }
            } else if lowerToken.hasPrefix("tag:") {
                if !matchesTagFilter(fileURL: fileURL, tag: String(token.dropFirst(4))) { return false }
            } else {
                if !matchesTextOrRegex(fileURL: fileURL, token: token, regex: regex) { return false }
            }
        }
        return true
    }

    private static func matchesDateFilter(fileURL: URL, token: String) -> Bool {
        guard let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) else {
            return false
        }
        let lower = token.lowercased()
        if lower == "today" { return Calendar.current.isDateInToday(modified) }
        if lower == "yesterday" { return Calendar.current.isDateInYesterday(modified) }

        var valueStr = lower
        var op = ">="
        if valueStr.hasPrefix(">=") || valueStr.hasPrefix("<=") {
            op = String(valueStr.prefix(2))
            valueStr = String(valueStr.dropFirst(2))
        } else if valueStr.hasPrefix(">") || valueStr.hasPrefix("<") || valueStr.hasPrefix("=") {
            op = String(valueStr.prefix(1))
            valueStr = String(valueStr.dropFirst(1))
        }

        guard let num = Int(valueStr.compactMap { $0.isNumber ? $0 : nil }.map(String.init).joined()) else { return false }
        let unit = valueStr.filter { $0.isLetter }

        var seconds: TimeInterval = Double(num) * 86400
        switch unit {
        case "h": seconds = Double(num) * 3600
        case "w": seconds = Double(num) * 7 * 86400
        case "m": seconds = Double(num) * 30 * 86400
        case "y": seconds = Double(num) * 365 * 86400
        default: break
        }

        let targetDate = Date().addingTimeInterval(-seconds)
        switch op {
        case "<", "<=": return modified <= targetDate
        default: return modified >= targetDate
        }
    }

    private static func matchesSizeFilter(fileURL: URL, token: String) -> Bool {
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) else { return false }
        var valueStr = token.lowercased()
        var op = ">="
        if valueStr.hasPrefix(">=") || valueStr.hasPrefix("<=") {
            op = String(valueStr.prefix(2))
            valueStr = String(valueStr.dropFirst(2))
        } else if valueStr.hasPrefix(">") || valueStr.hasPrefix("<") || valueStr.hasPrefix("=") {
            op = String(valueStr.prefix(1))
            valueStr = String(valueStr.dropFirst(1))
        }

        let digits = valueStr.filter { $0.isNumber }
        guard let num = Int64(digits), !digits.isEmpty else { return false }
        let unit = valueStr.filter { $0.isLetter }

        var multiplier: Int64 = 1024 * 1024
        if unit.hasPrefix("k") {
            multiplier = 1024
        } else if unit.hasPrefix("b") && !unit.hasPrefix("by") {
            multiplier = 1
        } else if unit.hasPrefix("g") {
            multiplier = 1024 * 1024 * 1024
        }

        let targetBytes = num * multiplier
        switch op {
        case "<": return size < targetBytes
        case "<=": return size <= targetBytes
        case "=": return size == targetBytes
        case ">": return size > targetBytes
        default: return size >= targetBytes
        }
    }

    private static func matchesKindFilter(fileURL: URL, token: String) -> Bool {
        let lower = token.lowercased()
        let ext = fileURL.pathExtension.lowercased()

        switch lower {
        case "image", "img", "images":
            return ["png", "jpg", "jpeg", "gif", "svg", "webp", "heic", "tiff", "icns", "bmp"].contains(ext)
        case "doc", "document", "documents":
            return ["doc", "docx", "pdf", "pages", "txt", "md", "rtf", "odt", "xls", "xlsx"].contains(ext)
        case "code", "source":
            return ["swift", "py", "js", "ts", "json", "html", "css", "cpp", "c", "h", "sh", "yml", "yaml"].contains(ext)
        case "pdf":
            return ext == "pdf"
        case "folder", "dir", "directory":
            return (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        case "archive", "zip":
            return ["zip", "tar", "gz", "7z", "rar", "bz2"].contains(ext)
        default:
            return ext == lower || fileURL.lastPathComponent.lowercased().contains(lower)
        }
    }

    private static func matchesTagFilter(fileURL: URL, tag: String) -> Bool {
        let targetTag = tag.lowercased()
        guard let tags = try? (fileURL as NSURL).resourceValues(forKeys: [.tagNamesKey]),
              let tagArray = tags[.tagNamesKey] as? [String] else { return false }
        return tagArray.contains { $0.lowercased() == targetTag }
    }

    private static func matchesTextOrRegex(fileURL: URL, token: String, regex: NSRegularExpression?) -> Bool {
        let fileName = fileURL.lastPathComponent
        if fileName.localizedCaseInsensitiveContains(token) { return true }
        if let regex = regex {
            let range = NSRange(location: 0, length: fileName.utf16.count)
            if regex.firstMatch(in: fileName, options: [], range: range) != nil { return true }
        }
        return matchesContent(fileURL: fileURL, query: token)
    }

    private static func matchesContent(fileURL: URL, query: String) -> Bool {
        guard query.count >= 3 else { return false }
        let textExtensions: Set<String> = ["txt", "md", "swift", "json", "py", "js", "ts", "css", "html", "sh", "yml", "xml", "csv"]
        guard textExtensions.contains(fileURL.pathExtension.lowercased()) else { return false }
        guard let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize), size < 2_000_000 else { return false }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return false }
        return content.localizedCaseInsensitiveContains(query)
    }

    private static func sortItems(_ items: [FileItem], by option: SortOption, ascending: Bool) -> [FileItem] {
        return items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            let res: Bool
            switch option {
            case .name: res = lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            case .dateModified: res = lhs.dateModified < rhs.dateModified
            case .dateCreated: res = lhs.dateCreated < rhs.dateCreated
            case .dateAccessed:
                let d1 = lhs.dateAccessed ?? Date.distantPast
                let d2 = rhs.dateAccessed ?? Date.distantPast
                res = d1 < d2
            case .size: res = lhs.size < rhs.size
            case .kind: res = lhs.fileExtension.localizedStandardCompare(rhs.fileExtension) == .orderedAscending
            case .owner: res = lhs.ownerName.localizedStandardCompare(rhs.ownerName) == .orderedAscending
            case .group: res = lhs.groupName.localizedStandardCompare(rhs.groupName) == .orderedAscending
            }
            return ascending ? res : !res
        }
    }

    public static func setTags(for url: URL, tags: [String]) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
