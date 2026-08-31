import Foundation

/// Process-wide list of every live `DebouncedDefaultsWrite`. `WilesApp` calls `flushAll()` once
/// from `applicationWillTerminate` so every coalesced write reaches `UserDefaults` before the
/// process dies — a value changed inside the last debounce interval before ⌘Q would otherwise be
/// lost and restore stale next launch (findings MM-171 / ML-259).
///
/// Entries are held weakly: a `DebouncedDefaultsWrite` owned by a released store just drops out.
@MainActor
public final class DebouncedWriteRegistry {
    public static let shared = DebouncedWriteRegistry()

    private let writers = NSHashTable<DebouncedDefaultsWrite>.weakObjects()

    private init() { }

    func register(_ writer: DebouncedDefaultsWrite) {
        writers.add(writer)
    }

    /// Flushes every registered debounced write. Idempotent — a writer with nothing pending is a
    /// no-op.
    public func flushAll() {
        for writer in writers.allObjects {
            writer.flush()
        }
    }
}
