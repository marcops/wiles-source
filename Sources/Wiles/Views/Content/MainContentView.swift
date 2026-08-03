import SwiftUI
import QuickLook
import AppKit

struct MainContentView: View {
    var appState: AppState
    @State private var sidebarWidthSaveTask: Task<Void, Never>?

    var body: some View {
        @Bindable var appState = appState
        return ZStack {
            HSplitView {
            SidebarView(appState: appState)
                .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: CGFloat(appState.sidebarWidth), maxWidth: LayoutTokens.sidebarMaxWidth, maxHeight: .infinity)
                .background(sidebarWidthTracker)
                .background(SplitViewDividerSetter(position: CGFloat(appState.sidebarWidth)))
                .layoutPriority(0)
            VStack(spacing: 0) {
                HeaderBarView(appState: appState)
                VSplitView {
                    HSplitView {
                        contentArea
                            .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                            .background(contentTranslucentBackground)
                        if appState.showPreviewSidebar {
                            PreviewSidebarView(appState: appState)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if appState.showTerminalDrawer {
                        IntegratedTerminalView(appState: appState)
                            .frame(minHeight: 100, idealHeight: 200, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if appState.showFooter {
                    FooterBarView(appState: appState)
                }
            }
            .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .top)
            .background(contentTranslucentBackground)
            .layoutPriority(1)
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(minWidth: LayoutTokens.windowMinWidth, maxWidth: .infinity, minHeight: LayoutTokens.windowMinHeight, maxHeight: .infinity)
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
        .sheet(isPresented: $appState.showDiskUsageSheet) {
            DiskSpaceVisualizerSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showNewFileSheet) {
            NewFileSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showConnectToServerSheet) {
            ConnectToServerSheetView(appState: appState)
        }
        .sheet(item: $appState.symlinkItem) { item in
            SymlinkSheetView(item: item, appState: appState)
        }
        .sheet(isPresented: $appState.showSaveSmartFolderSheet) {
            SaveSmartFolderSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showPasswordCompressSheet) {
            PasswordCompressSheetView(appState: appState)
        }
        .sheet(isPresented: $appState.showArchiveInspectionSheet) {
            if let url = appState.inspectArchiveURL {
                ArchiveInspectionSheetView(archiveURL: url, appState: appState)
            }
        }
        .alert(appState.tr(.emptyTrash) + "?", isPresented: $appState.showEmptyTrashAlert) {
            Button(appState.tr(.emptyTrash), role: .destructive) {
                appState.performEmptyTrash()
            }
            Button(appState.tr(.cancel), role: .cancel) {}
        } message: {
            Text(appState.tr(.emptyTrashConfirm))
        }
        .alert("Error", isPresented: $appState.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.errorMessage ?? "An error occurred.")
        }
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .underWindowBackground)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.sidebarOverlayOpacity)
                keyboardShortcutsHandler
                GlobalKeyMonitor(appState: appState)
            }
        )
        if appState.showShortcutsHUD {
            ShortcutsHUDOverlay(appState: appState)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        }
    }
    
    private var contentTranslucentBackground: some View {
        ZStack {
            TranslucentVisualEffectView(material: .sidebar)
            Color(NSColor.windowBackgroundColor)
                .opacity(appState.contentOverlayOpacity)
        }
        .ignoresSafeArea()
    }

    private var sidebarWidthTracker: some View {
        GeometryReader { geo in
            Color.clear
                .onChange(of: geo.size.width) { _, newWidth in
                    scheduleSidebarWidthSave(newWidth)
                }
        }
    }

