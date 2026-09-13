import Foundation
@testable import Wiles

/// Covers `LaunchServicesGate` — the actor that's supposed to cap how many LaunchServices-touching
/// operations run at once. Verifies the cap is actually observed under real concurrent load, not
/// just asserted in a comment.
@MainActor
public struct LaunchServicesGateTests {
    public static func run() async {
        await testConcurrencyReachesTheConfiguredLimit()
        await testNeverExceedsTheConfiguredLimit()
        await testEveryWaiterEventuallyRuns()
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var active = 0
        private var maxActive = 0
        private var completed = 0

        func enter() {
            lock.lock()
            active += 1
            maxActive = max(maxActive, active)
            lock.unlock()
        }

        func exit() {
            lock.lock()
            active -= 1
            completed += 1
            lock.unlock()
        }

        var observedMax: Int {
            lock.lock()
            defer { lock.unlock() }
            return maxActive
        }

        var completedCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return completed
        }
    }

    /// A gate whose bodies never overlap is indistinguishable from `limit: 1` no matter what
    /// `limit` says — this is the check that would have caught `run(_:)` running its (synchronous)
    /// body while still holding the actor, which serializes every caller instead of letting up to
    /// `limit` of them run at once.
    private static func testConcurrencyReachesTheConfiguredLimit() async {
        let limit = 3
        let gate = LaunchServicesGate(limit: limit)
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< (limit * 4) {
                group.addTask {
                    await gate.run {
                        counter.enter()
                        Thread.sleep(forTimeInterval: 0.05)
                        counter.exit()
                    }
                }
            }
        }

        TestReporter.report(
            "Services/LaunchServicesGate",
            "POS: bodies actually overlap up to the configured limit (limit \(limit), observed max \(counter.observedMax))",
            result: counter.observedMax == limit)
    }

    private static func testNeverExceedsTheConfiguredLimit() async {
        let limit = 2
        let gate = LaunchServicesGate(limit: limit)
        let counter = Counter()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 20 {
                group.addTask {
                    await gate.run {
                        counter.enter()
                        Thread.sleep(forTimeInterval: 0.02)
                        counter.exit()
                    }
                }
            }
        }

        TestReporter.report(
            "Services/LaunchServicesGate",
            "POS: never runs more bodies than the configured limit under load (limit \(limit), observed max \(counter.observedMax))",
            result: counter.observedMax <= limit)
    }

    private static func testEveryWaiterEventuallyRuns() async {
        // Regression guard for the waiter-queue FIFO logic: a low-limit gate serialising many
        // callers must not drop or duplicate a waiter's continuation resume.
        let gate = LaunchServicesGate(limit: 1)
        let counter = Counter()
        let taskCount = 15

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< taskCount {
                group.addTask {
                    await gate.run {
                        counter.enter()
                        counter.exit()
                    }
                }
            }
        }

        TestReporter.report(
            "Services/LaunchServicesGate",
            "POS: every queued caller eventually runs exactly once (completed \(counter.completedCount)/\(taskCount))",
            result: counter.completedCount == taskCount)
    }
}
