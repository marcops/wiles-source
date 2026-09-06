import AppKit
import Foundation

/// Launches the debug Wiles.app bundle, exposes its pid for AX, and terminates it on teardown.
/// `--ui-testing` suppresses the first-run permission prompts (WilesApp.swift). A private prefs
/// domain keeps the run from disturbing the user's real Wiles settings.
final class WilesProcess {
    static let bundleID = "com.marco.wiles.uitest"

    let bundleURL: URL
    private(set) var runningApp: NSRunningApplication?

    var pid: pid_t { runningApp?.processIdentifier ?? -1 }

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    /// Seeds the isolated defaults domain so the app opens straight into `folder` on launch
    /// (`NavigationStore.init` restores `wiles_lastOpenedFolder`), sidestepping a fragile
    /// type-into-path-bar step at the top of every run.
    func setInitialFolder(_ folder: URL) {
        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = ["write", Self.bundleID, "wiles_lastOpenedFolder", folder.path]
        defaults.standardOutput = FileHandle.nullDevice
        defaults.standardError = FileHandle.nullDevice
        try? defaults.run()
        defaults.waitUntilExit()
    }

    func launch() throws {
        for stale in NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleID) {
            stale.forceTerminate()
        }
        Timing.pause(Timing.launch)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--ui-testing"]
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        let semaphore = DispatchSemaphore(value: 0)
        let outcome = LaunchOutcome()
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, error in
            outcome.app = app
            outcome.error = error
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 30) == .success else {
            throw RunnerError.launchTimedOut
        }
        if let error = outcome.error { throw error }
        runningApp = outcome.app
    }

    /// Carries the async `openApplication` result across the semaphore wait without tripping
    /// Swift 6's captured-`var` mutation diagnostic. Written once on a bg queue, read after
    /// `semaphore.wait` returns — no overlap.
    private final class LaunchOutcome: @unchecked Sendable {
        var app: NSRunningApplication?
        var error: Error?
    }

    func activate() {
        runningApp?.activate(options: [.activateAllWindows])
        Timing.pause(Timing.settle)
    }

    func terminate() {
        runningApp?.terminate()
        Timing.pause(Timing.settle)
        if runningApp?.isTerminated == false {
            runningApp?.forceTerminate()
        }
    }
}
