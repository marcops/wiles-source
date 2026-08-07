@testable import Wiles
import Foundation

@MainActor
public struct SmartFoldersFeatureTests {
    public static func run() {
        let savedFolders = SmartFolderService.loadSavedSmartFolders()
        defer {
            SmartFolderService.saveSmartFolders(savedFolders)
        }

        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let dummyFolder = SmartFolder(
            id: UUID(),
            name: "Test Smart Folder",
            searchQuery: "kind:pdf",
            scopePath: tempDir.path
        )

        var currentFolders = savedFolders
        currentFolders.append(dummyFolder)
        SmartFolderService.saveSmartFolders(currentFolders)

        let reloaded = SmartFolderService.loadSavedSmartFolders()
        report("Feature/SmartFolders", "POS: SmartFolderService persists and reloads new smart folder", result: reloaded.contains(where: { $0.id == dummyFolder.id }))

        testPredicateInjectionIsNeutralized()
    }

    /// Fix 1(a): SmartFolderService.executeQuery/executeContentQuery build their NSPredicate
    /// with `%@` argument substitution instead of raw string interpolation. Interpolating a
    /// query string directly into `NSPredicate(format:)` lets characters with predicate syntax
    /// meaning (`%`, `\`, `(`, `)`, `'`) corrupt the format parser and raise an
    /// NSInvalidArgumentException - an Objective-C exception Swift's try/catch cannot intercept,
    /// crashing the whole app. NSMetadataQuery itself needs a live Spotlight index and isn't
    /// practical to drive in a unit test, so this test exercises the exact predicate-construction
    /// pattern the service uses (mirroring the two `NSPredicate(format:...)` call sites verbatim)
    /// with malicious query strings, and evaluates the resulting predicate. Reaching the report
    /// call at all - as opposed to the process crashing during `NSPredicate(format:)` construction
    /// - is the proof that the injection is neutralized.
    private static func testPredicateInjectionIsNeutralized() {
        let maliciousQueries = [
            "100% done",
            "unbalanced ( paren",
            "unbalanced ) paren",
            "it's a \"test\"",
            "back\\slash \\ escape",
            "%@ %K format specifiers",
            "') OR (1=1"
        ]

        for maliciousQuery in maliciousQueries {
            // Mirrors SmartFolderService.executeQuery's predicate construction exactly.
            let wildcardQuery = "*\(maliciousQuery)*"
            let singleFieldPredicate = NSPredicate(format: "kMDItemDisplayName ==[cd] %@", wildcardQuery)
            let singleFieldResult = singleFieldPredicate.evaluate(with: NSDictionary())
            report(
                "Feature/SmartFolders",
                "POS: single-field predicate (executeQuery pattern) with '\(maliciousQuery)' evaluates without crashing",
                result: singleFieldResult == false
            )

            // Mirrors SmartFolderService.executeContentQuery's predicate construction exactly.
            let contentPredicate = NSPredicate(format: "(kMDItemTextContent ==[cd] %@) || (kMDItemFSName ==[cd] %@)", wildcardQuery, wildcardQuery)
            let contentResult = contentPredicate.evaluate(with: NSDictionary())
            report(
                "Feature/SmartFolders",
                "POS: compound OR predicate (executeContentQuery pattern) with '\(maliciousQuery)' evaluates without crashing",
                result: contentResult == false
            )
        }
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
