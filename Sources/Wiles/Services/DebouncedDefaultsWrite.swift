import Foundation

/// One coalesced write to durable storage (`UserDefaults`) behind a timer. Replaces the
/// hand-rolled `pendingX?.cancel()` + `DispatchQueue.main.asyncAfter(...)` + per-type
/// `flushPendingSaves` trio that was copied across `ViewPreferences`, `SidebarPreferences` and
/// `AutoOrganizationRuleStore` — one of which (the sidebar's expanded-tree set) shipped without a
/// flush at all.
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
        let item = DispatchWorkItem { [weak self] in
            write()
            self?.pending = nil // timer fired — nothing left for a later flush() to re-run
        }
        pending = item
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: item)
    }

    /// Runs the pending write now, if one is still pending — a no-op once the timer already fired,
    /// so quit-time flush can't re-write the same value. `perform()` then `cancel()`.
    public func flush() {
        guard let item = pending else { return }
        pending = nil
        item.perform()
        item.cancel()
    }

    /// Drops the pending write without running it.
    public func cancel() {
        pending?.cancel()
        pending = nil
    }
}
