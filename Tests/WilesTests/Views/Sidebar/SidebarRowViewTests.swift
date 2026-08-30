import XCTest
@testable import Wiles

/// `SidebarRowView.isFavoriteMissing` — the pure decision behind dimming a favorite whose
/// backing path is gone from disk (L89). Extracted from the async `FileManager` refresh so the
/// rule ("only Favorites-section rows, only when the path is missing") is testable directly.
@MainActor
final class SidebarRowViewTests: XCTestCase {
    func testFavoriteRowWithMissingPathIsMissing() {
        XCTAssertTrue(SidebarRowView.isFavoriteMissing(isFavoritesSection: true, pathExists: false))
    }

    func testFavoriteRowWithExistingPathIsNotMissing() {
        XCTAssertFalse(SidebarRowView.isFavoriteMissing(isFavoritesSection: true, pathExists: true))
    }

    func testNonFavoriteRowIsNeverMissingEvenWhenPathGone() {
        XCTAssertFalse(SidebarRowView.isFavoriteMissing(isFavoritesSection: false, pathExists: false))
    }

    func testNonFavoriteRowIsNeverMissingWhenPathExists() {
        XCTAssertFalse(SidebarRowView.isFavoriteMissing(isFavoritesSection: false, pathExists: true))
    }

    // MARK: - B18-2: favoriteStatusKey only folds in the folder-contents signal for the favorite
    // whose parent is the folder on screen, so an FSEvents refresh doesn't re-check every favorite.

    private func key(_ favorite: String, current: String, count: Int, isFavorites: Bool = true) -> String {
        SidebarRowView.favoriteStatusKey(
            favoriteURL: URL(fileURLWithPath: favorite),
            currentURL: URL(fileURLWithPath: current),
            visibleItemCount: count,
            isFavoritesSection: isFavorites)
    }

    func testNonFavoritesSectionKeyIsJustThePath() {
        XCTAssertEqual(key("/Users/x/Docs", current: "/Users/x", count: 3, isFavorites: false), "/Users/x/Docs")
        XCTAssertEqual(
            key("/Users/x/Docs", current: "/Users/x", count: 3, isFavorites: false),
            key("/Users/x/Docs", current: "/other", count: 99, isFavorites: false))
    }

    func testFavoriteNotInCurrentFolderIgnoresItemCountChanges() {
        let keyA = key("/Users/x/Projects/App", current: "/Users/x/Downloads", count: 1)
        let keyB = key("/Users/x/Projects/App", current: "/Users/x/Downloads", count: 500)
        XCTAssertEqual(keyA, keyB, "item-count churn must not re-key a favorite whose parent isn't on screen")
    }

    func testFavoriteWhoseParentIsCurrentFolderTracksItemCount() {
        let keyA = key("/Users/x/Downloads/report.pdf", current: "/Users/x/Downloads", count: 1)
        let keyB = key("/Users/x/Downloads/report.pdf", current: "/Users/x/Downloads", count: 2)
        XCTAssertNotEqual(keyA, keyB, "a favorite in the on-screen folder must re-check when that folder's contents change")
    }

    func testKeyStillChangesOnNavigation() {
        let keyA = key("/Users/x/Projects/App", current: "/Users/x/Downloads", count: 1)
        let keyB = key("/Users/x/Projects/App", current: "/Users/x/Music", count: 1)
        XCTAssertNotEqual(keyA, keyB, "navigating still re-checks favorites (catches a volume unmounted while the sidebar stayed open)")
    }
}
