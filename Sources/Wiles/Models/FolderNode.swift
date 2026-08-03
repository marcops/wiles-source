import Foundation

struct FolderNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    var children: [Self]?

    static func buildRootTree() -> Self {
        let root = URL(fileURLWithPath: "/")
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let children = loadSubfolders(at: root, autoExpandFor: home)
        return Self(id: root, name: "Root (/)", url: root, children: children)
    }

    private static func loadSubfolders(at folderURL: URL, autoExpandFor homeURL: URL) -> [Self] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]

        guard let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }

        var nodes: [Self] = []
        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if !isDir { continue }

            let stdURL = url.standardizedFileURL
            let name = stdURL.lastPathComponent
            let isAncestorOrHome = homeURL.path.hasPrefix(stdURL.path)

            let children = isAncestorOrHome ? loadSubfolders(at: stdURL, autoExpandFor: homeURL) : nil
            nodes.append(Self(id: stdURL, name: name, url: stdURL, children: children?.isEmpty == true ? nil : children))
        }
        return nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
