import XCTest
@testable import Wiles

/// Standalone dedicated suite for `SystemAppearanceObserver` — follows the standalone-XCTestCase
/// precedent (see `DefaultFolderHandlerServiceTests`) since this wraps a live AppKit/
/// DistributedNotificationCenter singleton with no fake-able seam, same class of limited
/// testability as other system-observer wrappers in this project.
@MainActor
final class SystemAppearanceObserverTests: XCTestCase {
    func testSharedIsASingleton() {
        XCTAssertTrue(SystemAppearanceObserver.shared === SystemAppearanceObserver.shared)
    }

    // POS: `isDark` reflects the real system appearance at the moment the singleton was first
    // touched — the only reachable behavior contract without a fake NSApp.effectiveAppearance hook.
    func testIsDarkMatchesActualSystemAppearance() {
        let expected = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        XCTAssertEqual(SystemAppearanceObserver.shared.isDark, expected)
    }
}
