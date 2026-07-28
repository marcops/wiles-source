import SwiftUI
import QuickLook

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
        .background(keyboardShortcutsHandler)
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
            Button("") { appState.cutSelected() }.keyboardShortcut("x", modifiers: .command).hidden()
            Button("") { appState.copySelected() }.keyboardShortcut("c", modifiers: .command).hidden()
            Button("") { appState.pasteToCurrentDirectory() }.keyboardShortcut("v", modifiers: .command).hidden()
            Button("") { appState.deleteSelected() }.keyboardShortcut(.delete, modifiers: .command).hidden()
            Button("") { handleBackspaceKey() }.keyboardShortcut(.delete, modifiers: []).hidden()
            Button("") { openSelectedItem() }.keyboardShortcut("o", modifiers: .command).hidden()
            Button("") { triggerQuickLook() }.keyboardShortcut(" ", modifiers: []).hidden()
            Button("") { handleEnterKey() }.keyboardShortcut(.return, modifiers: []).hidden()
            Button("") { handleDownArrowKey() }.keyboardShortcut(.downArrow, modifiers: .command).hidden()
            Button("") { openPropertiesForSelected() }.keyboardShortcut("i", modifiers: .command).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut(".", modifiers: [.command, .shift]).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut("h", modifiers: .control).hidden()
            Button("") { appState.showHelpSheet = true }.keyboardShortcut("?", modifiers: [.command, .shift]).hidden()
        }
        .frame(width: 0, height: 0)
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
    
    private func handleBackspaceKey() {
        if appState.navigationMode == .gnome {
            appState.goUp()
        }
    }
    
    private func handleEnterKey() {
        if appState.navigationMode == .gnome {
            openSelectedItem()
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
