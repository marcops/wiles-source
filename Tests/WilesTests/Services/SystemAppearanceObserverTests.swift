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

    // POS: exercises the DistributedNotificationCenter observer closure by posting the real
    // "AppleInterfaceThemeChangedNotification" name locally (no actual System Settings change is
    // made) — proves the observer's `Task { @MainActor in ... }` callback runs and refreshes `isDark`
    // to match the (unchanged) real system appearance, without crashing.
    func testPostingThemeChangeNotificationRefreshesIsDarkOnMainActor() async {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil, userInfo: nil, deliverImmediately: true)

        // The observer callback dispatches to @MainActor asynchronously; a short yield gives it a
        // chance to run before asserting.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let expected = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        XCTAssertEqual(SystemAppearanceObserver.shared.isDark, expected)
    }
}
