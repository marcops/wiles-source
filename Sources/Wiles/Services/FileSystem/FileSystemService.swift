import AppKit
import Foundation
import GitBeacon

public struct FileSystemService: Sendable {
    static let recursiveSearchResultLimit: Int = 2000
    static let recursiveSearchBatchSize: Int = 40

    /// `recentURLs` is the caller's in-memory recents list (`NavigationStore.recentOpenedURLs`) —
    /// passed in rather than re-read from `UserDefaults` here, so the two can't diverge before a save.
    public static func loadDirectoryContents(at url: URL, options: DirectoryLoadOptions, recentURLs: [URL] = []) async throws -> [FileItem] {
        if url.path == AppState.recentsVirtualURL.path {
            return await loadRecentsVirtualDirectory(recentURLs: recentURLs, options: options)
        }
        return try await loadRealDirectoryContents(at: url, options: options)
    }

    private static func loadRecentsVirtualDirectory(recentURLs: [URL], options: DirectoryLoadOptions) async -> [FileItem] {
        await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var items: [FileItem] = []
            for fileURL in recentURLs {
                if Task.isCancelled {
                    break
                }
                guard fm.fileExists(atPath: fileURL.path) else { continue }

                // Let FileItem resolve the icon from `.effectiveIcon` in its own resourceValues
                // batch instead of a separate blocking NSWorkspace LaunchServices IPC per entry.
                items.append(FileItem.load(url: fileURL, fetchTags: options.showTags, needsOwnerGroup: options.showOwnerGroup))
            }
            if !options.searchQuery.isEmpty {
                let tokenRegexes = SearchFilterService.parseTokenRegexes(query: options.searchQuery, caseSensitive: options.searchCaseSensitive)
                items = items.filter {
                    SearchFilterService.matchesSearch(
                        fileURL: $0.url, query: options.searchQuery, tokenRegexes: tokenRegexes,
                        scope: options.searchScope, caseSensitive: options.searchCaseSensitive)
                }
            }
            return items
        }.value
    }

    private static func loadRealDirectoryContents(at url: URL, options: DirectoryLoadOptions) async throws -> [FileItem] {
        try await Task.detached(priority: .userInitiated) {
            try loadRealDirectoryContentsSync(at: url, options: options)
        }.value
    }

    /// A directory that no longer exists (deleted, unmounted, or moved out from under the user
    /// while they were viewing it) is treated as empty — matching prior behavior and the "folder
    /// vanished during navigation" flow, not a real failure worth an alert. Any other failure
    /// (most notably permission denied on a protected folder) is a genuine read error that must be
    /// distinguishable from "this folder legitimately has zero items," so it's reported and
    /// re-thrown for the caller to surface to the user.
    private static func directoryEntries(at url: URL, keys: [URLResourceKey]) throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants])
        } catch {
            if let cocoaError = error as? CocoaError, cocoaError.code == .fileReadNoSuchFile {
                return []
            }
            ErrorReporter.report(error, context: "Listing directory contents at \(url.path)")
            throw error
        }
    }

    private static func loadRealDirectoryContentsSync(at url: URL, options: DirectoryLoadOptions) throws -> [FileItem] {
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
        let fileURLs = try directoryEntries(at: url, keys: keys)

        let tokenRegexes = SearchFilterService.parseTokenRegexes(query: options.searchQuery, caseSensitive: options.searchCaseSensitive)
        var items: [FileItem] = []
        for fileURL in fileURLs {
            if Task.isCancelled {
                break
            }
            if isFileHidden(fileURL: fileURL, showHidden: options.showHidden) {
                continue
            }
            if !SearchFilterService.matchesSearch(
                fileURL: fileURL, query: options.searchQuery, tokenRegexes: tokenRegexes,
                scope: options.searchScope, caseSensitive: options.searchCaseSensitive) {
                continue
            }

            items.append(FileItem.load(url: fileURL, fetchTags: options.showTags, needsOwnerGroup: options.showOwnerGroup))
        }
        let sortedItems = sortItems(items, by: options.sortOption, ascending: options.sortAscending)
        if options.searchQuery.isEmpty {
            DirectoryCacheService.shared.cacheDirectory(DirectoryLoadResult(items: sortedItems), for: url)
        }
        return sortedItems
    }

    /// Recursively enumerates every file under `root` (used when the user turns on "search
    /// everywhere" instead of the default single-folder, non-recursive search) and filters each
    /// one through the same `SearchFilterService` predicate as a normal folder listing. Capped at
    /// `Self.recursiveSearchResultLimit` so a query with very broad matches over the whole
    /// home directory can't grow the result list — and the walk time — without bound.
    ///
    /// `includeHidden` is deliberately separate from `options.showHidden` (which only governs a
    /// normal single-folder listing) — hidden folders default to excluded here regardless of that
    /// setting, since walking into every dotfile/cache folder under the home directory is both
    /// slow and rarely what a "search everywhere" query is looking for.
    ///
    /// `onBatch` is invoked periodically (every `Self.recursiveSearchBatchSize` matches,
    /// and once more with the final result) with the sorted matches found so far, so the UI can
    /// stream results in as they're found instead of blocking on the full walk.
    public static func loadRecursiveSearchResults(
        at root: URL,
        options: DirectoryLoadOptions,
        includeHidden: Bool,
        onBatch: @escaping @Sendable ([FileItem]) -> Void) async throws {
        try await Task.detached(priority: .userInitiated) {
            try performRecursiveSearch(at: root, options: options, includeHidden: includeHidden, onBatch: onBatch)
        }.value
    }

    /// Without an `errorHandler`, `FileManager.enumerator` silently aborts the ENTIRE walk
    /// the first time it hits a directory it can't read — and the home folder tree is full
    /// of those on modern macOS without Full Disk Access (`~/Library/Mail`,
    /// `~/Library/Containers`, various TCC-protected caches). That would make a recursive
    /// search stop dead at whatever protected folder it happens to reach first, long before
    /// getting to folders like `~/Documents` that come later in enumeration order. Returning
    /// `true` here tells it to skip the unreadable item and keep walking everything else.
    private static func makeRecursiveSearchEnumerator(
        at root: URL, options: DirectoryLoadOptions, includeHidden: Bool) -> FileManager.DirectoryEnumerator? {
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
        var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !includeHidden {
            enumeratorOptions.insert(.skipsHiddenFiles)
        }
        return FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: enumeratorOptions,
            errorHandler: { _, _ in true })
    }

    private static func performRecursiveSearch(
        at root: URL,
        options: DirectoryLoadOptions,
        includeHidden: Bool,
        onBatch: @escaping @Sendable ([FileItem]) -> Void) throws {
        guard let enumerator = makeRecursiveSearchEnumerator(at: root, options: options, includeHidden: includeHidden) else {
            // `FileManager.enumerator(at:)` returns nil (rather than an empty enumerator) when the
            // root itself can't be read at all — most commonly permission denied. Previously this
            // silently reported zero results, indistinguishable from a genuinely empty tree; now it's
            // reported and thrown so the caller can surface a real error instead of a misleading
            // "nothing found."
            let error = WilesError.permissionDenied(path: root.path)
            ErrorReporter.report(error, context: "Starting recursive search enumerator at \(root.path)")
            throw error
        }

        let tokenRegexes = SearchFilterService.parseTokenRegexes(query: options.searchQuery, caseSensitive: options.searchCaseSensitive)
        let isOrderedBefore = sortComparator(for: options.sortOption, ascending: options.sortAscending)
        var items: [FileItem] = []
        var lastReportedCount = 0
        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                break
            }
            if !includeHidden, isFileHidden(fileURL: fileURL, showHidden: false) {
                continue
            }
            if !SearchFilterService.matchesSearch(
                fileURL: fileURL, query: options.searchQuery, tokenRegexes: tokenRegexes,
                scope: options.searchScope, caseSensitive: options.searchCaseSensitive) {
                continue
            }

            let newItem = FileItem.load(url: fileURL, fetchTags: options.showTags, needsOwnerGroup: options.showOwnerGroup)
            items.insert(newItem, at: insertionIndex(for: newItem, in: items, isOrderedBefore: isOrderedBefore))
            if items.count - lastReportedCount >= Self.recursiveSearchBatchSize {
                onBatch(items)
                lastReportedCount = items.count
            }
            if items.count >= Self.recursiveSearchResultLimit {
                break
            }
        }
        onBatch(items)
    }

    private static func isFileHidden(fileURL: URL, showHidden: Bool) -> Bool {
        guard !showHidden else { return false }
        // Fast path: skip the stat for dotfiles during recursive enumeration.
        if fileURL.lastPathComponent.hasPrefix(".") {
            return true
        }
        return FileItem.isHidden(
            url: fileURL,
            isHiddenResourceValue: try? fileURL.resourceValues(forKeys: [.isHiddenKey]).isHidden)
    }

    /// `internal` (not `private`): also used by `AppState` to re-sort `items` in memory after an
    /// in-place create/rename, without re-reading the directory from disk.
    static func sortItems(_ items: [FileItem], by option: SortOption, ascending: Bool) -> [FileItem] {
        items.sorted(by: sortComparator(for: option, ascending: ascending))
    }

    /// The "directories first, then `option` order" predicate, built once. Reused by the recursive
    /// search's binary-insertion so it never re-sorts a growing array per batch.
    static func sortComparator(for option: SortOption, ascending: Bool) -> (FileItem, FileItem) -> Bool {
        let isBefore: (FileItem, FileItem) -> Bool = switch option {
        case .name: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .dateModified: { $0.dateModified < $1.dateModified }
        case .dateCreated: { $0.dateCreated < $1.dateCreated }
        case .dateAccessed: { ($0.dateAccessed ?? .distantPast) < ($1.dateAccessed ?? .distantPast) }
        case .size: { $0.size < $1.size }
        case .kind: { $0.fileExtension.localizedStandardCompare($1.fileExtension) == .orderedAscending }
        case .owner: { $0.ownerName.localizedStandardCompare($1.ownerName) == .orderedAscending }
        case .group: { $0.groupName.localizedStandardCompare($1.groupName) == .orderedAscending }
        }
        return { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return ascending ? isBefore(lhs, rhs) : !isBefore(lhs, rhs)
        }
    }

    /// Lower-bound index for `item` in an array already ordered by `isOrderedBefore`.
    static func insertionIndex(
        for item: FileItem, in sorted: [FileItem],
        isOrderedBefore: (FileItem, FileItem) -> Bool) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if isOrderedBefore(sorted[mid], item) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    public static func setTags(for url: URL, tags: [String]) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
