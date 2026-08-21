import Foundation
import Observation

@Observable
@MainActor
public final class NavigationStore {
    public var currentURL: URL {
        didSet {
            pathText = currentURL.path
            UserDefaults.standard.set(currentURL.path, forKey: DefaultsKey.lastOpenedFolder.rawValue)
        }
    }

    public var pathText: String = ""
    public var historyBack: [URL] = []
    public var historyForward: [URL] = []
    public var recentOpenedURLs: [URL] = [] {
        didSet {
            let paths = recentOpenedURLs.map(\.path)
            UserDefaults.standard.set(paths, forKey: DefaultsKey.recentOpenedURLs.rawValue)
        }
    }

    public init(initialURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let savedPath = UserDefaults.standard.string(forKey: DefaultsKey.lastOpenedFolder.rawValue)
        let resolvedURL: URL = if let path = savedPath, Self.existsOptimistically(atPath: path) {
            URL(fileURLWithPath: path)
        } else {
            initialURL
        }
        currentURL = resolvedURL
        pathText = resolvedURL.path

        if let savedRecents = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) {
            recentOpenedURLs = savedRecents.compactMap { path in
                Self.existsOptimistically(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
        }

        Task { [weak self] in
            await self?.validateSlowVolumePaths()
        }
    }

    /// `/Volumes/` paths (network shares, external drives) are accepted optimistically at init
    /// time instead of a synchronous `fileExists` check, which could stall window construction for
    /// seconds against a sleeping/unreachable mount (same rationale as `AppState+Navigation.swift`'s
    /// `navigateTo`). This verifies them afterward and corrects state if any turned out to be gone.
    private func validateSlowVolumePaths() async {
        let pathsToCheck = Set(([currentURL] + recentOpenedURLs).map(\.path).filter(Self.isLikelySlowVolume))
        guard !pathsToCheck.isEmpty else { return }

        let existence = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: pathsToCheck.map { ($0, FileManager.default.fileExists(atPath: $0)) })
        }.value

        if let exists = existence[currentURL.path], !exists {
            currentURL = FileManager.default.homeDirectoryForCurrentUser
        }
        recentOpenedURLs = recentOpenedURLs.filter { existence[$0.path] ?? true }
    }

    private static func isLikelySlowVolume(_ path: String) -> Bool {
        path.hasPrefix("/Volumes/")
    }

    /// Skips the synchronous `fileExists` check for a `/Volumes/` path — it's accepted as-is here
    /// and verified later off-`@MainActor` by `validateSlowVolumePaths()`.
    private static func existsOptimistically(atPath path: String) -> Bool {
        isLikelySlowVolume(path) || FileManager.default.fileExists(atPath: path)
    }
}
