import AppKit
import SwiftTerm
import SwiftUI

struct IntegratedTerminalView: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let currentPath = appState.navigation.currentURL.path

        if let cached = windowUIState.terminalViewCache.view {
            // Drawer reopened: return the cached terminal untouched. Injecting `cd <folder>\r` here
            // appended to whatever was on the input line — corrupting a running program or command.
            return cached
        }

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        windowUIState.terminalViewCache.view = terminalView

        terminalView.startProcess(executable: Self.loginShellPath, args: ["-l"], environment: nil, execName: nil)
        // Capture the shell pid now, while SwiftTerm's internal structure is known-good, so teardown
        // doesn't depend on the same reflection resolving after a future SwiftTerm bump.
        windowUIState.terminalViewCache.shellPid = TerminalViewCache.reflectShellPid(of: terminalView)
        Self.sendInitialCommands(to: terminalView, path: currentPath)
        return terminalView
    }

    /// The user's real login shell (`$SHELL`), falling back to `/bin/zsh` (the macOS default) when
    /// the environment doesn't carry it.
    static let loginShellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    /// Deliberately a no-op: the terminal is `cd`'d only once, at shell start/respawn — never on
    /// navigation or drawer reopen (an injected `cd` would corrupt whatever is on the input line).
    func updateNSView(_: LocalProcessTerminalView, context _: Context) { }

    func makeCoordinator() -> Coordinator {
        if let cached = windowUIState.terminalViewCache.coordinator {
            cached.rebind(appState: appState, windowUIState: windowUIState)
            return cached
        }
        let coordinator = Coordinator(appState: appState, windowUIState: windowUIState)
        windowUIState.terminalViewCache.coordinator = coordinator
        return coordinator
    }

    /// Seeds a freshly-started shell with `cd <folder>` then `clear`, once the PTY has settled.
    /// Only ever run against a brand-new shell (first open or respawn).
    static func sendInitialCommands(to view: LocalProcessTerminalView, path: String) {
        Task { @MainActor in
            try? await Task.sleep(for: AsyncDelayTokens.terminalInitialCommandDelay)
            view.send(txt: "cd \(CopyPathService.posixSingleQuoted(path))\r")
            view.send(txt: "clear\r")
        }
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        // Weak: the coordinator is cached on `windowUIState.terminalViewCache`, so holding the
        // parent struct (which itself retains `appState`/`windowUIState`) strong made a cycle that
        // only `TerminalViewCache.tearDown()` broke — a missed teardown leaked the whole window.
        private weak var appState: AppState?
        private weak var windowUIState: WindowUIState?

        init(appState: AppState, windowUIState: WindowUIState) {
            self.appState = appState
            self.windowUIState = windowUIState
        }

        func rebind(appState: AppState, windowUIState: WindowUIState) {
            self.appState = appState
            self.windowUIState = windowUIState
        }

        func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) { }
        func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) { }
        func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) { }

        /// A shell that exits the instant it starts (a broken `.zshrc`, `exit` in a profile) would
        /// otherwise be respawned forever. After this many restarts inside `restartWindow`, stop.
        private var restartTimes: [Date] = []
        private static let restartWindow: TimeInterval = 10
        private static let maxRestartsInWindow = 3

        /// The shell exited (`exit`, `⌃D`, or it crashed). Without this the drawer would keep
        /// showing a frozen dead terminal with no way back short of toggling the whole drawer.
        /// Restart a fresh shell in the same view, back at the current folder.
        func processTerminated(source _: TerminalView, exitCode _: Int32?) {
            let now = Date()
            restartTimes.append(now)
            restartTimes.removeAll { now.timeIntervalSince($0) > Self.restartWindow }
            let appState = appState
            let windowUIState = windowUIState
            DispatchQueue.main.async { [restartCount = restartTimes.count] in
                guard let appState, let view = windowUIState?.terminalViewCache.view else { return }
                // Shell is exiting on launch — stop respawning; toggling the drawer starts fresh.
                guard restartCount <= Self.maxRestartsInWindow else { return }
                view.startProcess(executable: IntegratedTerminalView.loginShellPath, args: ["-l"], environment: nil, execName: nil)
                windowUIState?.terminalViewCache.shellPid = TerminalViewCache.reflectShellPid(of: view)
                IntegratedTerminalView.sendInitialCommands(
                    to: view, path: appState.navigation.currentURL.path)
            }
        }
    }
}
