import XCTest

// MARK: - GlobalKeyMonitor leak regression
//
// Real reported bug: dragging a file out of Wiles onto another app left the keyboard completely
// dead everywhere in Wiles until relaunch. Root cause: `KeyMonitorNSView` (backing
// `GlobalKeyMonitor`, one instance per window) installed an `NSEvent.addLocalMonitorForEvents`
// monitor in `viewDidMoveToWindow()` but never removed it — no `deinit`, no
// `viewWillMove(toWindow:)`. Its handler captures `self` weakly and returns `nil` when `self` is
// gone; per `NSEvent.addLocalMonitorForEvents` semantics, a monitor returning `nil` swallows the
// event app-wide for every other monitor and the whole responder chain. Once any window closes
// (or its content view hierarchy is torn down) while the monitor is still registered, every
// keyDown/scrollWheel anywhere in the app is silently eaten forever — exactly "nothing I type
// works until I relaunch."
//
// This test reproduces the leak mechanism directly (open a second window, close it) rather than a
// literal drag to a third-party app, since that's the deterministic, automatable trigger for the
// same underlying defect — see the class-doc comment on `GlobalKeyMonitor.KeyMonitorNSView` for
// the fix (mirrors `ClickOutsideDetector`'s existing `viewWillMove(toWindow:)`/
// `removeFromSuperview()` monitor-removal pattern).
//
// ❌ NOT run via `swift test`/bare `xcodebuild` — see WilesLaunchUITests.swift's header comment.
// ✅ Run from Xcode: open Package.swift → Product → Test (⌘U)

@MainActor
final class GlobalKeyMonitorUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    /// Opens a second window (Cmd+N), closes it (Cmd+W), then verifies Cmd+N still opens a third
    /// window — i.e. the app-wide keyDown monitor is still alive and dispatching, not swallowing
    /// every event because the second window's `KeyMonitorNSView` leaked its monitor on teardown.
    func testKeyboardShortcutsSurviveClosingASecondWindow() throws {
        XCTAssertTrue(
            app.windows.firstMatch.waitForExistence(timeout: 5.0),
            "Wiles main window did not appear within 5 seconds"
        )
        XCTAssertTrue(
            waitForWindowCount(1),
            "Test must start with exactly one window, found \(app.windows.count)"
        )

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount(2), "Cmd+N did not open a second window")

        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(waitForWindowCount(1), "Cmd+W did not close the second window")

        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(
            waitForWindowCount(2),
            "Cmd+N stopped opening windows after closing the second window — GlobalKeyMonitor's " +
            "NSEvent monitor leaked and is now swallowing all keyboard input app-wide"
        )
    }

    private func waitForWindowCount(_ count: Int, timeout: TimeInterval = 3.0) -> Bool {
        let predicate = NSPredicate(format: "count == %d", count)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.windows)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
