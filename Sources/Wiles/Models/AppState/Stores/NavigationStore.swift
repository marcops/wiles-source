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
}
