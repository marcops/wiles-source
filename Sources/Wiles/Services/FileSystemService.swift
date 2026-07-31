import Foundation
import AppKit

public struct FileSystemService: Sendable {
    public static func loadDirectoryContents(
        at url: URL, showHidden: Bool, showTags: Bool, searchQuery: String, sortOption: SortOption, sortAscending: Bool
    ) async -> [FileItem] {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
            if showTags {
                keys.append(.tagNamesKey)
                keys.append(.labelColorKey)
            }
            guard let fileURLs = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants]) else {
                return []
            }
            
            let regex = parseSearchRegex(query: searchQuery)
            var items: [FileItem] = []
            for fileURL in fileURLs {
                if isFileHidden(fileURL: fileURL, showHidden: showHidden) { continue }
                if !matchesSearch(fileURL: fileURL, query: searchQuery, regex: regex) { continue }
                
                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                items.append(FileItem(url: fileURL, icon: icon, fetchTags: showTags))
            }
            return sortItems(items, by: sortOption, ascending: sortAscending)
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
        guard !query.isEmpty else { return true }
        
        if query.hasPrefix("tag:") {
            let targetTag = String(query.dropFirst(4)).lowercased()
            if let tags = try? (fileURL as NSURL).resourceValues(forKeys: [.tagNamesKey]) {
                if let tagArray = tags[.tagNamesKey] as? [String] {
                    return tagArray.contains { $0.lowercased() == targetTag }
                }
            }
            return false
        }
        
        let fileName = fileURL.lastPathComponent
        if fileName.localizedCaseInsensitiveContains(query) { return true }
        
        if let regex = regex {
            let range = NSRange(location: 0, length: fileName.utf16.count)
            if regex.firstMatch(in: fileName, options: [], range: range) != nil { return true }
        }
        
        return matchesContent(fileURL: fileURL, query: query)
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
        return items.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            let res: Bool
            switch option {
            case .name: res = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .dateModified: res = a.dateModified < b.dateModified
            case .dateCreated: res = a.dateCreated < b.dateCreated
            case .dateAccessed: 
                let d1 = a.dateAccessed ?? Date.distantPast
                let d2 = b.dateAccessed ?? Date.distantPast
                res = d1 < d2
            case .size: res = a.size < b.size
            case .kind: res = a.fileExtension.localizedStandardCompare(b.fileExtension) == .orderedAscending
            case .owner: res = a.ownerName.localizedStandardCompare(b.ownerName) == .orderedAscending
            case .group: res = a.groupName.localizedStandardCompare(b.groupName) == .orderedAscending
            }
            return ascending ? res : !res
        }
    }
    
    public static func setTags(for url: URL, tags: [String]) throws {
        try (url as NSURL).setResourceValue(tags, forKey: .tagNamesKey)
    }
}
