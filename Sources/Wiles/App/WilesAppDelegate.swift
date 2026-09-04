import AppKit

/// App-global lifecycle hooks that must run exactly once for the process, not once per window.
/// They previously lived as `.onReceive(...)` on the `WindowGroup`'s content view, which registers
/// a fresh observer for every open window.
final class WilesAppDelegate: NSObject, NSApplicationDelegate {
    private var openWithCacheObserver: (any NSObjectProtocol)?

    func applicationDidFinishLaunching(_: Notification) {
        // A just-installed app the user then launches wouldn't appear in the "Open With" menu until
        // the per-extension cache was nuked by size or a relaunch.
        openWithCacheObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { OpenWithService.invalidateApplicationsCache() }
            }
    }

    func applicationWillTerminate(_: Notification) {
        // `.onDisappear` doesn't fire on ⌘Q with windows open, and wouldn't drain a still-pending
        // debounce anyway — flush every coalesced `UserDefaults` write before the process dies.
        // Every `DebouncedDefaultsWrite` self-registers, so a newly-added one is covered here by
        // construction.
        MainActor.assumeIsolated {
            DebouncedWriteRegistry.shared.flushAll()
            // Same reasoning for the integrated terminal: SIGKILL every window's shell so it isn't
            // left orphaned after ⌘Q.
            TerminalProcessRegistry.shared.tearDownAll()
        }
    }
}
