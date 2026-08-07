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

public struct FileSystemService: FileSystemServiceProtocol, Sendable {
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
                let regex = SearchFilterService.parseSearchRegex(query: options.searchQuery)
                items = items.filter { SearchFilterService.matchesSearch(fileURL: $0.url, query: options.searchQuery, regex: regex) }
            }
            return items
        }.value
    }

    private static func loadRealDirectoryContents(at url: URL, options: DirectoryLoadOptions) async -> [FileItem] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            // Prefetching creationDateKey/contentAccessDateKey/effectiveIconKey here — not just the
            // keys FileItem strictly needs for its primary fields — means FileItem's own
            // resourceValues(forKeys:) call below hits URL's warm resource cache for all of them
            // instead of triggering a fresh per-file stat/IPC call for whichever ones were missing.
            // effectiveIconKey in particular replaces a blocking NSWorkspace.icon(forFile:) call per
            // file (a LaunchServices IPC round trip) with one bulk-fetched alongside everything else.
            var keys: [URLResourceKey] = [
                .isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey,
                .creationDateKey, .contentAccessDateKey, .effectiveIconKey,
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

            let regex = SearchFilterService.parseSearchRegex(query: options.searchQuery)
            var items: [FileItem] = []
            for fileURL in fileURLs {
                if isFileHidden(fileURL: fileURL, showHidden: options.showHidden) { continue }
                if !SearchFilterService.matchesSearch(fileURL: fileURL, query: options.searchQuery, regex: regex) { continue }

                items.append(FileItem(url: fileURL, fetchTags: options.showTags))
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
