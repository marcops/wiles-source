import Foundation

/// The "build the home-directory `FolderNode` tree off the main actor, with a fallback-timeout
/// Retry state" flow shared by `SidebarView` and `FolderPickerSheet`. They had drifted — only
/// `FolderPickerSheet` re-checked that its target was still unset after the `await`, so `SidebarView`
/// could clobber a Retry/newer result with a stale scan. One implementation now (LL-020).
@MainActor
enum RootDirectoryTreeLoader {
    static let fallbackTimeout: TimeInterval = 6

    /// - `isPending`: the caller's target `@State` is still `nil` (nothing built or retried since).
    /// - `setTimedOut`: drives the caller's "show Retry" flag.
    /// - `apply`: installs the built tree — only called while still pending.
    /// - `scan` / `timeout`: injectable for tests; production uses the defaults.
    static func load(
        isPending: @escaping () -> Bool,
        setTimedOut: @escaping (Bool) -> Void,
        apply: (FolderNode) -> Void,
        scan: @escaping @Sendable () -> FolderNode = { FolderNode.buildRootTree() },
        timeout: TimeInterval = fallbackTimeout) async {
        guard isPending() else { return }
        setTimedOut(false)
        let buildTask = Task.detached(priority: .userInitiated, operation: scan)
        // GCD timer, not a sibling Task: a stuck detached scan can starve the cooperative pool, and
        // a `Task.sleep` timeout sharing that pool would starve right along with it.
        let fallbackWorkItem = DispatchWorkItem {
            if isPending() {
                setTimedOut(true)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: fallbackWorkItem)
        let node = await buildTask.value
        fallbackWorkItem.cancel()
        guard isPending() else { return }
        setTimedOut(false)
        apply(node)
    }
}
