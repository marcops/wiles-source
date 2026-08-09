import Foundation
import AppKit

@MainActor
public final class SmartFolderService: NSObject, SmartFolderServiceProtocol, @unchecked Sendable {
    public static let shared = SmartFolderService()
    private var query: NSMetadataQuery?
    private var queryObserver: NSObjectProtocol?

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
        let wildcardQuery = "*\(smartFolder.searchQuery)*"
        metadataQuery.predicate = NSPredicate(format: "kMDItemDisplayName ==[cd] %@", wildcardQuery)
        if !smartFolder.scopePath.isEmpty && FileManager.default.fileExists(atPath: smartFolder.scopePath) {
            metadataQuery.searchScopes = [URL(fileURLWithPath: smartFolder.scopePath)]
        } else {
            metadataQuery.searchScopes = [NSMetadataQueryUserHomeScope]
        }

        if let existingObserver = queryObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            queryObserver = nil
        }
        queryObserver = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                if let observer = self?.queryObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.queryObserver = nil
                }
            }
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
        let wildcardQuery = "*\(queryText)*"
        metadataQuery.predicate = NSPredicate(format: "(kMDItemTextContent ==[cd] %@) || (kMDItemFSName ==[cd] %@)", wildcardQuery, wildcardQuery)
        metadataQuery.searchScopes = [folderURL]

        if let existingObserver = queryObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            queryObserver = nil
        }
        queryObserver = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                if let observer = self?.queryObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.queryObserver = nil
                }
            }
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
