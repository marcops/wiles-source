import AppKit
import SwiftTerm
import SwiftUI

struct IntegratedTerminalView: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let currentPath = appState.navigation.currentURL.path

        if let cached = windowUIState.terminalViewCache.view {
            // Drawer was reopened — `cd` to wherever the browser is now, once. It does NOT keep
            // following navigation after this (see `updateNSView`).
            Self.sendInitialCommands(to: cached, path: currentPath, clearFirst: false)
            return cached
        }

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        windowUIState.terminalViewCache.view = terminalView

        terminalView.startProcess(executable: "/bin/zsh", args: ["-l"], environment: nil, execName: nil)
        Self.sendInitialCommands(to: terminalView, path: currentPath, clearFirst: true)
        return terminalView
    }

    /// Deliberately a no-op: the terminal syncs to the current folder only when the drawer opens
    /// (`makeNSView`), never on every navigation — an injected `cd` mid-command would corrupt the
    /// user's input or run at an unexpected time.
    func updateNSView(_: LocalProcessTerminalView, context _: Context) { }

    func makeCoordinator() -> Coordinator {
        if let cached = windowUIState.terminalViewCache.coordinator {
            cached.parent = self
            return cached
        }
        let coordinator = Coordinator(self)
        windowUIState.terminalViewCache.coordinator = coordinator
        return coordinator
    }

    /// Sends the `cd <folder>` (and, for a fresh shell, `clear`) once the PTY has settled.
    static func sendInitialCommands(to view: LocalProcessTerminalView, path: String, clearFirst: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.terminalInitialCommandDelay) {
            view.send(txt: "cd \(CopyPathService.posixSingleQuoted(path))\r")
            if clearFirst {
                view.send(txt: "clear\r")
            }
        }
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: IntegratedTerminalView

        init(_ parent: IntegratedTerminalView) {
            self.parent = parent
        }

        func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) { }
        func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) { }
        func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) { }

        /// The shell exited (`exit`, `⌃D`, or it crashed). Without this the drawer would keep
        /// showing a frozen dead terminal with no way back short of toggling the whole drawer.
        /// Restart a fresh shell in the same view, back at the current folder.
        func processTerminated(source _: TerminalView, exitCode _: Int32?) {
            let parent = parent
            DispatchQueue.main.async {
                guard let view = parent.windowUIState.terminalViewCache.view else { return }
                view.startProcess(executable: "/bin/zsh", args: ["-l"], environment: nil, execName: nil)
                IntegratedTerminalView.sendInitialCommands(
                    to: view, path: parent.appState.navigation.currentURL.path, clearFirst: true)
            }
        }
    }
}
