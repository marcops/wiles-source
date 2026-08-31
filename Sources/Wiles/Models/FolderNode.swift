import Foundation

struct FolderNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let url: URL
    var children: [Self]?
    let hasSubfolders: Bool

    /// Shallow on purpose: comparing `children` by mapping to `id`s (one level) instead of the
    /// synthesized deep recursive comparison. A deep compare walks the whole subtree on every
    /// SwiftUI diff of a `@State`-held tree — on the real (large, deeply nested) home-directory
    /// tree, that's slow enough to visibly hang the sidebar when a node expands. Still distinguishes
    /// nil vs. empty children and different child sets, which is all callers rely on.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.url == rhs.url &&
            lhs.hasSubfolders == rhs.hasSubfolders &&
            lhs.children?.map(\.id) == rhs.children?.map(\.id)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Synchronous recursive disk walk (`contentsOfDirectory` + per-entry `resourceValues` for `/`,
    /// `/Users`, `~`). Callers MUST run this inside `Task.detached` — a `body`/`init` call site would
    /// beachball proportional to `~`. Prefer `buildRootTreeOffMainActor()`, which makes that structural.
    static func buildRootTree() -> Self {
        let root = URL(fileURLWithPath: "/")
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL
        let children = loadSubfolders(at: root, autoExpandFor: home, ancestorRealPaths: [root.resolvingSymlinksInPath().path])
        return Self(id: root, name: "Root (/)", url: root, children: children, hasSubfolders: !children.isEmpty)
    }

    /// `buildRootTree()` with the off-main guarantee made structural (R3) rather than a call-site
    /// convention. Preferred entry point for anything reached from a View.
    static func buildRootTreeOffMainActor() async -> Self {
        await CancellableWork.detached(priority: .userInitiated) { buildRootTree() }
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
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .linkCountKey])
            guard values?.isDirectory ?? false else { continue }

            let stdURL = url.standardizedFileURL
            let name = stdURL.lastPathComponent
            let realPath = stdURL.resolvingSymlinksInPath().path
            let isAncestorOrHome = homeURL.isDescendantOrSelf(of: stdURL)

            var children: [Self]?
            if isAncestorOrHome, !ancestorRealPaths.contains(realPath) {
                children = loadSubfolders(at: stdURL, autoExpandFor: homeURL, ancestorRealPaths: ancestorRealPaths.union([realPath]))
            }
            let loadedChildren = (children?.isEmpty ?? false) ? nil : children
            let hasSubfolders = loadedChildren.map { !$0.isEmpty } ?? mayHaveSubfolders(linkCount: values?.linkCount, url: stdURL)
            nodes.append(Self(id: stdURL, name: name, url: stdURL, children: loadedChildren, hasSubfolders: hasSubfolders))
        }
        return nodes.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// A directory's hard-link count is 2 (its own `.` plus the parent's entry for it) plus one per
    /// child subdirectory on POSIX/APFS/HFS+ — so `> 2` answers "has subfolders" from the `stat`
    /// already done, without an `enumerator` per sibling. Some network mounts report an unreliable
    /// count (< 2); there, fall back to the first-hit enumerator probe.
    private static func mayHaveSubfolders(linkCount: Int?, url: URL) -> Bool {
        guard let linkCount, linkCount >= 2 else { return directoryHasSubfolder(at: url) }
        return linkCount > 2
    }

    /// Uses a lazy `FileManager.enumerator` (not `contentsOfDirectory`) so a folder with thousands
    /// of children doesn't get fully materialized just to answer a yes/no question — this bails on
    /// the first subdirectory found.
    private static func directoryHasSubfolder(at url: URL) -> Bool {
        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsSubdirectoryDescendants, .skipsPackageDescendants]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options,
            // Skip an unreadable child instead of aborting on the first one and wrongly answering
            // "no subfolders" (→ folder shown as non-expandable). R1 / BA-509.
            errorHandler: { _, _ in true })
        else {
            return false
        }
        for case let childURL as URL in enumerator
            where (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false {
            return true
        }
        return false
    }
}
