@testable import Wiles
import Foundation

@MainActor
public struct SmartFolderTests {
    public static func run() {
        let folder = SmartFolder(name: "PDFs", searchQuery: "kind:pdf", scopePath: "/Users")
        SmartFolderService.saveSmartFolders([folder])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        TestReporter.report("SmartFolder", "POS: saveSmartFolders and loadSavedSmartFolders persist folder", result: loaded.contains(where: { $0.name == "PDFs" }))

        testEmptyArrayRoundTrip()
        testMultipleFoldersFieldByFieldRoundTrip()
        testDefaultInitValues()
        testHashableEqualityIsIdentityBased()
        testSavingOverwritesPreviousData()
        testCorruptedDefaultsDataReturnsEmptyArray()
        testMissingDefaultsKeyReturnsEmptyArray()
        testSpecialCharactersRoundTripThroughPersistence()
        testFolderWithNonexistentScopePathPersistsUnchanged()
        testFolderWithEmptyScopePathPersistsAsEmpty()
    }

    private static func testDefaultInitValues() {
        // POS: default icon and a fresh, unique id/createdAt are supplied when not specified
        let before = Date()
        let folder = SmartFolder(name: "Untitled", searchQuery: "kind:any", scopePath: "")
        let after = Date()

        let iconDefaulted = folder.icon == "folder.badge.gearshape"
        let createdAtInRange = folder.createdAt >= before && folder.createdAt <= after
        TestReporter.report("SmartFolder", "POS: default init supplies default icon and createdAt within call window", result: iconDefaulted && createdAtInRange)

        let folderB = SmartFolder(name: "Untitled", searchQuery: "kind:any", scopePath: "")
        TestReporter.report("SmartFolder", "POS: default init generates a distinct id per instance", result: folder.id != folderB.id)
    }

    private static func testHashableEqualityIsIdentityBased() {
        let id = UUID()
        let date = Date()
        let folderA = SmartFolder(id: id, name: "Same", icon: "a", searchQuery: "q", scopePath: "/x", createdAt: date)
        let folderB = SmartFolder(id: id, name: "Same", icon: "a", searchQuery: "q", scopePath: "/x", createdAt: date)
        TestReporter.report("SmartFolder", "POS: two folders with identical field values are equal", result: folderA == folderB)

        let folderC = SmartFolder(name: "Same", icon: "a", searchQuery: "q", scopePath: "/x", createdAt: date)
        let folderD = SmartFolder(name: "Same", icon: "a", searchQuery: "q", scopePath: "/x", createdAt: date)
        TestReporter.report("SmartFolder", "NEG: two folders with identical fields but different auto-generated ids are not equal", result: folderC != folderD)
    }

    private static func testSavingOverwritesPreviousData() {
        // POS: saving a new set of folders fully replaces the previously persisted set, not merges it
        let original = SmartFolder(name: "Original", searchQuery: "kind:pdf", scopePath: "/Users")
        SmartFolderService.saveSmartFolders([original])

        let replacement = SmartFolder(name: "Replacement", searchQuery: "kind:doc", scopePath: "/Users")
        SmartFolderService.saveSmartFolders([replacement])

        let loaded = SmartFolderService.loadSavedSmartFolders()
        let onlyReplacementPresent = loaded.count == 1 && loaded.first?.name == "Replacement"
        TestReporter.report("SmartFolder", "POS: saveSmartFolders replaces prior contents rather than appending", result: onlyReplacementPresent)

        SmartFolderService.saveSmartFolders([])
    }

    private static func testCorruptedDefaultsDataReturnsEmptyArray() {
        // NEG: if the persisted bytes aren't valid JSON for [SmartFolder], loading fails gracefully to []
        let garbage = "not valid json".data(using: .utf8)!
        UserDefaults.standard.set(garbage, forKey: DefaultsKey.smartFolders.rawValue)

        let loaded = SmartFolderService.loadSavedSmartFolders()
        TestReporter.report("SmartFolder", "NEG: corrupted (non-JSON) persisted data decodes to an empty array instead of crashing", result: loaded.isEmpty)

        SmartFolderService.saveSmartFolders([])
    }

    private static func testMissingDefaultsKeyReturnsEmptyArray() {
        // NEG: if the key has never been written (nil), loading returns [] rather than throwing/crashing
        UserDefaults.standard.removeObject(forKey: DefaultsKey.smartFolders.rawValue)

        let loaded = SmartFolderService.loadSavedSmartFolders()
        TestReporter.report("SmartFolder", "NEG: missing UserDefaults key returns an empty array", result: loaded.isEmpty)
    }

