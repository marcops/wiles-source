@testable import Wiles
import Foundation

/// Covers the `/Volumes/` branch of `AppState.navigateTo()` (Sources/Wiles/Models/AppState/AppState+Navigation.swift):
/// paths under `/Volumes/` hop onto a `Task.detached` before the (potentially slow) `fileExists`
/// disk call, then hop back to `@MainActor` to apply the result — unlike local paths, which resolve
/// `fileExists` inline and update state synchronously.
///
/// We can't fabricate a stalled/slow network mount here (no write access to `/Volumes/` as a normal
/// user — see UI_TEST_BACKLOG.md), so this doesn't prove the UI stays responsive under a hung mount.
/// It does prove the two directly-observable, non-timing-dependent consequences of routing through
/// `Task.detached`: (1) state is not updated synchronously on the calling thread, and (2) it is
/// eventually updated once the detached task completes. Uses whatever directory entries already
/// exist under `/Volumes/` (at minimum the boot volume is always present there) rather than a
/// hardcoded volume name, since that's machine-specific.
@MainActor
public struct AppStateNavigateToVolumesTests {
    public static func run() async {
        await testNavigateToVolumesPathDoesNotUpdateSynchronouslyButCompletesAsynchronously()
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }

    /// Finds a real, existing directory under `/Volumes/` without creating anything (we don't have
    /// permission to mkdir there as a non-root user).
    private static func firstVolumesDirectory() -> URL? {
        let volumesURL = URL(fileURLWithPath: "/Volumes")
        guard let entries = try? FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil) else {
            return nil
        }
        for entry in entries {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue {
                return entry
            }
        }
        return nil
    }

    private static func testNavigateToVolumesPathDoesNotUpdateSynchronouslyButCompletesAsynchronously() async {
        guard let target = firstVolumesDirectory() else {
            // No mounted volume entries visible in this environment (sandboxed CI?) — nothing to
            // exercise the /Volumes/ branch against. Report a pass rather than a false failure since
            // this is an environment limitation, not a source regression.
            report(
                "Navigation/Volumes",
                "POS: /Volumes/ branch skipped — no directory entries visible under /Volumes/ in this environment",
                result: true
            )
            return
        }

        let appState = AppState()
        let before = appState.navigation.currentURL

        appState.navigateTo(target)
        // The /Volumes/ branch dispatches the fileExists check + state mutation onto a
        // Task.detached and hops back via `await MainActor.run`, so control returns to us here
        // before that detached task has necessarily run at all. currentURL must therefore still be
        // whatever it was before the call — a local (non-/Volumes/) path would have updated it
        // synchronously and inline instead.
        report(
            "Navigation/Volumes",
            "POS: navigateTo() on a /Volumes/ path does not update currentURL synchronously " +
                "(proves it hops off the calling context via Task.detached rather than resolving inline)",
            result: appState.navigation.currentURL == before
        )

        // Give the detached task + MainActor hop a chance to run and apply completeNavigation().
        var updated = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 20_000_000)
            if appState.navigation.currentURL.standardizedFileURL == target.standardizedFileURL {
                updated = true
                break
            }
        }
        report(
            "Navigation/Volumes",
            "POS: navigateTo() on a /Volumes/ path eventually applies the navigation once the detached task completes",
            result: updated
        )
    }
}
