import SwiftUI
import SwiftTerm
import AppKit

/// Keeps the PTY-backed terminal NSView (and its running shell process) alive across drawer
/// show/hide cycles. SwiftUI destroys and recreates NSViewRepresentable content whenever it's
/// conditionally removed from the view tree, which tears down SwiftTerm's view while its
/// background PTY-read thread can still be active — that's what was crashing on a fast
/// open/close. Holding the real instance here means SwiftUI can freely add/remove it from the
/// hierarchy (so the VSplitView divider disappears for real when closed) without ever
/// deallocating the process underneath.
@MainActor
private final class TerminalViewCache {
    static let shared = TerminalViewCache()
    var view: LocalProcessTerminalView?
    var coordinator: IntegratedTerminalView.Coordinator?
    private init() {}
}

struct IntegratedTerminalView: NSViewRepresentable {
    var appState: AppState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        if let cached = TerminalViewCache.shared.view {
            return cached
        }

        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        TerminalViewCache.shared.view = terminalView

        let path = appState.navigation.currentURL.path
        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: nil,
            execName: nil
        )

        // Initial cd
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        if let cached = TerminalViewCache.shared.coordinator {
            cached.parent = self
            return cached
        }
        let coordinator = Coordinator(self, initialPath: appState.navigation.currentURL.path)
        TerminalViewCache.shared.coordinator = coordinator
        return coordinator
    }

    class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: IntegratedTerminalView
        var lastPath: String

        init(_ parent: IntegratedTerminalView, initialPath: String) {
            self.parent = parent
            self.lastPath = initialPath
        }

        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }
}
