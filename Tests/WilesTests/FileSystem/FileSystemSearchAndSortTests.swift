import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct FileSystemSearchAndSortTests {
    public static func run() async {
        await testHiddenFilesFilter()
        await testTextSearch()
        await testWildcardRegexSearch()
        await testRPrefixRegexSearch()
        await testKindFilter()
        await testFolderKindFilter()
        await testSizeFilter()
        await testDateFilterToday()
        await testSortByNameAscendingAndDescending()
        await testSortBySize()
        await testDirectoriesAlwaysSortFirst()
        await testSetTagsRoundTrip()
        await testDateFilterEdgeCases()
        await testSizeFilterEdgeCases()
        testDirectSearchFilterServiceGuardFailures()
        await testSearchScopeNameExcludesContentMatches()
        await testSearchScopeContentExcludesNameOnlyMatches()
        await testSearchScopeBothMatchesEither()
        await testCaseSensitiveSearch()
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
        await FileSystemService.loadDirectoryContents(
            at: url,
            options: DirectoryLoadOptions(
                showHidden: showHidden, showTags: false, searchQuery: query, sortOption: sort, sortAscending: ascending,
                searchScope: scope, searchCaseSensitive: caseSensitive))
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("FileSystem/SearchAndSort", name, result: result)
    }

    private static func testHiddenFilesFilter() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)

        let withoutHidden = await load(at: dir, showHidden: false)
        report("NEG: hidden dotfiles are excluded when showHidden is false", result: !withoutHidden.contains { $0.name == ".hidden.txt" })

        let withHidden = await load(at: dir, showHidden: true)
        report("POS: hidden dotfiles are included when showHidden is true", result: withHidden.contains { $0.name == ".hidden.txt" })
    }

    private static func testTextSearch() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("invoice_march.pdf"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("receipt.pdf"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "invoice")
        report("POS: plain text search matches filenames case-insensitively", result: results.count == 1 && results.first?.name == "invoice_march.pdf")
    }

    private static func testWildcardRegexSearch() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("report_2024.csv"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("summary.csv"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "report_*")
        report("POS: wildcard query (*) is treated as a regex pattern", result: results.count == 1 && results.first?.name == "report_2024.csv")
    }

    private static func testRPrefixRegexSearch() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("IMG_0001.jpg"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "r:^IMG_\\d+")
        report("POS: \"r:\" prefix forces the raw regex pattern that follows", result: results.count == 1 && results.first?.name == "IMG_0001.jpg")
    }

    private static func testKindFilter() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("photo.png"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("script.swift"), atomically: true, encoding: .utf8)

        let images = await load(at: dir, query: "kind:image")
        report("POS: \"kind:image\" matches known image extensions", result: images.count == 1 && images.first?.name == "photo.png")

        let code = await load(at: dir, query: "ext:swift")
        report("POS: \"ext:\" filters by exact extension", result: code.count == 1 && code.first?.name == "script.swift")
    }

    private static func testFolderKindFilter() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("Subfolder"), withIntermediateDirectories: true)
        try? "x".write(to: dir.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let folders = await load(at: dir, query: "kind:folder")
        report("POS: \"kind:folder\" matches only directories", result: folders.count == 1 && folders.first?.name == "Subfolder")
    }

    private static func testSizeFilter() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 10).write(to: dir.appendingPathComponent("small.bin"))
        try? Data(repeating: 0, count: 5000).write(to: dir.appendingPathComponent("big.bin"))

        let bigger = await load(at: dir, query: "size:>1k")
        report("POS: \"size:>1k\" filters files above a threshold in kilobytes", result: bigger.count == 1 && bigger.first?.name == "big.bin")

        let smaller = await load(at: dir, query: "size:<1k")
        report("NEG: \"size:<1k\" excludes the larger file", result: smaller.count == 1 && smaller.first?.name == "small.bin")
    }

    private static func testDateFilterToday() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("today_file.txt"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "date:today")
        report("POS: \"date:today\" matches a file just created", result: results.count == 1 && results.first?.name == "today_file.txt")
    }

    private static func testSortByNameAscendingAndDescending() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("banana.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("cherry.txt"), atomically: true, encoding: .utf8)

        let ascending = await load(at: dir, sort: .name, ascending: true)
        report("POS: sortOption .name ascending orders A→Z", result: ascending.map(\.name) == ["apple.txt", "banana.txt", "cherry.txt"])

        let descending = await load(at: dir, sort: .name, ascending: false)
        report("POS: sortOption .name descending orders Z→A", result: descending.map(\.name) == ["cherry.txt", "banana.txt", "apple.txt"])
    }

    private static func testSortBySize() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? Data(repeating: 0, count: 300).write(to: dir.appendingPathComponent("medium.bin"))
        try? Data(repeating: 0, count: 100).write(to: dir.appendingPathComponent("small.bin"))
        try? Data(repeating: 0, count: 900).write(to: dir.appendingPathComponent("large.bin"))

        let results = await load(at: dir, sort: .size, ascending: true)
        report("POS: sortOption .size ascending orders smallest to largest", result: results.map(\.name) == ["small.bin", "medium.bin", "large.bin"])
    }

    private static func testDirectoriesAlwaysSortFirst() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("aaa_file.txt"), atomically: true, encoding: .utf8)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("zzz_folder"), withIntermediateDirectories: true)

        let results = await load(at: dir, sort: .name, ascending: true)
        report("POS: folders always sort before files regardless of name-based ordering", result: results.first?.name == "zzz_folder")
    }

    /// Covers matchesDateFilter's digit-parse guard failure (no numeric digits in the value) and the
    /// week/month/year unit branches of dateFilterSeconds, none of which the "today"/"yesterday"/hour
    /// tests elsewhere exercise.
    private static func testDateFilterEdgeCases() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("dated.txt"), atomically: true, encoding: .utf8)

        let noDigits = await load(at: dir, query: "date:>=xh")
        report("NEG: \"date:\" filter with no numeric digits in the value matches nothing", result: noDigits.isEmpty)

        let byWeek = await load(at: dir, query: "date:>=1w")
        report("POS: \"date:>=Nw\" applies the week unit without crashing", result: byWeek.isEmpty)

        let byMonth = await load(at: dir, query: "date:>=1m")
        report("POS: \"date:>=Nm\" applies the month unit without crashing", result: byMonth.isEmpty)

        let byYear = await load(at: dir, query: "date:>=1y")
        report("POS: \"date:>=Ny\" applies the year unit without crashing", result: byYear.isEmpty)
    }

    /// Covers matchesSizeFilter's default (">=") operator branch — reached when the value has no
    /// explicit </<=/=/> prefix — and sizeFilterMultiplier's default (megabyte) branch, reached for
    /// any unit other than "k"/"b"/"g" (including no unit at all, or "m").
    private static func testSizeFilterEdgeCases() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("no_operator.bin")
        try? Data(repeating: 0, count: 500).write(to: file)

        let defaultOperator = await load(at: dir, query: "size:500b")
        report(
            "POS: \"size:Nb\" with no explicit operator defaults to >= and matches an exact-size file",
            result: defaultOperator.count == 1 && defaultOperator.first?.name == "no_operator.bin")

        let defaultMultiplier = await load(at: dir, query: "size:>1m")
        report("NEG: \"size:>Nm\" applies the default megabyte multiplier, excluding a 500-byte file", result: defaultMultiplier.isEmpty)
    }

    /// Covers guard-failure branches reached only when resourceValues() itself fails or the file's
    /// content can't be decoded: matchesDateFilter/matchesSizeFilter's "resourceValues failed" guard,
    /// and matchesContent's size-check and UTF-8-decode guards. Calling SearchFilterService directly
    /// (rather than through loadDirectoryContents, which only ever sees real directory entries) lets a
    /// deliberately nonexistent URL reach these guards.
    private static func testDirectSearchFilterServiceGuardFailures() {
        let missingFile = tempDir().appendingPathComponent("missing.txt")
        let dateResult = SearchFilterService.matchesSearch(fileURL: missingFile, query: "date:>=1d", tokenRegexes: [:], scope: .name, caseSensitive: false)
        report("NEG: matchesSearch with a \"date:\" query on a nonexistent file returns false (resourceValues guard)", result: !dateResult)

        let sizeResult = SearchFilterService.matchesSearch(fileURL: missingFile, query: "size:>1b", tokenRegexes: [:], scope: .name, caseSensitive: false)
        report("NEG: matchesSearch with a \"size:\" query on a nonexistent file returns false (resourceValues guard)", result: !sizeResult)

        let contentResultMissing = SearchFilterService.matchesSearch(
            fileURL: missingFile,
            query: "unicorn",
            tokenRegexes: [:],
            scope: .content,
            caseSensitive: false)
        report("NEG: matchesSearch content-search fallback on a nonexistent file returns false (resourceValues guard)", result: !contentResultMissing)

        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let invalidUTF8File = dir.appendingPathComponent("invalid_utf8.txt")
        try? Data([0xFF, 0xFE, 0xFD, 0x80, 0x81]).write(to: invalidUTF8File)
        let contentResultInvalid = SearchFilterService.matchesSearch(
            fileURL: invalidUTF8File,
            query: "unicorn",
            tokenRegexes: [:],
            scope: .content,
            caseSensitive: false)
        report("NEG: matchesSearch content-search fallback on a file with invalid UTF-8 content returns false (decode guard)", result: !contentResultInvalid)
    }

    /// Regression: "jpg" used to match Swift files that only mention "jpg" in their source.
    private static func testSearchScopeNameExcludesContentMatches() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "let extensions = [\"png\", \"jpg\", \"jpeg\"]".write(to: dir.appendingPathComponent("Utility.swift"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "jpg", scope: .name)
        report("NEG: \"name\" scope does not match a file whose content (not name) contains the query", result: results.isEmpty)
    }

    /// `.content` scope is content-only, no name fallback.
    private static func testSearchScopeContentExcludesNameOnlyMatches() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "no matching keyword here".write(to: dir.appendingPathComponent("jpg_report.txt"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "jpg", scope: .content)
        report("NEG: \"content\" scope does not match a file whose name (not content) contains the query", result: results.isEmpty)
    }

    /// `.both` matches either a name hit or a content hit.
    private static func testSearchScopeBothMatchesEither() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "no matching keyword here".write(to: dir.appendingPathComponent("jpg_report.txt"), atomically: true, encoding: .utf8)
        try? "let extensions = [\"png\", \"jpg\", \"jpeg\"]".write(to: dir.appendingPathComponent("Utility.swift"), atomically: true, encoding: .utf8)
        try? "nothing relevant".write(to: dir.appendingPathComponent("unrelated.txt"), atomically: true, encoding: .utf8)

        let results = await load(at: dir, query: "jpg", scope: .both)
        let names = Set(results.map(\.name))
        report(
            "POS: \"both\" scope matches a name-only hit and a content-only hit, and excludes non-matching files",
            result: names == ["jpg_report.txt", "Utility.swift"])
    }

    /// Case sensitivity defaults off (matches regardless of case) and, when enabled, requires an
    /// exact-case match.
    private static func testCaseSensitiveSearch() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("Report.txt"), atomically: true, encoding: .utf8)

        let insensitive = await load(at: dir, query: "report", caseSensitive: false)
        report("POS: case-insensitive (default) search matches regardless of case", result: insensitive.count == 1)

        let sensitiveWrongCase = await load(at: dir, query: "report", caseSensitive: true)
        report("NEG: case-sensitive search does not match a differently-cased query", result: sensitiveWrongCase.isEmpty)

        let sensitiveRightCase = await load(at: dir, query: "Report", caseSensitive: true)
        report("POS: case-sensitive search matches the exact case", result: sensitiveRightCase.count == 1)
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

    private static func testSetTagsRoundTrip() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("tagged.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)

        try? FileSystemService.setTags(for: file, tags: ["Red", "Important"])
        let item = FileItem(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: setTags() writes Finder tags that FileItem subsequently reads back", result: Set(item.tags) == Set(["Red", "Important"]))
    }
}
