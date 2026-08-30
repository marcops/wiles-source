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
        await testDirectoryListingIsCappedWithTruncationSignal()
        await testSizeFilterEdgeCases()
        testDirectSearchFilterServiceGuardFailures()
        testExtractHiddenFlag()
        await testSearchScopeNameExcludesContentMatches()
        await testSearchScopeContentExcludesNameOnlyMatches()
        await testSearchScopeBothMatchesEither()
        await testCaseSensitiveSearch()
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
        for name in ["photo.png", "script.swift", "modern.heic", "bundle.zip", "bundle.tar"] {
            try? "x".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }

        let images = await load(at: dir, query: "kind:image")
        report(
            "POS: \"kind:image\" matches by UTType conformance, not a stale hardcoded list",
            result: Set(images.map(\.name)) == ["photo.png", "modern.heic"])
        let archives = await load(at: dir, query: "kind:archive")
        report("POS: \"kind:archive\" matches archive types by UTType conformance", result: Set(archives.map(\.name)) == ["bundle.zip", "bundle.tar"])
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
    /// explicit </<=/=/> prefix — and sizeFilterMultiplier's unit matching: bare/`m` → MB,
    /// recognized words (`b`/`bytes`, `k`/`kb`, `g`/`gb`), and an unrecognized unit → filter fails
    /// (L5 regression: `10bytes` used to be silently read as 10 MB).
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

        // L5: the full word "bytes" is a byte unit, not MB — a 500-byte file matches "size:>100bytes".
        let wordUnit = await load(at: dir, query: "size:>100bytes")
        report("POS: \"size:>Nbytes\" is treated as bytes, not megabytes", result: wordUnit.count == 1)

        // An unrecognized unit makes the whole size filter fail rather than defaulting to MB.
        let unknownUnit = await load(at: dir, query: "size:>1bogus")
        report("NEG: \"size:>Nbogus\" (unknown unit) matches nothing instead of silently meaning MB", result: unknownUnit.isEmpty)
    }

    /// Covers guard-failure branches reached only when resourceValues() itself fails or the file's
    /// content can't be decoded: matchesDateFilter/matchesSizeFilter's "resourceValues failed" guard,
    /// and matchesContent's size-check and UTF-8-decode guards. Calling SearchFilterService directly
    /// (rather than through loadDirectoryContents, which only ever sees real directory entries) lets a
    /// deliberately nonexistent URL reach these guards.
    private static func testDirectSearchFilterServiceGuardFailures() {
        let missingFile = tempDir().appendingPathComponent("missing.txt")
        func matches(_ query: String, scope: SearchScope) -> Bool {
            SearchFilterService.matchesSearch(
                fileURL: missingFile,
                parsed: SearchFilterService.parsedQuery(query: query, scope: scope, caseSensitive: false),
                scope: scope, caseSensitive: false)
        }
        let dateResult = matches("date:>=1d", scope: .name)
        report("NEG: matchesSearch with a \"date:\" query on a nonexistent file returns false (resourceValues guard)", result: !dateResult)

        let sizeResult = matches("size:>1b", scope: .name)
        report("NEG: matchesSearch with a \"size:\" query on a nonexistent file returns false (resourceValues guard)", result: !sizeResult)

        let contentResultMissing = matches("unicorn", scope: .content)
        report("NEG: matchesSearch content-search fallback on a nonexistent file returns false (resourceValues guard)", result: !contentResultMissing)

        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // A non-UTF-8 (Latin-1) text file whose content matches must still be found — content
        // search falls back past UTF-8 instead of silently skipping the file.
        let latin1File = dir.appendingPathComponent("latin1.txt")
        try? "café doré résumé".data(using: .isoLatin1)?.write(to: latin1File)
        func contentMatch(_ query: String) -> Bool {
            SearchFilterService.matchesSearch(
                fileURL: latin1File,
                parsed: SearchFilterService.parsedQuery(query: query, scope: .content, caseSensitive: false),
                scope: .content, caseSensitive: false)
        }
        report("POS: content search decodes a non-UTF-8 (Latin-1) text file instead of skipping it", result: contentMatch("caf"))
        report("NEG: a decoded non-UTF-8 file that doesn't contain the query still returns false", result: !contentMatch("unicorn"))
    }

    /// `extractHiddenFlag` pulls the global "hidden:true" token out of the query before per-file
    /// filter tokens are matched, since it's a search-wide setting, not a per-file predicate.
    private static func testExtractHiddenFlag() {
        let (strippedYes, includeHiddenYes) = SearchFilterService.extractHiddenFlag(from: "report hidden:true kind:pdf")
        report(
            "POS: extractHiddenFlag strips \"hidden:true\" and reports includeHidden true",
            result: includeHiddenYes && strippedYes == "report kind:pdf")

        let (strippedNo, includeHiddenNo) = SearchFilterService.extractHiddenFlag(from: "report kind:pdf")
        report(
            "NEG: extractHiddenFlag leaves the query untouched and reports includeHidden false when absent",
            result: !includeHiddenNo && strippedNo == "report kind:pdf")

        let (strippedCase, includeHiddenCase) = SearchFilterService.extractHiddenFlag(from: "HIDDEN:TRUE report")
        report(
            "POS: extractHiddenFlag matches \"hidden:true\" case-insensitively",
            result: includeHiddenCase && strippedCase == "report")
    }

    // `toggleToken`/`containsToken` back the composing quick-filter buttons in `HeaderBarView`:
    // a `prefix:value` token is appended if absent, stripped if present, and free text is kept.

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

    private static func testSetTagsRoundTrip() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("tagged.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: file, tags: ["Red", "Important"])
        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path), fetchTags: true)
        report("POS: setTags() writes Finder tags that FileItem subsequently reads back", result: Set(item.tags) == Set(["Red", "Important"]))
    }

    /// A folder with more than `directoryListingLimit` entries is capped, and the caller learns the
    /// list was cut (so `AppState` can show "showing the first N") instead of reading it as complete.
    private static func testDirectoryListingIsCappedWithTruncationSignal() async {
        let dir = tempDir()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let overCap = FileSystemService.directoryListingLimit + 25
        for index in 0 ..< overCap {
            FileManager.default.createFile(atPath: dir.appendingPathComponent("f\(index).txt").path, contents: nil)
        }

        let loaded = await load(at: dir)
        report(
            "POS: a directory listing is capped at directoryListingLimit entries",
            result: loaded.count == FileSystemService.directoryListingLimit)

        let appState = AppState()
        appState.applyLoadedItems(
            loaded, target: appState.navigation.currentURL,
            truncatedAtCap: loaded.count >= FileSystemService.directoryListingLimit)
        report(
            "POS: applying a capped listing sets resultsTruncated so the footer can flag it",
            result: appState.fileSystem.resultsTruncated)
    }
}
