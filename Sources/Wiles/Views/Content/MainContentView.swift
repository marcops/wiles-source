import SwiftUI
import QuickLook
import AppKit

struct MainContentView: View {
    var appState: AppState
    
    var body: some View {
        @Bindable var appState = appState
        return VStack(spacing: 0) {
            HeaderBarView(appState: appState)
            Divider()
            HSplitView {
                SidebarView(appState: appState)
                    .frame(minWidth: 140, idealWidth: 150, maxWidth: 260)
                contentArea
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(minWidth: 650, minHeight: 450)
        .quickLookPreview($appState.quickLookURL)
        .background(
            ZStack {
                keyboardShortcutsHandler
                GlobalKeyMonitor(appState: appState)
            }
        )
    }
    
    @ViewBuilder
    private var contentArea: some View {
        if appState.viewMode == .grid {
            FileGridView(appState: appState)
        } else {
            FileListView(appState: appState)
        }
    }
    
    private var keyboardShortcutsHandler: some View {
        HStack {
            Button("") { appState.selectedURLs.removeAll() }.keyboardShortcut(.escape, modifiers: []).hidden()
            Button("") { appState.cutSelected() }.keyboardShortcut("x", modifiers: .command).hidden()
            Button("") { appState.copySelected() }.keyboardShortcut("c", modifiers: .command).hidden()
            Button("") { appState.pasteToCurrentDirectory() }.keyboardShortcut("v", modifiers: .command).hidden()
            Button("") { openSelectedItem() }.keyboardShortcut("o", modifiers: .command).hidden()
            Button("") { triggerQuickLook() }.keyboardShortcut(" ", modifiers: []).hidden()
            Button("") { handleDownArrowKey() }.keyboardShortcut(.downArrow, modifiers: .command).hidden()
            Button("") { openPropertiesForSelected() }.keyboardShortcut("i", modifiers: .command).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut(".", modifiers: [.command, .shift]).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut("h", modifiers: .control).hidden()
            Button("") { appState.showHelpSheet = true }.keyboardShortcut("?", modifiers: [.command, .shift]).hidden()
        }
        .onDeleteCommand {
            appState.deleteSelected()
        }
    }
    
    private func toggleHiddenFiles() {
        appState.showHiddenFiles.toggle()
        appState.refreshCurrentDirectory()
    }
    
    private func triggerQuickLook() {
        if let first = appState.selectedURLs.first {
            appState.quickLookURL = first
        }
    }
    
    private func openPropertiesForSelected() {
        if let first = appState.selectedURLs.first, let item = appState.items.first(where: { $0.url == first }) {
            appState.propertiesItem = item
        }
    }
    
    private func handleDownArrowKey() {
        if appState.navigationMode == .macOS {
            openSelectedItem()
        }
    }
    
    private func openSelectedItem() {
        if let first = appState.selectedURLs.first {
            appState.navigateTo(first)
        }
    }
}

struct GlobalKeyMonitor: NSViewRepresentable {
    var appState: AppState

    func makeNSView(context: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.appState = appState
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {
        nsView.appState = appState
    }

    class KeyMonitorNSView: NSView {
        var appState: AppState?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let appState = self?.appState else { return event }
                    
                    if let firstResponder = event.window?.firstResponder, firstResponder is NSTextView || firstResponder is NSTextField {
                        return event
                    }
                    
                    let keyCode = event.keyCode
                    let isCmd = event.modifierFlags.contains(.command)
                    
                    // KeyCode 51 = Backspace/Delete, KeyCode 117 = Forward Delete, KeyCode 36 = Return
                    if keyCode == 51 || keyCode == 117 {
                        if !appState.selectedURLs.isEmpty {
                            appState.deleteSelected()
                            return nil
                        } else if appState.navigationMode == .gnome && !isCmd {
                            appState.goUp()
                            return nil
                        }
                    } else if keyCode == 36 && isCmd {
                        if !appState.selectedURLs.isEmpty {
                            appState.deleteSelected()
                            return nil
                        }
                    } else if keyCode == 36 && !isCmd {
                        if appState.navigationMode == .gnome, let first = appState.selectedURLs.first {
                            appState.navigateTo(first)
                            return nil
                        }
                    }
                    
                    return event
                }
            }
        }
    }
}
