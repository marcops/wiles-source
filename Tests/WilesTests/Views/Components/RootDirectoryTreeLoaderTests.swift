import Foundation
@testable import Wiles

/// Covers `RootDirectoryTreeLoader` — the home-directory-tree build flow now shared by
/// `SidebarView` and `FolderPickerSheet` (LL-020), including the post-`await` re-check that only
/// `FolderPickerSheet` used to have.
@MainActor
public struct RootDirectoryTreeLoaderTests {
    public static func run() async {
        await testNoWorkWhenNotPending()
        await testAppliesScanResultAndClearsTimedOut()
        await testTimeoutFlagIsRaisedForASlowScan()
        await testResultNotAppliedIfPendingClearedDuringAwait()
    }

    private nonisolated static func fakeNode(_ tag: String) -> FolderNode {
        let url = URL(fileURLWithPath: "/tmp/rdtl-\(tag)")
        return FolderNode(id: url, name: tag, url: url, children: [], hasSubfolders: false)
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Bool
        init(_ initial: Bool) {
            value = initial
        }

        var pending: Bool {
            get { lock.lock()
                defer { lock.unlock() }
                return value
            }
            set { lock.lock()
                value = newValue
                lock.unlock()
            }
        }
    }

    private static func testNoWorkWhenNotPending() async {
        var applied: FolderNode?
        var timedOutCalls: [Bool] = []
        await RootDirectoryTreeLoader.load(
            isPending: { false },
            setTimedOut: { timedOutCalls.append($0) },
            apply: { applied = $0 },
            scan: { fakeNode("never") })
        report("POS: does nothing when the target is already populated", applied == nil && timedOutCalls.isEmpty)
    }

    private static func testAppliesScanResultAndClearsTimedOut() async {
        var applied: FolderNode?
        var timedOutCalls: [Bool] = []
        await RootDirectoryTreeLoader.load(
            isPending: { applied == nil },
            setTimedOut: { timedOutCalls.append($0) },
            apply: { applied = $0 },
            scan: { fakeNode("built") })
        report(
            "POS: applies the scan result and only ever sets timedOut=false on the happy path",
            applied?.name == "built" && !timedOutCalls.contains(true))
    }

    private static func testTimeoutFlagIsRaisedForASlowScan() async {
        var applied: FolderNode?
        var sawTimeout = false
        await RootDirectoryTreeLoader.load(
            isPending: { applied == nil },
            setTimedOut: {
                if $0 {
                    sawTimeout = true
                }
            },
            apply: { applied = $0 },
            scan: { Thread.sleep(forTimeInterval: 0.25)
                return fakeNode("slow")
            },
            timeout: 0.03)
        report(
            "POS: a scan that overruns the timeout raises the Retry flag, then still applies when it finishes",
            sawTimeout && applied?.name == "slow")
    }

    private static func testResultNotAppliedIfPendingClearedDuringAwait() async {
        let box = Box(true)
        var applied: FolderNode?
        await RootDirectoryTreeLoader.load(
            isPending: { box.pending },
            setTimedOut: { _ in },
            apply: { applied = $0 },
            scan: { box.pending = false
                return fakeNode("stale")
            })
        report(
            "POS: a scan whose target was cleared mid-await (Retry / newer result) is discarded, not applied",
            applied == nil)
    }

    private static func report(_ name: String, _ result: Bool) {
        TestReporter.report("View/RootDirectoryTreeLoader", name, result: result)
    }
}
