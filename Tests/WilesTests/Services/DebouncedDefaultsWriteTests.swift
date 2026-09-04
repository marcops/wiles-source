import Foundation
@testable import Wiles

/// Covers `DebouncedDefaultsWrite` + `DebouncedWriteRegistry` — the shared debounced-write type
/// that replaces the three hand-rolled `pendingX?.cancel()` + `asyncAfter` + manual-flush trios
/// (finding MM-171). A long interval is used so nothing fires on its own timer during the test.
@MainActor
public struct DebouncedDefaultsWriteTests {
    public static func run() {
        testScheduleDoesNotRunSynchronouslyButFlushDoes()
        testSecondScheduleReplacesTheFirst()
        testCancelDropsThePendingWrite()
        testRegistryFlushAllRunsAPendingWrite()
        testFlushWithNothingPendingIsANoOp()
        testASecondFlushDoesNotRunTheWriteAgain()
    }

    /// The scheduled block clears `pending` when it runs, so once a write has happened (via `flush`
    /// here, or the timer in production) a later `flush` — e.g. quit-time `flushAll()` after the
    /// timer already fired — is a no-op instead of a redundant second write of the same value.
    private static func testASecondFlushDoesNotRunTheWriteAgain() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        var runs = 0
        writer.schedule { runs += 1 }
        writer.flush()
        writer.flush()
        report(
            "Services/DebouncedDefaultsWrite",
            "POS: a second flush() after the write already ran does not run it again",
            result: runs == 1)
    }

    private static func testScheduleDoesNotRunSynchronouslyButFlushDoes() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        var runs = 0
        writer.schedule { runs += 1 }
        report("Services/DebouncedDefaultsWrite", "NEG: schedule() does not run the write synchronously", result: runs == 0)
        writer.flush()
        report("Services/DebouncedDefaultsWrite", "POS: flush() runs the pending write immediately", result: runs == 1)
    }

    private static func testSecondScheduleReplacesTheFirst() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        var value = 0
        writer.schedule { value = 1 }
        writer.schedule { value = 2 }
        writer.flush()
        report(
            "Services/DebouncedDefaultsWrite", "POS: a second schedule() cancels the first — only the latest write runs",
            result: value == 2)
    }

    private static func testCancelDropsThePendingWrite() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        var ran = false
        writer.schedule { ran = true }
        writer.cancel()
        writer.flush()
        report("Services/DebouncedDefaultsWrite", "POS: cancel() drops the pending write so a later flush() is a no-op", result: !ran)
    }

    private static func testRegistryFlushAllRunsAPendingWrite() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        var ran = false
        writer.schedule { ran = true }
        DebouncedWriteRegistry.shared.flushAll()
        report(
            "Services/DebouncedDefaultsWrite", "POS: DebouncedWriteRegistry.flushAll() flushes every registered writer",
            result: ran)
    }

    private static func testFlushWithNothingPendingIsANoOp() {
        let writer = DebouncedDefaultsWrite(interval: 60)
        writer.flush()
        writer.flush()
        report("Services/DebouncedDefaultsWrite", "POS: flush() with nothing pending does not crash", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
