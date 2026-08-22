import Foundation

struct FolderNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    var children: [Self]?
    let hasSubfolders: Bool

    static func buildRootTree() -> Self {
        let root = URL(fileURLWithPath: "/")
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let children = loadSubfolders(at: root, autoExpandFor: home, ancestorRealPaths: [root.resolvingSymlinksInPath().path])
        return Self(id: root, name: "Root (/)", url: root, children: children, hasSubfolders: !children.isEmpty)
    }

    /// Loads only the immediate subfolders of `folderURL`.
    static func loadChildren(of folderURL: URL) -> [Self] {
        let stdURL = folderURL.standardizedFileURL
        return loadSubfolders(at: stdURL, autoExpandFor: stdURL, ancestorRealPaths: [stdURL.resolvingSymlinksInPath().path])
    }

    /// `ancestorRealPaths` prevents a self-referential mount (e.g. `Macintosh HD -> /`) from
    /// recursing forever by tracking resolved paths already on the current branch.
    private static func loadSubfolders(at folderURL: URL, autoExpandFor homeURL: URL, ancestorRealPaths: Set<String>) -> [Self] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]

        guard let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            return []
        }

        var nodes: [Self] = []
        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { continue }

            let stdURL = url.standardizedFileURL
            let name = stdURL.lastPathComponent
            let realPath = stdURL.resolvingSymlinksInPath().path
            let isAncestorOrHome = homeURL.path.hasPrefix(stdURL.path)

            var children: [Self]?
            if isAncestorOrHome, !ancestorRealPaths.contains(realPath) {
                children = loadSubfolders(at: stdURL, autoExpandFor: homeURL, ancestorRealPaths: ancestorRealPaths.union([realPath]))
            }
            let hasSubfolders = children.map { !$0.isEmpty } ?? directoryHasSubfolder(at: stdURL)
            nodes.append(Self(id: stdURL, name: name, url: stdURL, children: children?.isEmpty == true ? nil : children, hasSubfolders: hasSubfolders))
        }
        return nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func directoryHasSubfolder(at url: URL) -> Bool {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let urls = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
        else {
            return false
        }
        return urls.contains { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
    }
}
