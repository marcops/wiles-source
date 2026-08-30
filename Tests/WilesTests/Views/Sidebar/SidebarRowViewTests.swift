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
}
