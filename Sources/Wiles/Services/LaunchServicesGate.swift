import Foundation

/// Caps how many LaunchServices-touching operations (`.effectiveIconKey` resolution,
/// `NSWorkspace.urlsForApplications`) run at once. LaunchServices serializes icon/UTType
/// resolution on an internal client-side lock — letting many `Task.detached` bodies hit it
/// concurrently (several windows navigating together, a background scan running alongside the
/// user browsing) piles them all onto that one lock instead of just queuing politely, and under
/// load this has been observed to wedge every caller behind it rather than merely slow them down.
actor LaunchServicesGate {
    static let shared = LaunchServicesGate(limit: 2)

    private let limit: Int
    private var active = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = limit
    }

    private func acquire() async {
        if active < limit {
            active += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
        active += 1
    }

    private func release() {
        active -= 1
        if !waiters.isEmpty {
            waiters.removeFirst().resume()
        }
    }

    /// `nonisolated`: the body must run outside this actor's isolation so up to `limit` of them
    /// can genuinely overlap. If this method were actor-isolated (as it originally was), calling
    /// the (synchronous) body directly from within an isolated call holds the actor's one serial
    /// executor for the body's whole duration — no other caller's `acquire()` can even be
    /// scheduled until this one returns, silently collapsing any `limit > 1` to fully serial
    /// execution no matter what `limit` says.
    nonisolated func run<T: Sendable>(_ body: @Sendable () throws -> T) async rethrows -> T {
        await acquire()
        do {
            let result = try body()
            await release()
            return result
        } catch {
            await release()
            throw error
        }
    }
}
