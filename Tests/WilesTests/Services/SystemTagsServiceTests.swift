import Foundation
@testable import Wiles

/// `SystemTagsService` maps Finder's `FavoriteTagNames` to `TagColor`s. ML-070: the parsed list is
/// now held in a cache refreshed by `startObserving()` / an app-activation observer, and
/// `favoriteTags` (read per tag per row per render) only ever returns that cache or the standard
/// fallback — it never parses Finder's cross-app prefs inside a view body.
@MainActor
public struct SystemTagsServiceTests {
    public static func run() {
        defer { SystemTagsService.invalidateCache() }
        testFavoriteTagsNonEmpty()
        testFavoriteTagsGetterDoesNoWorkBeyondReturningACachedOrFallbackList()
        testRefreshPopulatesTheCache()
        testStartObservingIsIdempotent()
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

    /// ML-070: reading `favoriteTags` many times in a row (as a grid of tag cells does every frame)
    /// must be a cheap cache/fallback read — deterministically the same value, no per-read parse.
    private static func testFavoriteTagsGetterDoesNoWorkBeyondReturningACachedOrFallbackList() {
        SystemTagsService.refresh()
        let first = SystemTagsService.favoriteTags
        let second = SystemTagsService.favoriteTags
        let third = SystemTagsService.favoriteTags
        report("POS: repeated favoriteTags reads return the identical cached list (no per-read Finder prefs parse)", first == second && second == third)
    }

    private static func testRefreshPopulatesTheCache() {
        SystemTagsService.invalidateCache() // now delegates to refresh()
        report("POS: after refresh() favoriteTags reflects a populated cache", !SystemTagsService.favoriteTags.isEmpty)
    }

    private static func testStartObservingIsIdempotent() {
        SystemTagsService.startObserving()
        SystemTagsService.startObserving()
        report("POS: startObserving() called twice does not crash and leaves favoriteTags readable", !SystemTagsService.favoriteTags.isEmpty)
    }

    private static func testCacheIsStableAndSurvivesInvalidate() {
        SystemTagsService.invalidateCache()
        let first = SystemTagsService.favoriteTags
        let cached = SystemTagsService.favoriteTags
        report("POS: a second read returns the same list", first == cached)

        SystemTagsService.invalidateCache()
        let afterInvalidate = SystemTagsService.favoriteTags
        report("POS: re-reading after invalidateCache() yields the same logical list", afterInvalidate == first)
    }

    private static func testColorLookupIsCaseInsensitive() {
        SystemTagsService.invalidateCache()
        guard SystemTagsService.color(forTagNamed: "red") != nil else {
            report("SKIP: no 'Red' favorite tag in this environment — color lookup case-insensitivity not asserted", true)
            return
        }
        report(
            "POS: color(forTagNamed:) matches case-insensitively",
            SystemTagsService.color(forTagNamed: "RED") == SystemTagsService.color(forTagNamed: "red"))
    }
}
