import XCTest
@testable import Wiles

/// `SaveSmartFolderSheetView.resolvedScopePath` — a smart folder saved while viewing a virtual
/// location (Recents, a `wiles://` URL) or an active smart-folder view must not persist that
/// non-directory as its `scopePath` (L95). It falls back to `""`, which `SmartFolderService`
/// already reads as the user-home search scope. A real folder is kept as-is.
@MainActor
final class SaveSmartFolderSheetTests: XCTestCase {
    func testRealFolderIsKeptAsScope() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Scope-\(UUID().uuidString)")
        let resolved = SaveSmartFolderSheetView.resolvedScopePath(currentURL: dir, isSmartFolderActive: false)
        XCTAssertEqual(resolved, dir.path)
    }

    func testRecentsVirtualURLFallsBackToEmptyScope() {
        let resolved = SaveSmartFolderSheetView.resolvedScopePath(
            currentURL: AppState.recentsVirtualURL, isSmartFolderActive: false)
        XCTAssertEqual(resolved, "")
    }

    func testWilesSchemeVirtualURLFallsBackToEmptyScope() throws {
        let resolved = try SaveSmartFolderSheetView.resolvedScopePath(
            currentURL: XCTUnwrap(URL(string: "wiles://smartfolder")), isSmartFolderActive: false)
        XCTAssertEqual(resolved, "")
    }

    func testActiveSmartFolderFallsBackToEmptyScopeEvenForRealFolder() {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Scope-\(UUID().uuidString)")
        let resolved = SaveSmartFolderSheetView.resolvedScopePath(currentURL: dir, isSmartFolderActive: true)
        XCTAssertEqual(resolved, "")
    }
}
