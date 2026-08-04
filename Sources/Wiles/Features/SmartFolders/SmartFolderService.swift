import Foundation
import AppKit

public struct SmartFolder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var icon: String
    public var searchQuery: String
    public var scopePath: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, icon: String = "folder.badge.gearshape", searchQuery: String, scopePath: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.icon = icon
        self.searchQuery = searchQuery
        self.scopePath = scopePath
        self.createdAt = createdAt
    }
}

@MainActor
public protocol SmartFolderServiceProtocol: Sendable {
    static func loadSavedSmartFolders() -> [SmartFolder]
    static func saveSmartFolders(_ folders: [SmartFolder])
}

@MainActor
public final class SmartFolderService: NSObject, SmartFolderServiceProtocol, @unchecked Sendable {
    public static let shared = SmartFolderService()
    private var query: NSMetadataQuery?

    public static func loadSavedSmartFolders() -> [SmartFolder] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue),
              let folders = try? JSONDecoder().decode([SmartFolder].self, from: data) else { return [] }
        return folders
    }

    public static func saveSmartFolders(_ folders: [SmartFolder]) {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.smartFolders.rawValue)
        }
    }

    public func executeQuery(for smartFolder: SmartFolder, completion: @escaping @Sendable ([FileItem]) -> Void) {
        query?.stop()
        let metadataQuery = NSMetadataQuery()
        let cleanQuery = smartFolder.searchQuery.replacingOccurrences(of: "'", with: "")
        let predicateStr = "kMDItemDisplayName == '*\(cleanQuery)*'c"
        metadataQuery.predicate = NSPredicate(format: predicateStr)
        if !smartFolder.scopePath.isEmpty && FileManager.default.fileExists(atPath: smartFolder.scopePath) {
            metadataQuery.searchScopes = [URL(fileURLWithPath: smartFolder.scopePath)]
        } else {
            metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        }

        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { notification in
            guard let query = notification.object as? NSMetadataQuery else { completion([]); return }
            query.stop()
            guard let results = query.results as? [NSMetadataItem] else { completion([]); return }
            var items: [FileItem] = []
            for res in results {
                if let path = res.value(forAttribute: NSMetadataItemPathKey) as? String {
                    let url = URL(fileURLWithPath: path)
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    items.append(FileItem(url: url, icon: icon))
                }
            }
            completion(items)
        }
        metadataQuery.start()
        query = metadataQuery
    }

    public func executeContentQuery(queryText: String, in folderURL: URL, completion: @escaping @Sendable ([FileItem]) -> Void) {
        query?.stop()
        let metadataQuery = NSMetadataQuery()
        let cleanQuery = queryText.replacingOccurrences(of: "'", with: "")
        let predicateStr = "(kMDItemTextContent == '*\(cleanQuery)*'c || kMDItemFSName == '*\(cleanQuery)*'c)"
        metadataQuery.predicate = NSPredicate(format: predicateStr)
        metadataQuery.searchScopes = [folderURL]

        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { notification in
            guard let query = notification.object as? NSMetadataQuery else { completion([]); return }
            query.stop()
            guard let results = query.results as? [NSMetadataItem] else { completion([]); return }
            var items: [FileItem] = []
            for res in results {
                if let path = res.value(forAttribute: NSMetadataItemPathKey) as? String {
                    let url = URL(fileURLWithPath: path)
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    items.append(FileItem(url: url, icon: icon))
                }
            }
            completion(items)
        }
        metadataQuery.start()
        query = metadataQuery
    }
}
