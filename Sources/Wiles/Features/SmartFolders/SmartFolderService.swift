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
            let paths = results.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            Self.fetchFileItems(forPaths: paths, completion: completion)
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
            let paths = results.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
            Self.fetchFileItems(forPaths: paths, completion: completion)
        }
        metadataQuery.start()
        query = metadataQuery
    }

    /// Resolves `FileItem`s (including their `NSWorkspace` icon) for a Spotlight result set's paths
    /// off the main thread. With large result sets, doing this icon lookup inline inside the
    /// synchronous `NSMetadataQueryDidFinishGathering` callback caused a mild UI hitch; batching it
    /// into a detached task and hopping back to the main actor once done keeps that work off the hot
    /// path, mirroring the off-main pattern used for `/Volumes/` navigation in `AppState+Navigation.swift`.
    private nonisolated static func fetchFileItems(forPaths paths: [String], completion: @escaping @Sendable ([FileItem]) -> Void) {
        Task.detached(priority: .userInitiated) {
            var items: [FileItem] = []
            items.reserveCapacity(paths.count)
            for path in paths {
                let url = URL(fileURLWithPath: path)
                let icon = NSWorkspace.shared.icon(forFile: path)
                items.append(FileItem(url: url, icon: icon))
            }
            await MainActor.run {
                completion(items)
            }
        }
    }
}
