import SwiftUI
import SwiftTerm
import AppKit

struct IntegratedTerminalView: NSViewRepresentable {
    var appState: AppState

    func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator

        let path = appState.currentURL.path

        terminalView.startProcess(
            executable: "/bin/zsh",
            args: ["-l"],
            environment: nil,
            execName: nil
        )

        // Initial cd
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            terminalView.send(txt: "cd \"\(path)\"\r")
            terminalView.send(txt: "clear\r")
        }

        return terminalView
    }

    func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        let currentPath = appState.currentURL.path
        if context.coordinator.lastPath != currentPath {
            context.coordinator.lastPath = currentPath
            // Send cd command to the terminal
            nsView.send(txt: "cd \"\(currentPath)\"\r")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, initialPath: appState.currentURL.path)
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
