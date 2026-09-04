import Foundation
@testable import Wiles

/// Covers `FolderNode+DirectoryTree.swift` — the non-view logic shared by the sidebar and
/// folder-picker directory trees.
@MainActor
public struct FolderNodeDirectoryTreeTests {
    public static func run() async {
        testDisplayNameLocalizesRootOnly()
        testResolvedChildrenPrefersEagerThenCache()
        testNeedsChildLoad()
        await testLoadChildrenOffMainActorMatchesSyncLoad()
    }

    private static func leaf(_ name: String, base: URL) -> FolderNode {
        let url = base.appendingPathComponent(name)
        return FolderNode(id: url, name: name, url: url, children: nil, hasSubfolders: false)
    }

    private static func testDisplayNameLocalizesRootOnly() {
        let root = FolderNode(id: URL(fileURLWithPath: "/"), name: "Root (/)", url: URL(fileURLWithPath: "/"), children: nil, hasSubfolders: true)
        report(
            "POS: displayName swaps the '/' placeholder for the localized volume label",
            result: root.displayName(rootLabel: "Macintosh HD") == "Macintosh HD")

        let base = URL(fileURLWithPath: testTemporaryDirectory())
        let child = leaf("Documents", base: base)
        report("NEG: displayName leaves a non-root node's own name untouched", result: child.displayName(rootLabel: "Macintosh HD") == "Documents")
    }

    private static func testResolvedChildrenPrefersEagerThenCache() {
        let base = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let folderURL = base.appendingPathComponent("folder")
        let eager = [leaf("eager", base: folderURL)]
        let cached = [leaf("cached", base: folderURL)]

        let cache = BoundedFolderNodeCache()
        cache[folderURL] = cached

        let withEager = FolderNode(id: folderURL, name: "folder", url: folderURL, children: eager, hasSubfolders: true)
        report("POS: resolvedChildren returns the eagerly-loaded children when present", result: withEager.resolvedChildren(in: cache) == eager)

        let lazy = FolderNode(id: folderURL, name: "folder", url: folderURL, children: nil, hasSubfolders: true)
        report("POS: resolvedChildren falls back to the lazy cache entry", result: lazy.resolvedChildren(in: cache) == cached)

        let emptyCacheNode = FolderNode(id: base, name: "base", url: base, children: nil, hasSubfolders: true)
        report(
            "NEG: resolvedChildren is nil when neither eager nor cached children exist",
            result: emptyCacheNode.resolvedChildren(in: BoundedFolderNodeCache()) == nil)
    }

    private static func testNeedsChildLoad() {
        let base = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let folderURL = base.appendingPathComponent("folder")
        let unloaded = FolderNode(id: folderURL, name: "folder", url: folderURL, children: nil, hasSubfolders: true)

        report(
            "POS: needsChildLoad is true when children are unresolved and no load is in flight",
            result: unloaded.needsChildLoad(cache: BoundedFolderNodeCache(), inFlight: []))
        report(
            "NEG: needsChildLoad is false while a load for the same URL is already in flight",
            result: !unloaded.needsChildLoad(cache: BoundedFolderNodeCache(), inFlight: [folderURL]))

        let cache = BoundedFolderNodeCache()
        cache[folderURL] = [leaf("x", base: folderURL)]
        report("NEG: needsChildLoad is false once the cache already holds this folder's children", result: !unloaded.needsChildLoad(cache: cache, inFlight: []))

        let eager = FolderNode(id: folderURL, name: "folder", url: folderURL, children: [leaf("x", base: folderURL)], hasSubfolders: true)
        report(
            "NEG: needsChildLoad is false when the node carries eagerly-loaded children",
            result: !eager.needsChildLoad(cache: BoundedFolderNodeCache(), inFlight: []))
    }

    private static func testLoadChildrenOffMainActorMatchesSyncLoad() async {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subA = root.appendingPathComponent("alpha")
        let subB = root.appendingPathComponent("beta")
        defer { try? fm.removeItem(at: root) }
        try? fm.createDirectory(at: subA, withIntermediateDirectories: true)
        try? fm.createDirectory(at: subB, withIntermediateDirectories: true)

        let offMain = await FolderNode.loadChildrenOffMainActor(of: root)
        let sync = FolderNode.loadChildren(of: root)
        report(
            "POS: loadChildrenOffMainActor returns the same result as the synchronous loadChildren",
            result: offMain.map(\.url) == sync.map(\.url) && offMain.map(\.name).sorted() == ["alpha", "beta"])
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("Model/FolderNode+DirectoryTree", name, result: result)
    }
}
