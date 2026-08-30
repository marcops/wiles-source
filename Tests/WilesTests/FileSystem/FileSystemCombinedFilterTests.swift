import AppKit
import Foundation
@testable import Wiles

/// Multi-token search combinations for `FileSystemService.loadDirectoryContents` — `kind:` + `size:`
/// + `date:` + `tag:` + plain text + regex tokens ANDed together, including order-independence and a
/// full 63-combination truth table. Split out of `FileSystemSearchAndSortTests` to stay under the
/// `file_length` limit.
@MainActor
public struct FileSystemCombinedFilterTests {
    public static func run() async {
        await testComboKindSizeText()
        await testComboIsOrderIndependent()
        await testComboKindAndRegex()
        await testComboSizeAndCaseSensitiveRegex()
        await testComboKindSizeTextAndRegex()
        await testAllFilterTokenCombinations()
    }

    private static func tempDir() -> URL {
        URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    }

    private static func load(
        at url: URL, query: String = "", sort: SortOption = .name, ascending: Bool = true, showHidden: Bool = false,
        scope: SearchScope = .name, caseSensitive: Bool = false) async -> [FileItem] {
        await (try? FileSystemService.loadDirectoryContents(
            at: url,
            options: DirectoryLoadOptions(
                showHidden: showHidden, showTags: false, searchQuery: query, sortOption: sort, sortAscending: ascending,
                searchScope: scope, searchCaseSensitive: caseSensitive))) ?? []
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("FileSystem/SearchAndSort", name, result: result)
    }

    /// `kind:` + `size:` + plain text combined must AND together — only a file matching all three
    /// survives, not just the last token evaluated.
    private static func testComboKindSizeText() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("invoice_march.pdf"))
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("invoice_march.txt"))
        try? Data(repeating: 0, count: 10).write(to: dir.appendingPathComponent("invoice_small.pdf"))
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("receipt.pdf"))

        let results = await load(at: dir, query: "kind:pdf size:>1k invoice")
        report(
            "POS: \"kind:pdf size:>1k invoice\" only matches the file satisfying all three tokens",
            result: results.count == 1 && results.first?.name == "invoice_march.pdf")
    }

    /// Same combo as above, tokens reordered — AND across tokens must not depend on token order.
    private static func testComboIsOrderIndependent() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("invoice_march.pdf"))
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("invoice_march.txt"))
        try? Data(repeating: 0, count: 10).write(to: dir.appendingPathComponent("invoice_small.pdf"))

        let results = await load(at: dir, query: "invoice size:>1k kind:pdf")
        report(
            "POS: reordering the same tokens (\"invoice size:>1k kind:pdf\") yields the same match",
            result: results.count == 1 && results.first?.name == "invoice_march.pdf")
    }

    /// `kind:` combined with a wildcard/regex token — the regex must apply to that token only, not
    /// swallow the whole query string (which would include the literal "kind:pdf " prefix and never
    /// match any real filename).
    private static func testComboKindAndRegex() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("IMG_0001.pdf"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("IMG_abc.pdf"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("IMG_0002.txt"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "kind:pdf r:^IMG_\\d+")
        report(
            "POS: \"kind:pdf r:^IMG_\\\\d+\" matches only the pdf whose name satisfies the regex token",
            result: results.count == 1 && results.first?.name == "IMG_0001.pdf")
    }

    /// A `size:` filter combined with a case-sensitive regex token — proves the case-sensitivity
    /// flag reaches per-token regex compilation, not just the plain-text substring path.
    private static func testComboSizeAndCaseSensitiveRegex() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("OnlyUpper_Report.txt"))

        let insensitive = await load(at: dir, query: "size:>1k r:report", caseSensitive: false)
        report("POS: case-insensitive regex token matches \"Report\" against pattern \"report\"", result: insensitive.count == 1)

        let sensitive = await load(at: dir, query: "size:>1k r:report", caseSensitive: true)
        report("NEG: case-sensitive regex token does not match \"Report\" against lowercase pattern \"report\"", result: sensitive.isEmpty)
    }

    /// All four token types at once — `kind:`, `size:`, plain text, and a regex token — must all AND
    /// together correctly regardless of order.
    private static func testComboKindSizeTextAndRegex() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("Invoice_IMG_0001.pdf"))
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("Invoice_IMG_abc.pdf"))
        try? Data(repeating: 0, count: 10).write(to: dir.appendingPathComponent("Invoice_IMG_0002.pdf"))
        try? Data(repeating: 0, count: 2000).write(to: dir.appendingPathComponent("Invoice_IMG_0003.txt"))

        let results = await load(at: dir, query: "kind:pdf size:>1k invoice r:IMG_\\d+")
        report(
            "POS: kind: + size: + text + regex all combined match only the single file satisfying every token",
            result: results.count == 1 && results.first?.name == "Invoice_IMG_0001.pdf")
    }

    /// Truth-table coverage: every non-empty subset of the 6 token types (`kind:`, `size:`,
    /// `date:`, `tag:`, plain text, regex) must AND together correctly — checked against every one
    /// of the 63 combinations, computed from a per-file/per-token boolean flag table, not
    /// hand-picked examples. Also checks two differently-ordered variants of the same combo.
    private static func testAllFilterTokenCombinations() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileA = dir.appendingPathComponent("Report_IMG_2024.pdf")
        let fileB = dir.appendingPathComponent("Report_IMG_2024.txt")
        let fileC = dir.appendingPathComponent("Notes_IMG_old.pdf")
        let fileD = dir.appendingPathComponent("Archive_2020.zip")
        let fileE = dir.appendingPathComponent("Report_Summary.pdf")
        let allFiles = [fileA, fileB, fileC, fileD, fileE]
        for file in allFiles {
            try? Data(repeating: 0, count: file == fileC ? 50 : 2000).write(to: file)
        }
        try? FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(-2 * 86400)], ofItemAtPath: fileC.path)
        try? FileSystemService.setTags(for: fileA, tags: ["Red"])
        try? FileSystemService.setTags(for: fileB, tags: ["Red"])

        // Each token's ground-truth match per file — the expected result for any AND-combination
        // is just the intersection of the selected tokens' `true` files.
        let tokens: [(query: String, matches: Set<URL>)] = [
            ("kind:pdf", [fileA, fileC, fileE]),
            ("size:>1k", [fileA, fileB, fileD, fileE]),
            ("date:>=1d", [fileC]),
            ("tag:Red", [fileA, fileB]),
            ("Report", [fileA, fileB, fileE]),
            ("r:IMG", [fileA, fileB, fileC])
        ]

        var failures: [String] = []
        for mask in 1 ..< (1 << tokens.count) {
            let selected = (0 ..< tokens.count).filter { mask & (1 << $0) != 0 }.map { tokens[$0] }
            let query = selected.map(\.query).joined(separator: " ")
            let expected = selected.reduce(Set(allFiles)) { $0.intersection($1.matches) }

            let results = await load(at: dir, query: query)
            let actual = Set(results.map(\.url))
            if actual != expected {
                failures.append(query)
            }
        }
        report("POS: all \(63) non-empty combinations of kind:/size:/date:/tag:/text/regex tokens AND correctly", result: failures.isEmpty)

        let forward = await load(at: dir, query: "kind:pdf size:>1k Report r:IMG")
        let reversed = await load(at: dir, query: "r:IMG Report size:>1k kind:pdf")
        report(
            "POS: a 4-token combo returns the same result regardless of token order",
            result: Set(forward.map(\.url)) == Set(reversed.map(\.url)) && Set(forward.map(\.url)) == [fileA])
    }
}
