import Foundation
@testable import Wiles

/// `SystemTagsService` maps Finder's `FavoriteTagNames` to `TagColor`s and caches the parsed list
/// (it's read per tag per row per render). These cover the cache contract and the color lookup.
@MainActor
public struct SystemTagsServiceTests {
    public static func run() {
        defer { SystemTagsService.invalidateCache() }
        testFavoriteTagsNonEmpty()
        testCacheIsStableAndSurvivesInvalidate()
        testColorLookupIsCaseInsensitive()
    }

    private static func report(_ name: String, _ result: Bool) {
        TestReporter.report("Services/SystemTags", name, result: result)
    }

    private static func testFavoriteTagsNonEmpty() {
        SystemTagsService.invalidateCache()
        report("POS: favoriteTags is non-empty (real Finder list or the standard-color fallback)", !SystemTagsService.favoriteTags.isEmpty)
    }

    private static func testCacheIsStableAndSurvivesInvalidate() {
        SystemTagsService.invalidateCache()
        let first = SystemTagsService.favoriteTags
        let cached = SystemTagsService.favoriteTags
        report("POS: a second read within the TTL returns the same list", first == cached)

        SystemTagsService.invalidateCache()
        let afterInvalidate = SystemTagsService.favoriteTags
        report("POS: re-reading after invalidateCache() yields the same logical list", afterInvalidate == first)
    }

    private static func testColorLookupIsCaseInsensitive() {
        SystemTagsService.invalidateCache()
        // Only assert when the environment exposes a "Red" favorite (real Finder list or fallback);
        // a fully-custom Finder tag set legitimately has no "red" entry.
        guard SystemTagsService.color(forTagNamed: "red") != nil else {
            report("SKIP: no 'Red' favorite tag in this environment — color lookup case-insensitivity not asserted", true)
            return
        }
        report(
            "POS: color(forTagNamed:) matches case-insensitively",
            SystemTagsService.color(forTagNamed: "RED") == SystemTagsService.color(forTagNamed: "red"))
    }
}
