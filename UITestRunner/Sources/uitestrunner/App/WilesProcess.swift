import AppKit
import Foundation

/// Launches the debug Wiles.app bundle, exposes its pid for AX, and terminates it on teardown.
/// `--ui-testing` suppresses the first-run permission prompts (WilesApp.swift). A private prefs
/// domain keeps the run from disturbing the user's real Wiles settings.
final class WilesProcess {
    let bundleURL: URL
    private(set) var runningApp: NSRunningApplication?

    var pid: pid_t { runningApp?.processIdentifier ?? -1 }

    init(bundleURL: URL) {
        self.bundleURL = bundleURL
    }

    func launch() throws {
        for stale in NSRunningApplication.runningApplications(withBundleIdentifier: "com.marco.wiles") {
            stale.forceTerminate()
        }
        Thread.sleep(forTimeInterval: 1.0)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--ui-testing"]
        configuration.activates = true
        configuration.createsNewApplicationInstance = true

        let semaphore = DispatchSemaphore(value: 0)
        var launchError: Error?
        var launched: NSRunningApplication?
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, error in
            launched = app
            launchError = error
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 30) == .success else {
            throw RunnerError.launchTimedOut
        }
        if let launchError { throw launchError }
        runningApp = launched
    }

    func terminate() {
        runningApp?.terminate()
        Thread.sleep(forTimeInterval: 0.5)
        if runningApp?.isTerminated == false {
            runningApp?.forceTerminate()
        }
    }
}
