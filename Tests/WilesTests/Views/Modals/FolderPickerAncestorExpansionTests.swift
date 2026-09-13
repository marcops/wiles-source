import XCTest
@testable import Wiles

/// Covers `FolderPickerSheet.mustExpandAncestorsOffMain(forPath:)` — the decision behind whether
/// `expandAncestors(of:)` dispatches its ancestor-folder scan (real `FileManager` hits, one per
/// ancestor level) off `@MainActor`. It used to say "no" for any plain local path (only
/// `/Volumes/`-style paths were treated as needing off-main dispatch), so choosing a deeply nested
/// or large local folder in the picker could freeze the whole UI for the scan's duration — the
/// same hazard `AutoOrganizationService.processFolder` already guards against unconditionally for
/// every path, local or not.
@MainActor
final class FolderPickerAncestorExpansionTests: XCTestCase {
    func testOffMainIsRequiredForAnOrdinaryLocalPath() {
        XCTAssertTrue(
            FolderPickerSheet.mustExpandAncestorsOffMain(forPath: "/Users/someone/Documents/Deeply/Nested/Folder"),
            "a plain local path's ancestor scan must not run synchronously on the main actor")
    }

    func testOffMainIsStillRequiredForASlowVolumePath() {
        XCTAssertTrue(
            FolderPickerSheet.mustExpandAncestorsOffMain(forPath: "/Volumes/SomeShare/Folder"),
            "a /Volumes/ path must keep requiring off-main dispatch")
    }
}
