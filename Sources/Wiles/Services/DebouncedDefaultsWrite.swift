import Foundation

/// One coalesced write to durable storage (`UserDefaults`) behind a timer. Replaces the
/// hand-rolled `pendingX?.cancel()` + `DispatchQueue.main.asyncAfter(...)` + per-type
/// `flushPendingSaves` trio that was copied across `ViewPreferences`, `SidebarPreferences` and
/// `AutoOrganizationRuleStore` — one of which (the sidebar's expanded-tree set) shipped without a
/// flush at all (findings MM-171 / ML-259).
///
/// Every instance registers itself with `DebouncedWriteRegistry`, which `WilesApp` drains once on
/// `applicationWillTerminate` — so a new debounced write is flushed on quit by construction, with
/// nothing to remember to wire up.
@MainActor
public final class DebouncedDefaultsWrite {
    private let interval: TimeInterval
    private var pending: DispatchWorkItem?

    public init(interval: TimeInterval) {
        self.interval = interval
        DebouncedWriteRegistry.shared.register(self)
    }

    /// Schedules `write` to run after `interval`, cancelling any still-pending write first so a
    /// burst of edits serializes to storage only once.
    public func schedule(_ write: @escaping () -> Void) {
        pending?.cancel()
        let item = DispatchWorkItem(block: write)
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
    }

    /// Runs the pending write immediately and clears the timer. `perform()` before `cancel()` — a
    /// cancelled `DispatchWorkItem` no longer runs on `perform()`.
    public func flush() {
        pending?.perform()
        pending?.cancel()
        pending = nil
    }

    /// Drops the pending write without running it.
    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}
