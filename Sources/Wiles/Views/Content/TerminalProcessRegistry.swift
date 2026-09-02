import Foundation

/// Process-wide list of every live `TerminalViewCache`. `WilesAppDelegate` calls `tearDownAll()`
/// once from `applicationWillTerminate` so every integrated-terminal shell is SIGKILLed before the
/// process dies — `.onDisappear` (the only other teardown trigger) does NOT fire on ⌘Q with a
/// window open, so without this a `/bin/zsh -l` (and whatever it's running — `vim`, `tail -f`,
/// `ssh`, a dev server) is left orphaned, reparented to launchd, with no UI to see or kill it
/// (finding MM-122). Same weak-registry shape as `DebouncedWriteRegistry`.
@MainActor
final class TerminalProcessRegistry {
    static let shared = TerminalProcessRegistry()

    private let caches = NSHashTable<TerminalViewCache>.weakObjects()

    private init() { }

    func register(_ cache: TerminalViewCache) {
        caches.add(cache)
    }

    /// Tears down every registered terminal cache. Idempotent — a cache already torn down (`view`
    /// nil, `shellPid` nil) is a no-op.
    func tearDownAll() {
        for cache in caches.allObjects {
            cache.tearDown()
        }
    }
}
