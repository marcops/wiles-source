import Foundation
import AppKit

public struct FileSystemService: Sendable {
    public static func loadDirectoryContents(
        at url: URL, showHidden: Bool, searchQuery: String, sortOption: SortOption, sortAscending: Bool
    ) async -> [FileItem] {
        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .isHiddenKey]
            guard let fileURLs = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [.skipsSubdirectoryDescendants]) else {
                return []
            }
            
            var items: [FileItem] = []
            for fileURL in fileURLs {
                if !showHidden && (fileURL.lastPathComponent.hasPrefix(".") || (try? fileURL.resourceValues(forKeys: [.isHiddenKey]).isHidden) == true) {
                    continue
                }
                if !searchQuery.isEmpty && !fileURL.lastPathComponent.localizedCaseInsensitiveContains(searchQuery) {
                    continue
                }
                let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
                let item = FileItem(url: fileURL, icon: icon)
                items.append(item)
            }
            return sortItems(items, by: sortOption, ascending: sortAscending)
        }.value
    }
    
    private static func sortItems(_ items: [FileItem], by option: SortOption, ascending: Bool) -> [FileItem] {
        return items.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            let res: Bool
            switch option {
            case .name: res = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .dateModified: res = a.dateModified < b.dateModified
            case .size: res = a.size < b.size
            case .kind: res = a.fileExtension.localizedStandardCompare(b.fileExtension) == .orderedAscending
            }
            return ascending ? res : !res
        }
    }
}
