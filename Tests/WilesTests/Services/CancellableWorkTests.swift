import Foundation
@testable import Wiles

/// Covers `CancellableWork.detached` — the wrapper that makes `Task.isCancelled` /
/// `try Task.checkCancellation()` inside an off-main body actually respond to the caller's
/// cancellation (findings AM-140 / HM-235 / MM-096). A bare `try await Task.detached { … }.value`
/// would leave those checks as dead code and the test bodies below would hang forever.
@MainActor
public struct CancellableWorkTests {
    public static func run() async {
        await testForwardsCancellationToIsCancelled()
        await testCheckCancellationThrowsOnCancel()
        await testThrowingOverloadReturnsValue()
        await testNonThrowingOverloadReturnsValue()
    }

    private final class Flag: @unchecked Sendable {
        private let lock = NSLock()
        private var value = false
        func set() {
            lock.lock()
            value = true
            lock.unlock()
        }

        var isSet: Bool {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
    }

    private static func testForwardsCancellationToIsCancelled() async {
        let observedCancel = Flag()
        let outer = Task {
            await CancellableWork.detached { () -> Int in
                var i = 0
                while !Task.isCancelled {
                    i &+= 1
                    if i % 50000 == 0 {
                        await Task.yield()
                    }
                }
                observedCancel.set()
                return i
            }
        }
        try? await Task.sleep(for: .milliseconds(60))
        outer.cancel()
        _ = await outer.value
        TestReporter.report(
            "Services/CancellableWork",
            "POS: caller cancellation reaches Task.isCancelled inside the detached body",
            result: observedCancel.isSet)
    }

    private static func testCheckCancellationThrowsOnCancel() async {
        let outer = Task { () -> Bool in
            do {
                _ = try await CancellableWork.detached { () -> Int in
                    while true {
                        try Task.checkCancellation()
                        await Task.yield()
                    }
                }
                return false
            } catch is CancellationError {
                return true
            } catch {
                return false
            }
        }
        try? await Task.sleep(for: .milliseconds(60))
        outer.cancel()
        let threw = await outer.value
        TestReporter.report(
            "Services/CancellableWork",
            "POS: try Task.checkCancellation() in the body throws CancellationError on cancel",
            result: threw)
    }

    private static func testThrowingOverloadReturnsValue() async {
        var value = "?"
        do {
            value = try await CancellableWork.detached { () throws -> String in "done" }
        } catch {
            value = "threw"
        }
        TestReporter.report(
            "Services/CancellableWork", "POS: throwing overload returns the body's value when never cancelled",
            result: value == "done")
    }

    private static func testNonThrowingOverloadReturnsValue() async {
        let result = await CancellableWork.detached { () -> Int in 42 }
        TestReporter.report(
            "Services/CancellableWork", "POS: non-throwing overload returns the body's value",
            result: result == 42)
    }
}
