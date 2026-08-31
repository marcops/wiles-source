import XCTest
@testable import Wiles

/// Finding MM-096: a recursive "search everywhere" over Content/Both scope used to read every text
/// file under `~` from disk with no ceiling on the file count. `matchesSearch` now takes a
/// `ContentReadBudget` that caps total bytes read across the crawl; cache hits don't count.
final class SearchFilterContentBudgetTests: XCTestCase {
    private func makeDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mm096-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return dir
    }

    @discardableResult
    private func makeTextFile(_ name: String, in dir: URL, body: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func parsedContentQuery(_ query: String) -> ParsedSearchQuery {
        SearchFilterService.parsedQuery(query: query, scope: .content, caseSensitive: false)
    }

    func testContentMatchSucceedsWithinBudget() throws {
        let dir = try makeDir()
        let file = try makeTextFile("a-\(UUID().uuidString).txt", in: dir, body: "the needle is here")
        let budget = ContentReadBudget(totalBytes: 1_000_000)

        let matched = SearchFilterService.matchesSearch(
            fileURL: file, parsed: parsedContentQuery("needle"), scope: .content, caseSensitive: false,
            contentBudget: budget)

        XCTAssertTrue(matched)
        XCTAssertFalse(budget.exhausted)
        XCTAssertLessThan(budget.bytesRemaining, 1_000_000)
    }

    func testBudgetStopsReadingNewFilesOnceSpent() throws {
        let dir = try makeDir()
        let body = String(repeating: "needle ", count: 50) // ~350 bytes
        let first = try makeTextFile("first-\(UUID().uuidString).txt", in: dir, body: body)
        let second = try makeTextFile("second-\(UUID().uuidString).txt", in: dir, body: body)

        // Budget covers exactly the first file's read and no more.
        let budget = ContentReadBudget(totalBytes: body.utf8.count)
        let parsed = parsedContentQuery("needle")

        let firstMatched = SearchFilterService.matchesSearch(
            fileURL: first, parsed: parsed, scope: .content, caseSensitive: false, contentBudget: budget)
        let secondMatched = SearchFilterService.matchesSearch(
            fileURL: second, parsed: parsed, scope: .content, caseSensitive: false, contentBudget: budget)

        XCTAssertTrue(firstMatched, "the first file is within budget and its content matches")
        XCTAssertFalse(secondMatched, "the second file is past the budget — its content is never read")
        XCTAssertTrue(budget.exhausted)
    }

    func testCacheHitDoesNotConsumeBudget() throws {
        let dir = try makeDir()
        let file = try makeTextFile("cached-\(UUID().uuidString).txt", in: dir, body: "needle in a haystack")
        let parsed = parsedContentQuery("needle")

        // First match populates the content cache and spends the whole budget.
        let budget = ContentReadBudget(totalBytes: 8)
        XCTAssertTrue(SearchFilterService.matchesSearch(
            fileURL: file, parsed: parsed, scope: .content, caseSensitive: false, contentBudget: budget))
        XCTAssertTrue(budget.exhausted)

        // A fresh, empty budget still matches — the content now comes from cache, no disk read.
        let spentBudget = ContentReadBudget(totalBytes: 0)
        XCTAssertTrue(SearchFilterService.matchesSearch(
            fileURL: file, parsed: parsed, scope: .content, caseSensitive: false, contentBudget: spentBudget))
    }

    func testNilBudgetIsUnbounded() throws {
        let dir = try makeDir()
        let parsed = parsedContentQuery("needle")
        for i in 0 ..< 5 {
            let file = try makeTextFile("nb-\(i)-\(UUID().uuidString).txt", in: dir, body: "needle \(i)")
            XCTAssertTrue(SearchFilterService.matchesSearch(
                fileURL: file, parsed: parsed, scope: .content, caseSensitive: false, contentBudget: nil))
        }
    }
}
