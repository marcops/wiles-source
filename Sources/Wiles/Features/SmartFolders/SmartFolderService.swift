import AppKit
import Foundation

@MainActor
public final class SmartFolderService: NSObject, SmartFolderServiceProtocol, @unchecked Sendable {
    public static let shared = SmartFolderService()
    private var query: NSMetadataQuery?
    private var queryObserver: (any NSObjectProtocol)?
    /// Identifies the most recently started query. `fetchFileItems` resolves icons on a detached
    /// task, so a slower-finishing older query (e.g. one with more results) could otherwise still
    /// call its `completion` after a faster newer one already did, silently overwriting the newer,
    /// correct results with stale ones — this is why clicking a different smart folder could
    /// sometimes leave the previous one's results on screen. Each completion checks this token
    /// before applying, so only the most recently started query's results ever actually land.
    private var currentQueryToken = UUID()

    public static func loadSavedSmartFolders() -> [SmartFolder] {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.smartFolders.rawValue),
              let folders = try? JSONDecoder().decode([SmartFolder].self, from: data) else { return [] }
        return folders
    }

    public static func saveSmartFolders(_ folders: [SmartFolder]) throws {
        try saveSmartFolders(folders, encode: { try JSONEncoder().encode($0) })
    }

    /// Test-only seam: lets tests inject a throwing encoder to deterministically simulate an
    /// encoding failure (`SmartFolder`'s fields can't actually fail to encode in practice, so
    /// there's no real-world way to trigger this otherwise). Production code should always go
    /// through `saveSmartFolders(_:)` above.
    ///
    /// Deliberately not `try?` on the encode call: swallowing an encode failure here used to make
    /// the entire save silently a no-op - the caller believed the smart folder was saved/removed
    /// when nothing was actually persisted. Propagate the error so the caller can surface it.
    static func saveSmartFolders(_ folders: [SmartFolder], encode: ([SmartFolder]) throws -> Data) throws {
        let data = try encode(folders)
        UserDefaults.standard.set(data, forKey: DefaultsKey.smartFolders.rawValue)
    }

    public func executeQuery(for smartFolder: SmartFolder, completion: @escaping @Sendable ([FileItem]) -> Void) {
        let wildcardQuery = "*\(smartFolder.searchQuery)*"
        let predicate = NSPredicate(format: "kMDItemDisplayName ==[cd] %@", wildcardQuery)
        let searchScopes: [Any] = if !smartFolder.scopePath.isEmpty, FileManager.default.fileExists(atPath: smartFolder.scopePath) {
            [URL(fileURLWithPath: smartFolder.scopePath)]
        } else {
            [NSMetadataQueryUserHomeScope]
        }
        runQuery(predicate: predicate, searchScopes: searchScopes, completion: completion)
    }

    public func executeContentQuery(queryText: String, in folderURL: URL, completion: @escaping @Sendable ([FileItem]) -> Void) {
        let wildcardQuery = "*\(queryText)*"
        let predicate = NSPredicate(format: "(kMDItemTextContent ==[cd] %@) || (kMDItemFSName ==[cd] %@)", wildcardQuery, wildcardQuery)
        runQuery(predicate: predicate, searchScopes: [folderURL], completion: completion)
    }

    /// Shared `NSMetadataQuery` setup/teardown boilerplate for `executeQuery` and
    /// `executeContentQuery`, which differ only in the predicate and search scope they need.
    /// Owns the same staleness-token handling documented on `currentQueryToken`: each call stops
    /// any in-flight query, mints a fresh token before starting the new one, and the completion
    /// only applies its results if that token is still the most recent by the time it fires.
    private func runQuery(predicate: NSPredicate, searchScopes: [Any], completion: @escaping @Sendable ([FileItem]) -> Void) {
        query?.stop()
        let token = UUID()
        currentQueryToken = token
        let metadataQuery = NSMetadataQuery()
        metadataQuery.predicate = predicate
        metadataQuery.searchScopes = searchScopes

        if let existingObserver = queryObserver {
            NotificationCenter.default.removeObserver(existingObserver)
            queryObserver = nil
        }
        queryObserver = NotificationCenter.default
            .addObserver(forName: .NSMetadataQueryDidFinishGathering, object: metadataQuery, queue: .main) { [weak self] notification in
                // `NSNotification`/`NSMetadataQuery` handling stays outside any actor-hop closure —
                // neither is Sendable, and `MainActor.assumeIsolated`'s manual assertion doesn't
                // prove that to the region-based isolation checker on every Swift toolchain version
                // (CI runs an older one than local) the way an actual `await`/`Task { @MainActor }`
                // hop does. Extract the plain data first, then hop once for the `self`-touching part.
                guard let query = notification.object as? NSMetadataQuery else {
                    completion([])
                    return
                }
                query.stop()
                guard let results = query.results as? [NSMetadataItem] else {
                    completion([])
                    return
                }
                let paths = results.compactMap { $0.value(forAttribute: NSMetadataItemPathKey) as? String }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let observer = self.queryObserver {
                        NotificationCenter.default.removeObserver(observer)
                        self.queryObserver = nil
                    }
                    Self.fetchFileItems(forPaths: paths) { [weak self] items in
                        Task { @MainActor in
                            guard let self, self.currentQueryToken == token else { return }
                            completion(items)
                        }
                    }
                }
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
