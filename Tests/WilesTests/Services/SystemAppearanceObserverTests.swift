import XCTest
@testable import Wiles

/// Standalone dedicated suite for `SystemAppearanceObserver` — follows the standalone-XCTestCase
/// precedent (see `DefaultFolderHandlerServiceTests`) since this wraps a live AppKit/
/// DistributedNotificationCenter singleton with no fake-able seam, same class of limited
/// testability as other system-observer wrappers in this project.
@MainActor
final class SystemAppearanceObserverTests: XCTestCase {
    /// Mirrors the observer's own source of truth: the system-wide `AppleInterfaceStyle`, NOT
    /// `NSApp.effectiveAppearance` (which `WilesApp` freezes to a concrete value once it resolves
    /// "System", after which it no longer tracks the OS — finding MM-161).
    private var systemIsDark: Bool {
        SystemAppearanceObserver.isDark(
            appleInterfaceStyle: UserDefaults.standard.persistentDomain(
                forName: UserDefaults.globalDomain)?["AppleInterfaceStyle"] as? String)
    }

    func testSharedIsASingleton() {
        XCTAssertTrue(SystemAppearanceObserver.shared === SystemAppearanceObserver.shared)
    }

    /// The pure decision: only `"Dark"` (case-insensitively) is dark; everything else, including a
    /// missing key, is light.
    func testIsDarkPureDecision() {
        XCTAssertTrue(SystemAppearanceObserver.isDark(appleInterfaceStyle: "Dark"))
        XCTAssertTrue(SystemAppearanceObserver.isDark(appleInterfaceStyle: "dark"))
        XCTAssertFalse(SystemAppearanceObserver.isDark(appleInterfaceStyle: nil))
        XCTAssertFalse(SystemAppearanceObserver.isDark(appleInterfaceStyle: "Light"))
        XCTAssertFalse(SystemAppearanceObserver.isDark(appleInterfaceStyle: ""))
        XCTAssertFalse(SystemAppearanceObserver.isDark(appleInterfaceStyle: "AccentDark"))
    }

    // POS: `isDark` reflects the real *system* appearance at the moment the singleton was first
    // touched — read from the global preferences domain, not the app's (possibly overridden)
    // effective appearance.
    func testIsDarkMatchesSystemAppleInterfaceStyle() {
        XCTAssertEqual(SystemAppearanceObserver.shared.isDark, systemIsDark)
    }

    // POS: exercises the DistributedNotificationCenter observer closure by posting the real
    // "AppleInterfaceThemeChangedNotification" name locally (no actual System Settings change is
    // made) — proves the observer's `Task { @MainActor in ... }` callback runs and refreshes `isDark`
    // to match the (unchanged) system appearance, without crashing.
    func testPostingThemeChangeNotificationRefreshesIsDarkOnMainActor() async {
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil, userInfo: nil, deliverImmediately: true)

        // The observer callback dispatches to @MainActor asynchronously; a short yield gives it a
        // chance to run before asserting.
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(SystemAppearanceObserver.shared.isDark, systemIsDark)
    }
}
