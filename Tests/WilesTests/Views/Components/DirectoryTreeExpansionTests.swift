import Foundation
import SwiftUI
@testable import Wiles

/// Covers `DirectoryTreeExpansion` — the adapter that lets both directory-tree node views share
/// expand/collapse logic over their different backing stores (`Set<URL>` vs `Set<String>` paths).
@MainActor
public struct DirectoryTreeExpansionTests {
    public static func run() {
        testURLSetReadInsertRemove()
        testPathSetKeysByPathString()
        testToggleFlipsState()
    }

    private static func folderURL(_ name: String) -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(name)
    }

    private static func testURLSetReadInsertRemove() {
        var storage: Set<URL> = []
        let adapter = DirectoryTreeExpansion.urlSet(Binding(get: { storage }, set: { storage = $0 }))
        let url = folderURL("alpha")

        report("NEG: urlSet reports an absent URL as collapsed", result: !adapter.isExpanded(url))
        adapter.toggle(url)
        report("POS: urlSet toggle inserts the full URL and reports it expanded", result: storage == [url] && adapter.isExpanded(url))
        adapter.toggle(url)
        report("POS: urlSet toggle removes the URL again", result: storage.isEmpty && !adapter.isExpanded(url))
    }

    private static func testPathSetKeysByPathString() {
        var storage: Set<String> = []
        let adapter = DirectoryTreeExpansion.pathSet(Binding(get: { storage }, set: { storage = $0 }))
        let url = folderURL("beta")

        adapter.toggle(url)
        report("POS: pathSet stores the folder's path string, not the URL", result: storage == [url.path])
        report("POS: pathSet reads back expansion via the path string", result: adapter.isExpanded(url))
        adapter.toggle(url)
        report("POS: pathSet toggle clears the path entry", result: storage.isEmpty)
    }

    private static func testToggleFlipsState() {
        let sentinel = "sentinel-entry"
        var storage: Set<String> = [sentinel]
        let adapter = DirectoryTreeExpansion.pathSet(Binding(get: { storage }, set: { storage = $0 }))
        let url = folderURL("gamma")

        adapter.toggle(url)
        adapter.toggle(url)
        report("POS: a full toggle cycle leaves unrelated entries untouched", result: storage == [sentinel])
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("View/DirectoryTreeExpansion", name, result: result)
    }
}