    private static func testSpecialCharactersRoundTripThroughPersistence() {
        // POS: names/queries containing quotes, unicode, and wildcard-like characters survive JSON persistence untouched.
        // (Note: quote-stripping only happens inside executeQuery's predicate construction, never during save/load.)
        let tricky = SmartFolder(
            name: "Q3 \"Final\" Réport 🎉",
            searchQuery: "kind:pdf AND name:'it''s * a test'",
            scopePath: "/Users/tester"
        )
        SmartFolderService.saveSmartFolders([tricky])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        let matches = loaded.first(where: { $0.id == tricky.id })
        let fieldsPreserved = matches?.name == tricky.name && matches?.searchQuery == tricky.searchQuery
        TestReporter.report("SmartFolder", "POS: names/queries with quotes, unicode, and wildcards round-trip byte-for-byte through persistence", result: fieldsPreserved)

        SmartFolderService.saveSmartFolders([])
    }

    private static func testFolderWithNonexistentScopePathPersistsUnchanged() {
        // POS: scopePath validation (FileManager existence check) only happens at query-execution time,
        // never at save time - a folder pointing at a nonexistent path persists exactly as given.
        let missingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let folder = SmartFolder(name: "Ghost", searchQuery: "kind:any", scopePath: missingDir.path)

        SmartFolderService.saveSmartFolders([folder])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        let preserved = loaded.first(where: { $0.id == folder.id })?.scopePath == missingDir.path
        let stillMissing = !FileManager.default.fileExists(atPath: missingDir.path)
        TestReporter.report("SmartFolder", "POS: a scopePath pointing at a nonexistent directory persists unvalidated", result: preserved && stillMissing)

        SmartFolderService.saveSmartFolders([])
    }

    private static func testFolderWithEmptyScopePathPersistsAsEmpty() {
        // POS: an empty scopePath (used by executeQuery to fall back to NSMetadataQueryUserHomeScope) round-trips as ""
        let folder = SmartFolder(name: "HomeWide", searchQuery: "kind:any", scopePath: "")
        SmartFolderService.saveSmartFolders([folder])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        let preserved = loaded.first(where: { $0.id == folder.id })?.scopePath == ""
        TestReporter.report("SmartFolder", "POS: an empty scopePath round-trips as empty string", result: preserved)

        SmartFolderService.saveSmartFolders([])
    }

    private static func testEmptyArrayRoundTrip() {
        // POS: saving an empty array clears out any leftover data from previous saves
        SmartFolderService.saveSmartFolders([])
        let loaded = SmartFolderService.loadSavedSmartFolders()
        TestReporter.report("SmartFolder", "POS: saving an empty array then loading returns an empty array", result: loaded.isEmpty)
    }

    private static func testMultipleFoldersFieldByFieldRoundTrip() {
        let tempScopeA = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let tempScopeB = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path
        let tempScopeC = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).path

        let folderA = SmartFolder(name: "Images", icon: "photo", searchQuery: "kind:image", scopePath: tempScopeA)
        let folderB = SmartFolder(name: "Large Files", icon: "doc.fill", searchQuery: "size:>100mb", scopePath: tempScopeB)
        let folderC = SmartFolder(name: "Recent Downloads", icon: "arrow.down.circle", searchQuery: "kind:any", scopePath: tempScopeC)

        SmartFolderService.saveSmartFolders([folderA, folderB, folderC])
        let loaded = SmartFolderService.loadSavedSmartFolders()

        guard loaded.count == 3,
              let loadedA = loaded.first(where: { $0.id == folderA.id }),
              let loadedB = loaded.first(where: { $0.id == folderB.id }),
              let loadedC = loaded.first(where: { $0.id == folderC.id }) else {
            TestReporter.report("SmartFolder", "POS: saving multiple folders preserves all fields exactly on round-trip", result: false)
            return
        }

        let fieldsMatch =
            loadedA.name == folderA.name && loadedA.icon == folderA.icon &&
            loadedA.searchQuery == folderA.searchQuery && loadedA.scopePath == folderA.scopePath &&
            loadedB.name == folderB.name && loadedB.icon == folderB.icon &&
            loadedB.searchQuery == folderB.searchQuery && loadedB.scopePath == folderB.scopePath &&
            loadedC.name == folderC.name && loadedC.icon == folderC.icon &&
            loadedC.searchQuery == folderC.searchQuery && loadedC.scopePath == folderC.scopePath

        TestReporter.report(
            "SmartFolder", "POS: saving multiple folders preserves name, icon, searchQuery, and scopePath exactly on round-trip",
            result: fieldsMatch
        )

        // Clean up so this test doesn't leak state into subsequent runs.
        SmartFolderService.saveSmartFolders([])
    }
}
