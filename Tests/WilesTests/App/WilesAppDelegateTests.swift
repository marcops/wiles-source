import AppKit
import XCTest
@testable import Wiles

/// Covers `WilesAppDelegate` — the app-global lifecycle hooks moved off the per-window
/// `.onReceive(...)` so they run once for the process (finding LL-015).
@MainActor
final class WilesAppDelegateTests: XCTestCase {
    func testApplicationWillTerminateFlushesEveryDebouncedWrite() {
        let delegate = WilesAppDelegate()
        let writer = DebouncedDefaultsWrite(interval: 60)
        var flushed = false
        writer.schedule { flushed = true }

        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        XCTAssertTrue(flushed, "applicationWillTerminate must drain the DebouncedWriteRegistry")
    }

    func testApplicationDidFinishLaunchingRegistersTheOpenWithObserverWithoutCrashing() {
        let delegate = WilesAppDelegate()
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        // A second call must not double-register / crash.
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        // The observer is what keeps the "Open With" menu fresh; invalidating the cache directly
        // still works afterwards.
        OpenWithService.invalidateApplicationsCache()
    }
}
