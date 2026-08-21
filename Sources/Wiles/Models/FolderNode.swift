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
        let children = loadSubfolders(at: root, autoExpandFor: home)
        return Self(id: root, name: "Root (/)", url: root, children: children, hasSubfolders: !children.isEmpty)
    }

    /// Loads only the immediate subfolders of `folderURL`.
    static func loadChildren(of folderURL: URL) -> [Self] {
        loadSubfolders(at: folderURL.standardizedFileURL, autoExpandFor: folderURL.standardizedFileURL)
    }

    private static func loadSubfolders(at folderURL: URL, autoExpandFor homeURL: URL) -> [Self] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey]

        guard let urls = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else {
            return []
        }

        let nodes: [Self] = urls.compactMap { url in
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDir else { return nil }

            let stdURL = url.standardizedFileURL
            let name = stdURL.lastPathComponent
            let isAncestorOrHome = homeURL.path.hasPrefix(stdURL.path)

            let children = isAncestorOrHome ? loadSubfolders(at: stdURL, autoExpandFor: homeURL) : nil
            let hasSubfolders = children.map { !$0.isEmpty } ?? directoryHasSubfolder(at: stdURL)
            return Self(id: stdURL, name: name, url: stdURL, children: children?.isEmpty == true ? nil : children, hasSubfolders: hasSubfolders)
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
