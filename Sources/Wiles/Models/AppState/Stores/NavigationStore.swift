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
            let paths = recentOpenedURLs.map { $0.path }
            UserDefaults.standard.set(paths, forKey: DefaultsKey.recentOpenedURLs.rawValue)
        }
    }

    public init(initialURL: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let savedPath = UserDefaults.standard.string(forKey: DefaultsKey.lastOpenedFolder.rawValue)
        let resolvedURL: URL
        if let path = savedPath, FileManager.default.fileExists(atPath: path) {
            resolvedURL = URL(fileURLWithPath: path)
        } else {
            resolvedURL = initialURL
        }
        self.currentURL = resolvedURL
        self.pathText = resolvedURL.path

        if let savedRecents = UserDefaults.standard.stringArray(forKey: DefaultsKey.recentOpenedURLs.rawValue) {
            self.recentOpenedURLs = savedRecents.compactMap { path in
                FileManager.default.fileExists(atPath: path) ? URL(fileURLWithPath: path) : nil
            }
        }
    }

    public func navigateTo(_ url: URL) {
        guard url != currentURL else { return }
        HapticService.shared.play(.alignment)
        historyBack.append(currentURL)
        historyForward.removeAll()
        currentURL = url
        trackRecent(url)
    }

    public func goBack() {
        guard let previous = historyBack.popLast() else { return }
        HapticService.shared.play(.alignment)
        historyForward.append(currentURL)
        currentURL = previous
    }

    public func goForward() {
        guard let next = historyForward.popLast() else { return }
        HapticService.shared.play(.alignment)
        historyBack.append(currentURL)
        currentURL = next
    }

    public func goUp() {
        let parent = currentURL.deletingLastPathComponent()
        guard parent != currentURL else { return }
        navigateTo(parent)
    }

    private func trackRecent(_ url: URL) {
        recentOpenedURLs.removeAll { $0 == url }
        recentOpenedURLs.insert(url, at: 0)
        if recentOpenedURLs.count > 20 {
            recentOpenedURLs = Array(recentOpenedURLs.prefix(20))
        }
    }
}
