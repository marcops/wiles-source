import AppKit

/// Owns the local `NSEvent` monitor `ShortcutsSettingsView` installs while capturing a new key
/// combination for one row. A plain class, not the view struct itself, so it can guarantee the
/// monitor is removed via `deinit` under any teardown path — mirroring the backstop
/// `GlobalKeyMonitor.KeyMonitorNSView` already uses for its own monitor.
@MainActor
final class ShortcutCaptureController {
    /// Non-isolated so `deinit` (which always runs nonisolated) can remove the monitor without a
    /// data-race warning — same reasoning as `GlobalKeyMonitor.KeyMonitorNSView`'s own `monitor`.
    private nonisolated(unsafe) var monitor: Any?

    func start(onKeyDown: @escaping (NSEvent) -> Void) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            onKeyDown(event)
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
