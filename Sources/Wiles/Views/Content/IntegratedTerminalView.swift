import AppKit
import SwiftTerm
import SwiftUI

struct IntegratedTerminalView: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let cached = windowUIState.terminalViewCache.view {
            return cached
        }

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        windowUIState.terminalViewCache.view = terminalView

        let path = appState.navigation.currentURL.path
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: nil,
            execName: nil)

        // Initial cd
        DispatchQueue.main.asyncAfter(deadline: .now() + AsyncDelayTokens.terminalInitialCommandDelay) {
            terminalView.send(txt: "cd \"\(CopyPathService.escapeForTerminal(path))\"\r")
            terminalView.send(txt: "clear\r")
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        let currentPath = appState.navigation.currentURL.path
        if context.coordinator.lastPath != currentPath {
            context.coordinator.lastPath = currentPath
            // Send cd command to the terminal
            nsView.send(txt: "cd \"\(CopyPathService.escapeForTerminal(currentPath))\"\r")
        }
    }

    func makeCoordinator() -> Coordinator {
        if let cached = windowUIState.terminalViewCache.coordinator {
            cached.parent = self
            return cached
        }
        let coordinator = Coordinator(self, initialPath: appState.navigation.currentURL.path)
        windowUIState.terminalViewCache.coordinator = coordinator
        return coordinator
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: IntegratedTerminalView
        var lastPath: String

        init(_ parent: IntegratedTerminalView, initialPath: String) {
            self.parent = parent
            lastPath = initialPath
        }

        func sizeChanged(source _: LocalProcessTerminalView, newCols _: Int, newRows _: Int) { }
        func setTerminalTitle(source _: LocalProcessTerminalView, title _: String) { }
        func hostCurrentDirectoryUpdate(source _: TerminalView, directory _: String?) { }
        func processTerminated(source _: TerminalView, exitCode _: Int32?) { }
    }
}
