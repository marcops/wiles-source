import AppKit
import Foundation

@MainActor
public final class SmartFolderService: SmartFolderServiceProtocol {
    /// Instantiated per `AppState` (`appState.smartFolderService`), NOT a `.shared` singleton: the
    /// per-run `activeQuery`/`currentQueryToken` staleness state used to be shared across every open
    /// window, so a smart-folder run in one window silently discarded its own results the moment
    /// another window started its own run (`token != currentQueryToken`) — BA-108 / WILES_RULES.md
    /// "Singleton Services With Session State Need an Explicit Owner". The two `static` persistence
    /// helpers below hold no session state and stay static.
    public init() { }

    private var activeQuery: SpotlightQuery?
    /// The detached `FileItem`-resolution task for the current query, so a rapid smart-folder switch
    /// cancels the prior run's 2000-item resolve instead of letting it run to completion unused.
    private var fetchTask: Task<Void, Never>?

    /// Backstop timeout for each `NSMetadataQuery` gather. Overridable so tests don't have to sit
    /// through the full 20 s when Spotlight is cold/unindexed in the runner.
    var queryTimeout: Duration = SpotlightQuery.defaultTimeout
    /// Identifies the most recently started query. `fetchFileItems` resolves icons on a detached
    /// task, so a slower-finishing older query (e.g. one with more results) could otherwise still
    /// call its `completion` after a faster newer one already did, silently overwriting the newer,
    /// correct results with stale ones — this is why clicking a different smart folder could
    /// sometimes leave the previous one's results on screen. Each completion checks this token
    /// before applying, so only the most recently started query's results ever actually land.
    private var currentQueryToken = UUID()

    /// `true` when the last query's Spotlight gather timed out instead of finishing — the scope
    /// lives on an unindexed volume, so an empty result set means "can't tell", not "no matches".
    public private(set) var lastRunTimedOut = false

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

    /// Wraps the user's text in `*…*` for a Spotlight "contains" match, first stripping `*` and `"`:
    /// Spotlight treats a bare `*` as a wildcard and `"` as a phrase delimiter, so a typed `*` or an
    /// unbalanced quote would silently change what the smart folder matches.
    static func spotlightContainsPattern(for raw: String) -> String {
        let stripped = raw.replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "\"", with: "")
        return "*\(stripped)*"
    }

    public func executeQuery(for smartFolder: SmartFolder, completion: @escaping @Sendable ([FileItem]) -> Void) {
        let wildcardQuery = Self.spotlightContainsPattern(for: smartFolder.searchQuery)
        let predicate = NSPredicate(format: "kMDItemDisplayName ==[cd] %@", wildcardQuery)
        let searchScopes: [Any] = if !smartFolder.scopePath.isEmpty, FileManager.default.fileExists(atPath: smartFolder.scopePath) {
            [URL(fileURLWithPath: smartFolder.scopePath)]
        } else {
            [NSMetadataQueryUserHomeScope]
        }
        runQuery(predicate: predicate, searchScopes: searchScopes, completion: completion)
    }

    public func executeContentQuery(queryText: String, in folderURL: URL, completion: @escaping @Sendable ([FileItem]) -> Void) {
        let wildcardQuery = Self.spotlightContainsPattern(for: queryText)
        let predicate = NSPredicate(format: "(kMDItemTextContent ==[cd] %@) || (kMDItemFSName ==[cd] %@)", wildcardQuery, wildcardQuery)
        runQuery(predicate: predicate, searchScopes: [folderURL], completion: completion)
    }

    /// Shared `SpotlightQuery` orchestration for `executeQuery` and `executeContentQuery`, which
    /// differ only in the predicate and search scope they need. Owns the staleness-token handling
    /// documented on `currentQueryToken`: each call abandons any in-flight query, mints a fresh
    /// token before starting the new one, and only applies results if that token is still current.
    private func runQuery(predicate: NSPredicate, searchScopes: [Any], completion: @escaping @Sendable ([FileItem]) -> Void) {
        activeQuery?.cancel()
        fetchTask?.cancel()
        let token = UUID()
        currentQueryToken = token
        let spotlight = SpotlightQuery(predicate: predicate, searchScopes: searchScopes, timeout: queryTimeout)
        activeQuery = spotlight
        Task { @MainActor [weak self] in
            let (paths, timedOut) = await spotlight.run()
            guard let self, currentQueryToken == token else { return }
            activeQuery = nil
            lastRunTimedOut = timedOut
            fetchTask = Self.fetchFileItems(forPaths: paths) { items in
                Task { @MainActor [weak self] in
                    guard let self, currentQueryToken == token else { return }
                    completion(items)
                }
            }
        }
    }

    /// Resolves `FileItem`s for a Spotlight result set's paths off the main thread. Building them
    /// inline inside the synchronous `NSMetadataQueryDidFinishGathering` callback caused a mild UI
    /// hitch on large result sets; batching into a detached task and hopping back to the main actor
    /// once done keeps that work off the hot path, mirroring the off-main pattern used for
    /// `/Volumes/` navigation in `AppState+Navigation.swift`.
    /// Hard cap on Spotlight paths turned into `FileItem`s — a broad query (`*a*` over the home
    /// folder) can otherwise match tens of thousands of files, and each `FileItem.load` is a
    /// resourceValues batch + icon resolve. Aligned with `FileSystemService.recursiveSearchResultLimit`.
    nonisolated static let maxResultCount = 2000

    private nonisolated static func fetchFileItems(
        forPaths paths: [String], completion: @escaping @Sendable ([FileItem]) -> Void) -> Task<Void, Never> {
        Task.detached(priority: .userInitiated) {
            let cappedPaths = paths.prefix(maxResultCount)
            var items: [FileItem] = []
            items.reserveCapacity(cappedPaths.count)
            for path in cappedPaths {
                if Task.isCancelled {
                    return
                }
                // FileItem resolves the icon from `.effectiveIcon` in its resourceValues batch;
                // a per-path NSWorkspace.icon IPC here cost seconds on a broad Spotlight result set.
                items.append(FileItem.load(url: URL(fileURLWithPath: path)))
            }
            await MainActor.run {
                completion(items)
            }
        }
    }
}
