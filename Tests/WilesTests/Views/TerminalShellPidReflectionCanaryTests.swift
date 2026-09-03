import AppKit
import SwiftTerm
import XCTest
@testable import Wiles

/// MM-143 canary. `TerminalViewCache.reflectShellPid` reads SwiftTerm's module-internal
/// `LocalProcessTerminalView.process.shellPid` via `Mirror` — the only source of the pid
/// `TerminalViewCache.tearDown()` SIGKILLs on window close / ⌘Q (its fallback, `send("exit\r")`, is
/// swallowed by a foreground `vim`/`ssh`, so a broken reflection = a silent shell-process leak).
///
/// The reflection was in fact already broken: `process` is declared `LocalProcess!`, so the second
/// `Mirror` walked the `Optional` wrapper and `shellPid` never resolved. This canary locks in the
/// fix and fails the build the moment the access path stops resolving, per DEV_RULES.md
/// "Reflection / Private-API Access Into a Dependency Needs a CI Canary". Keep it in the SwiftTerm
/// version-bump checklist.
///
/// Deliberately does NOT call `startProcess` — a real PTY read-thread torn down at test-dealloc is
/// the crash `TerminalViewCache` exists to work around. A view whose process hasn't started still
/// has a `LocalProcess` with `shellPid == 0`, which is all the reflection path needs to exercise.
@MainActor
final class TerminalShellPidReflectionCanaryTests: XCTestCase {
    func testReflectShellPidResolvesTheMirrorPathThroughTheIUOProcessProperty() {
        let view = LocalProcessTerminalView(frame: .zero)

        let pid = TerminalViewCache.reflectShellPid(of: view)

        XCTAssertNotNil(
            pid,
            "reflectShellPid returned nil — SwiftTerm's LocalProcessTerminalView.process / "
                + "LocalProcess.shellPid layout changed, or the IUO `process` is no longer being "
                + "unwrapped. TerminalViewCache.tearDown can no longer SIGKILL the shell (MM-143).")
        XCTAssertEqual(pid, 0, "a terminal view whose process has not been started reports shellPid 0")
    }

    func testMirrorStillExposesTheProcessChildOnTheView() {
        let view = LocalProcessTerminalView(frame: .zero)
        let processChild = Mirror(reflecting: view).children.first { $0.label == "process" }
        XCTAssertNotNil(
            processChild,
            "SwiftTerm's LocalProcessTerminalView no longer exposes a `process` child — the first hop "
                + "of TerminalViewCache.reflectShellPid is broken (MM-143).")
    }

    func testReflectShellPidIsNilSafeForANilView() {
        XCTAssertNil(TerminalViewCache.reflectShellPid(of: nil))
    }
}
