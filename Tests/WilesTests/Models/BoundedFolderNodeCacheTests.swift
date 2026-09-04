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
        testReferenceSemanticsShareMutationsAcrossHolders()
    }

    /// Sidebar-freeze fix: `BoundedFolderNodeCache` is a `final class`, not a `struct`, specifically
    /// so it can be passed as a plain shared reference down the recursive tree views instead of a
    /// `@Binding` that fanned every node's independent completion out to every other node (see the
    /// type's own doc comment). This asserts the property the whole fix depends on: two holders of
    /// the "same" cache instance actually observe each other's writes, unlike a struct copy would.
    private static func testReferenceSemanticsShareMutationsAcrossHolders() {
        let shared = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        func writer(_ cache: BoundedFolderNodeCache) {
            cache[key] = [node(name: "a", base: base)]
        }
        writer(shared)

        report(
            "Model/BoundedFolderNodeCache",
            "POS: a write through one holder of the reference is visible through another holder of the same instance",
            result: shared[key] != nil)
    }

    private static func node(name: String, base: URL) -> FolderNode {
        let url = base.appendingPathComponent(name)
        return FolderNode(id: url, name: name, url: url, children: nil, hasSubfolders: false)
    }

    private static func baseURL() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func testGetSetRoundTrip() {
        let cache = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        report("Model/BoundedFolderNodeCache", "NEG: get on an empty cache returns nil", result: cache[key] == nil)

        let nodes = [node(name: "a", base: base), node(name: "b", base: base)]
        cache[key] = nodes
        report("Model/BoundedFolderNodeCache", "POS: get after set returns the stored nodes", result: cache[key] == nodes)
        report(
            "Model/BoundedFolderNodeCache",
            "POS: cachedURLs reports the standardized key of a stored entry",
            result: cache.cachedURLs == [key.standardizedFileURL])
    }

    private static func testOverwriteExistingKeyUpdatesValueAndAccounting() {
        let cache = BoundedFolderNodeCache()
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
        let cache = BoundedFolderNodeCache()
        let base = baseURL()
        let key = base.appendingPathComponent("folder")

        cache[key] = [node(name: "a", base: base)]
        cache[key] = nil

        report("Model/BoundedFolderNodeCache", "POS: assigning nil to an existing key removes it", result: cache[key] == nil)
    }

    private static func testSetNilOnMissingKeyIsSafeNoOp() {
        let cache = BoundedFolderNodeCache()
        let key = baseURL().appendingPathComponent("never-inserted")

        // Covers the `guard let newValue else { return }` branch with no prior entry either
        // (the `if let existing = storage.removeValue` branch also takes its false path here).
        cache[key] = nil

        report("Model/BoundedFolderNodeCache", "NEG: assigning nil to a key that was never inserted is a safe no-op", result: cache[key] == nil)
    }

    private static func testEvictionRemovesOldestEntryFirstWhenOverCapacity() {
        let base = baseURL()
        // Cap of two entries: inserting a third evicts the oldest (first-inserted) key while the
        // second and third both survive.
        let cache = BoundedFolderNodeCache(maxEntryCount: 2)

        let keyA = base.appendingPathComponent("a")
        let keyB = base.appendingPathComponent("b")
        let keyC = base.appendingPathComponent("c")

        cache[keyA] = [node(name: "a", base: base)]
        cache[keyB] = [node(name: "b", base: base)]
        cache[keyC] = [node(name: "c", base: base)]

        report("Model/BoundedFolderNodeCache", "POS: inserting past capacity evicts the oldest-inserted key", result: cache[keyA] == nil)
        report("Model/BoundedFolderNodeCache", "POS: the two most-recently-inserted keys survive eviction", result: cache[keyB] != nil && cache[keyC] != nil)
    }

    private static func testEvictionStopsOnceUnderCapacity() {
        let base = baseURL()
        // Cap large enough for every insert: the eviction loop's condition is false from the first
        // insert on (loop body never runs).
        let cache = BoundedFolderNodeCache(maxEntryCount: 50)
        let keys = (0 ..< 5).map { base.appendingPathComponent("k\($0)") }
        for (index, key) in keys.enumerated() {
            cache[key] = [node(name: "k\(index)", base: base)]
        }

        let allPresent = keys.allSatisfy { cache[$0] != nil }
        report("Model/BoundedFolderNodeCache", "POS: no eviction occurs while the entry count stays under the cap", result: allPresent)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
