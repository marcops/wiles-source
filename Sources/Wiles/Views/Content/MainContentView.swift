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
            if appState.showFooter {
                Divider()
                FooterBarView(appState: appState)
            }
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(minWidth: 650, minHeight: 450)
        .quickLookPreview($appState.quickLookURL)
        .sheet(item: $appState.renameItem) { item in
            RenameSheetView(item: item, appState: appState)
        }
        .sheet(item: $appState.imageConverterItem) { item in
            ImageConverterSheetView(item: item, appState: appState)
        }
        .sheet(isPresented: $appState.showBatchRenameSheet) {
            let selectedItems = appState.items.filter { appState.selectedURLs.contains($0.url) }
            BatchRenameSheetView(items: selectedItems, appState: appState)
        }
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
            Button("") { appState.selectedURLs = Set(appState.items.map { $0.url }) }.keyboardShortcut("a", modifiers: .command).hidden()
            Button("") { appState.cutSelected() }.keyboardShortcut("x", modifiers: .command).hidden()
            Button("") { appState.copySelected() }.keyboardShortcut("c", modifiers: .command).hidden()
            Button("") { appState.pasteToCurrentDirectory() }.keyboardShortcut("v", modifiers: .command).hidden()
            Button("") { openSelectedItem() }.keyboardShortcut("o", modifiers: .command).hidden()
            Button("") { triggerQuickLook() }.keyboardShortcut(" ", modifiers: []).hidden()
            Button("") { handleDownArrowKey() }.keyboardShortcut(.downArrow, modifiers: .command).hidden()
            Button("") { openPropertiesForSelected() }.keyboardShortcut("i", modifiers: .command).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut(".", modifiers: [.command, .shift]).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut("h", modifiers: .control).hidden()
            Button("") { focusPathField() }.keyboardShortcut("l", modifiers: .command).hidden()
            Button("") { appState.showHelpSheet = true }.keyboardShortcut("?", modifiers: [.command, .shift]).hidden()
        }
        .onDeleteCommand {
            appState.deleteSelected()
        }
    }
    
    private func triggerRenameForSelected() {
        if let first = appState.selectedURLs.first, let item = appState.items.first(where: { $0.url == first }) {
            appState.renameItem = item
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
    
    private func focusPathField() {
        appState.pathText = appState.currentURL.path
        appState.isEditingPath = true
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
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
                    self?.processLocalEvent(event)
                }
            }
        }

        private func processLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState = appState else { return event }
            if let firstResponder = event.window?.firstResponder, firstResponder is NSTextView || firstResponder is NSTextField {
                return event
            }
            
            if event.type == .scrollWheel {
                return handleScrollEvent(event, appState: appState)
            } else if event.type == .keyDown {
                return handleKeyDownEvent(event, appState: appState)
            }
            return event
        }

        private func handleScrollEvent(_ event: NSEvent, appState: AppState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            guard isCmd || isCtrl else { return event }

            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard delta != 0 else { return event }

            let step = delta > 0 ? 4.0 : -4.0
            appState.iconSize = min(IconSizeToken.maxSize, max(IconSizeToken.minSize, appState.iconSize + step))
            return nil
        }

        private func handleKeyDownEvent(_ event: NSEvent, appState: AppState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            let code = event.keyCode

            if (isCmd || isCtrl) && handleZoomKeyDown(code: code, appState: appState) {
                return nil
            }
            if handleNavigationKeyDown(code: code, isCmd: isCmd, appState: appState) {
                return nil
            }
            return event
        }

        private func handleZoomKeyDown(code: UInt16, appState: AppState) -> Bool {
            switch code {
            case KeyCode.equals, KeyCode.keypadPlus, KeyCode.bracketRight:
                appState.iconSize = min(IconSizeToken.maxSize, appState.iconSize + IconSizeToken.step)
                return true
            case KeyCode.minus, KeyCode.keypadMinus:
                appState.iconSize = max(IconSizeToken.minSize, appState.iconSize - IconSizeToken.step)
                return true
            case KeyCode.zero:
                appState.iconSize = IconSizeToken.defaultSize
                return true
            default:
                return false
            }
        }

        private func handleNavigationKeyDown(code: UInt16, isCmd: Bool, appState: AppState) -> Bool {
            if code == KeyCode.f2 {
                if !appState.selectedURLs.isEmpty {
                    triggerRenameForSelected(appState: appState)
                    return true
                }
            } else if code == KeyCode.backspace || code == KeyCode.forwardDelete {
                if !appState.selectedURLs.isEmpty {
                    appState.deleteSelected()
                    return true
                } else if appState.navigationMode == .gnome && !isCmd {
                    appState.goUp()
                    return true
                }
            } else if code == KeyCode.returnKey {
                if isCmd && !appState.selectedURLs.isEmpty {
                    appState.deleteSelected()
                    return true
                } else if !isCmd {
                    if appState.navigationMode == .gnome, let first = appState.selectedURLs.first {
                        appState.navigateTo(first)
                        return true
                    } else if appState.navigationMode == .macOS, let first = appState.selectedURLs.first, let item = appState.items.first(where: { $0.url == first }) {
                        appState.renameItem = item
                        return true
                    }
                }
            }
            return false
        }

        private func triggerRenameForSelected(appState: AppState) {
            if appState.selectedURLs.count > 1 {
                appState.showBatchRenameSheet = true
            } else if let first = appState.selectedURLs.first, let item = appState.items.first(where: { $0.url == first }) {
                appState.renameItem = item
            }
        }
    }
}