    private func scheduleSidebarWidthSave(_ newWidth: CGFloat) {
        guard newWidth > 0 else { return }
        sidebarWidthSaveTask?.cancel()
        sidebarWidthSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(LayoutTokens.sidebarWidthSaveDebounceMs))
            guard !Task.isCancelled else { return }
            appState.sidebarWidth = Double(newWidth)
        }
    }

    @ViewBuilder
    private var contentArea: some View {
        if appState.viewMode == .grid {
            FileGridView(appState: appState)
        } else if appState.viewMode == .list {
            FileListView(appState: appState)
        } else {
            FileColumnView(appState: appState)
        }
    }
    
    /// Shortcuts kept invisible on purpose: they're aliases for actions already discoverable
    /// elsewhere (a menu item, a toolbar button, or a mode-dependent alternate binding),
    /// so a second menu row for the same command would just be noise.
    private var keyboardShortcutsHandler: some View {
        HStack {
            Button("") { appState.selectedURLs.removeAll() }.keyboardShortcut(.escape, modifiers: []).hidden()
            Button("") { handleDownArrowKey() }.keyboardShortcut(.downArrow, modifiers: .command).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut(".", modifiers: [.command, .shift]).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut("h", modifiers: .control).hidden()
            Button("") { appState.showHelpSheet = true }.keyboardShortcut("?", modifiers: [.command, .shift]).hidden()
            Button("") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    appState.showShortcutsHUD.toggle()
                }
            }.keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom)).hidden()
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

    private func handleDownArrowKey() {
        if appState.navigationMode == .macOS {
            appState.openSelectedItem()
        }
    }
}

struct SplitViewDividerSetter: NSViewRepresentable {
    let position: CGFloat

    func makeNSView(context: Context) -> ApplierView {
        let view = ApplierView()
        view.position = position
        return view
    }

    func updateNSView(_ nsView: ApplierView, context: Context) {
        nsView.position = position
    }

    class ApplierView: NSView {
        var position: CGFloat = 0
        private var hasApplied = false

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            applyIfNeeded()
        }

        override func layout() {
            super.layout()
            applyIfNeeded()
        }

        private func applyIfNeeded() {
            guard !hasApplied, let splitView = enclosingSplitView() else { return }
            hasApplied = true
            splitView.setPosition(position, ofDividerAt: 0)
        }

        private func enclosingSplitView() -> NSSplitView? {
            var view = superview
            while let current = view {
                if let splitView = current as? NSSplitView { return splitView }
                view = current.superview
            }
            return nil
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
            let isShift = NSEvent.modifierFlags.contains(.shift)
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
            } else if code == KeyCode.arrowUp {
                if appState.viewMode == .column {
                    appState.columnViewVerticalDirection = -1
                    appState.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.viewMode == .grid ? -appState.gridColumnCount : -1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
                return true
            } else if code == KeyCode.arrowDown {
                if appState.viewMode == .column {
                    appState.columnViewVerticalDirection = 1
                    appState.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.viewMode == .grid ? appState.gridColumnCount : 1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
                return true
            } else if code == KeyCode.arrowLeft {
                if appState.viewMode == .grid {
                    moveSelection(by: -1, isShift: isShift, appState: appState)
                } else if appState.viewMode == .column {
                    appState.columnViewMoveLeftTrigger += 1
                } else {
                    appState.goUp()
                }
                return true
            } else if code == KeyCode.arrowRight {
                if appState.viewMode == .grid {
                    moveSelection(by: 1, isShift: isShift, appState: appState)
                } else if appState.viewMode == .column {
                    appState.columnViewDrillRightTrigger += 1
                } else {
                    if let first = appState.selectedURLs.first, let item = appState.items.first(where: { $0.url == first }), item.isDirectory {
                        appState.navigateTo(first)
                    }
                }
                return true
            }
            return false
        }

        private func moveSelection(by offset: Int, isShift: Bool, appState: AppState) {
            let items = appState.items
            guard !items.isEmpty else { return }
            let anchorURL = appState.selectedURLs.first
            let anchorIndex = items.firstIndex(where: { $0.url == anchorURL }) ?? -1
            let newIndex = max(0, min(items.count - 1, anchorIndex + offset))
            let newURL = items[newIndex].url
            if isShift && anchorIndex >= 0 {
                let lo = min(anchorIndex, newIndex)
                let hi = max(anchorIndex, newIndex)
                appState.selectedURLs = Set(items[lo...hi].map { $0.url })
            } else {
                appState.selectedURLs = [newURL]
            }
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
