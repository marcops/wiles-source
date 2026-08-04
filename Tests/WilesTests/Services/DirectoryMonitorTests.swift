@testable import Wiles
import Foundation

@MainActor
public struct DirectoryMonitorTests {
    public static func run() async {
        await testStartDetectsFileCreation()
        await testCancelStopsFurtherNotifications()
        testStartOnNonexistentPathDoesNotCrash()
    }

    private static func testStartDetectsFileCreation() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        final class Flag: @unchecked Sendable {
            var triggered = false
        }
        let flag = Flag()

        let monitor = DirectoryMonitor()
        monitor.start(path: dir.path) {
            flag.triggered = true
        }

        // Give the FSEventStream a moment to actually start before mutating the directory.
        try? await Task.sleep(nanoseconds: 300_000_000)

        let fileURL = dir.appendingPathComponent("new-file.txt")
        try? "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        var waited: UInt64 = 0
        let interval: UInt64 = 200_000_000
        let maxWait: UInt64 = 3_000_000_000
        while !flag.triggered && waited < maxWait {
            try? await Task.sleep(nanoseconds: interval)
            waited += interval
        }

        report("DirectoryMonitor", "POS: creating a file in a watched directory triggers the callback", result: flag.triggered)
        monitor.cancel()
    }

    private static func testCancelStopsFurtherNotifications() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        final class Flag: @unchecked Sendable {
            var triggered = false
        }
        let flag = Flag()

        let monitor = DirectoryMonitor()
        monitor.start(path: dir.path) {
            flag.triggered = true
        }

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Cancel before making any change, so no notification should ever come through.
        monitor.cancel()

        // Reset the flag after cancel(): system noise (e.g. Spotlight/.DS_Store activity) in a
        // freshly created temp dir can legitimately trip the callback before cancel() runs, which
        // would be a false failure unrelated to cancel()'s actual behavior. What we're testing is
        // specifically that a change made AFTER cancel() produces no notification.
        flag.triggered = false

        let fileURL = dir.appendingPathComponent("after-cancel.txt")
        try? "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        // Wait the same window we'd expect a real notification to arrive in, to confirm
        // it genuinely never fires rather than just checking too early.
        try? await Task.sleep(nanoseconds: 1_500_000_000)

        report("DirectoryMonitor", "NEG: changes after cancel() do not trigger the callback", result: !flag.triggered)
    }

    private static func testStartOnNonexistentPathDoesNotCrash() {
        let missingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        // Deliberately do not create this directory.

        let monitor = DirectoryMonitor()
        monitor.start(path: missingDir.path) {
            // Should never be reachable for a path that never existed and is never created.
        }
        monitor.cancel()

        report("DirectoryMonitor", "NEG: starting on a nonexistent path does not crash", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
