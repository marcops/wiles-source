import Foundation
@testable import Wiles

@MainActor
public struct BoundedFolderNodeCacheTests {
    public static func run() {
        testGetSetRoundTrip()
        testOverwriteExistingKeyUpdatesValueAndAccounting()
        testSetNilRemovesExistingEntry()
        testSetNilOnMissingKeyIsSafeNoOp()
        testEvictionRemovesOldestEntryFirstWhenOverCapacity()
        testEvictionStopsOnceUnderCapacity()
    }

    private static func node(name: String, base: URL) -> FolderNode {
        let url = base.appendingPathComponent(name)
        return FolderNode(id: url, name: name, url: url, children: nil, hasSubfolders: false)
    }

    private static func baseURL() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func testGetSetRoundTrip() {
        var cache = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        report("Model/BoundedFolderNodeCache", "NEG: get on an empty cache returns nil", result: cache[key] == nil)

        let nodes = [node(name: "a", base: base), node(name: "b", base: base)]
        cache[key] = nodes
        report("Model/BoundedFolderNodeCache", "POS: get after set returns the stored nodes", result: cache[key] == nodes)
    }

    private static func testOverwriteExistingKeyUpdatesValueAndAccounting() {
        var cache = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        cache[key] = [node(name: "first", base: base)]
        let secondValue = [node(name: "second-longer-name", base: base), node(name: "third", base: base)]
        cache[key] = secondValue

        report(
            "Model/BoundedFolderNodeCache",
            "POS: setting an existing key again replaces the stored value (covers the removeValue-then-reinsert branch)",
            result: cache[key] == secondValue)
    }

    private static func testSetNilRemovesExistingEntry() {
        var cache = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        cache[key] = [node(name: "a", base: base)]
        cache[key] = nil

        report("Model/BoundedFolderNodeCache", "POS: assigning nil to an existing key removes it", result: cache[key] == nil)
    }

    private static func testSetNilOnMissingKeyIsSafeNoOp() {
        var cache = BoundedFolderNodeCache()
        let key = baseURL().appendingPathComponent("never-inserted")

        // Covers the `guard let newValue else { return }` branch with no prior entry either
        // (the `if let existing = storage.removeValue` branch also takes its false path here).
        cache[key] = nil

        report("Model/BoundedFolderNodeCache", "NEG: assigning nil to a key that was never inserted is a safe no-op", result: cache[key] == nil)
    }

    private static func testEvictionRemovesOldestEntryFirstWhenOverCapacity() {
        let base = baseURL()
        // Each node costs 128 (estimatedBytesPerNode) + name bytes + absoluteString bytes. A short
        // single-character name keeps the per-entry cost small and predictable enough to reason
        // about the exact eviction boundary below.
        let entryNode = { (name: String) in node(name: name, base: base) }

        let oneEntryCost = estimatedCost(for: [entryNode("a")])
        // Cap sized to hold exactly two entries but not three, so inserting a third forces eviction
        // of the very first (oldest) key while the second and third both survive.
        var cache = BoundedFolderNodeCache(maxBytes: oneEntryCost * 2)

        let keyA = base.appendingPathComponent("a")
        let keyB = base.appendingPathComponent("b")
        let keyC = base.appendingPathComponent("c")

        cache[keyA] = [entryNode("a")]
        cache[keyB] = [entryNode("b")]
        cache[keyC] = [entryNode("c")]

        report("Model/BoundedFolderNodeCache", "POS: inserting past capacity evicts the oldest-inserted key", result: cache[keyA] == nil)
        report("Model/BoundedFolderNodeCache", "POS: the two most-recently-inserted keys survive eviction", result: cache[keyB] != nil && cache[keyC] != nil)
    }

    private static func testEvictionStopsOnceUnderCapacity() {
        let base = baseURL()
        let entryNode = { (name: String) in node(name: name, base: base) }
        let oneEntryCost = estimatedCost(for: [entryNode("a")])

        // Cap large enough for many entries: no eviction should occur, exercising the
        // `while totalEstimatedBytes > maxBytes` loop condition's false path from the very first
        // insert (the loop body never executes).
        var cache = BoundedFolderNodeCache(maxBytes: oneEntryCost * 10)
        let keys = (0 ..< 5).map { base.appendingPathComponent("k\($0)") }
        for (index, key) in keys.enumerated() {
            cache[key] = [entryNode("k\(index)")]
        }

        let allPresent = keys.allSatisfy { cache[$0] != nil }
        report("Model/BoundedFolderNodeCache", "POS: no eviction occurs while total estimated size stays under maxBytes", result: allPresent)
    }

    /// Mirrors the private `estimatedBytes(for:)` formula so tests can size `maxBytes` precisely
    /// without reaching into the type's private implementation.
    private static func estimatedCost(for nodes: [FolderNode]) -> Int {
        let estimatedBytesPerNode = 128
        return nodes.reduce(0) { $0 + estimatedBytesPerNode + $1.name.utf8.count + $1.url.absoluteString.utf8.count }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
