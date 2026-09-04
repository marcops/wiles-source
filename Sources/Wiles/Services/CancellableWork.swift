import Foundation

/// Runs a body off the main actor in a real `Task.detached` (a structural off-main guarantee) **and**
/// forwards the caller's cancellation into it, so `Task.isCancelled` / `try Task.checkCancellation()`
/// inside the body actually fire when the calling task is cancelled.
///
/// `try await Task.detached { … }.value` on its own does NOT do that: `Task.detached` does not
/// inherit cancellation and its handle is discarded, so every `isCancelled` check inside such a
/// body is dead code. Crawls, merges and scans written that way
/// kept running as zombie CPU/IO work after the user navigated away or closed the view. This is the
/// same wrapper `AppState.runFileOperation`'s `detached` branch already uses, extracted so every
/// service call site shares one policy.
public enum CancellableWork {
    public static func detached<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        let inner = Task.detached(priority: priority) { try await body() }
        return try await withTaskCancellationHandler {
            try await inner.value
        } onCancel: {
            inner.cancel()
        }
    }

    /// Non-throwing overload for bodies that only cooperatively bail (`if Task.isCancelled { break }`)
    /// and never call `try Task.checkCancellation()`.
    public static func detached<T: Sendable>(
        priority: TaskPriority = .userInitiated,
        _ body: @escaping @Sendable () async -> T) async -> T {
        let inner = Task.detached(priority: priority) { await body() }
        return await withTaskCancellationHandler {
            await inner.value
        } onCancel: {
            inner.cancel()
        }
    }
}
