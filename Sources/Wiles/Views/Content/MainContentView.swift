import SwiftUI
import QuickLook
import AppKit

/// Per-window focus key for `WindowUIState`. Published via `.focusedSceneValue` (not
/// `.focusedValue`, which needs an actual SwiftUI-focused control — this app uses custom
/// `NSEvent` monitors instead of native focus) so the menu commands in `WilesApp`, which live
/// outside any single window's view hierarchy, can read/toggle only the currently active window's
/// sheets, alerts, and shortcuts HUD. See `WindowUIState` for the full rationale.
private struct WindowUIStateKey: FocusedValueKey {
    typealias Value = WindowUIState
}

extension FocusedValues {
    var windowUIState: WindowUIState? {
        get { self[WindowUIStateKey.self] }
        set { self[WindowUIStateKey.self] = newValue }
    }
}

struct MainContentView: View {
    var appState: AppState
    @State private var windowUIState = WindowUIState()
    @State private var sidebarWidthSaveTask: Task<Void, Never>?

    var body: some View {
        @Bindable var appState = appState
        @Bindable var windowUIState = windowUIState
        return ZStack {
            HSplitView {
            SidebarView(appState: appState)
                .frame(minWidth: LayoutTokens.sidebarMinWidth, idealWidth: CGFloat(appState.preferences.sidebarWidth), maxWidth: LayoutTokens.sidebarMaxWidth, maxHeight: .infinity)
                .background(sidebarWidthTracker)
                .background(SplitViewDividerSetter(position: CGFloat(appState.preferences.sidebarWidth)))
                .layoutPriority(0)
            VStack(spacing: 0) {
                HeaderBarView(appState: appState)
                HSplitView {
                    contentArea
                        .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                        .background(contentTranslucentBackground)
                    if appState.preferences.showDiskUsageSidebar {
                        DiskUsageSidebarView(appState: appState)
                            .frame(maxHeight: .infinity)
                    } else if appState.preferences.showPreviewSidebar {
                        PreviewSidebarView(appState: appState)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Plain SwiftUI VStack, not VSplitView/NSSplitView: the latter animates a pane
                // *resizing* smoothly but not adding/removing an arranged subview, which made the
                // terminal's close animation snap instead of collapse. A real VStack properly
                // animates insertion/removal with `.transition`, sliding down instead of shrinking
                // toward center. The PTY process itself survives unmount via TerminalViewCache, so
                // removing the view here doesn't crash or leave anything running orphaned.
                if appState.preferences.showTerminalDrawer {
                    Divider()
                    IntegratedTerminalView(appState: appState)
                        .frame(height: 200)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if appState.preferences.showFooter {
                    FooterBarView(appState: appState)
                }
            }
            .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .top)
            .background(contentTranslucentBackground)
            .layoutPriority(1)
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(minWidth: effectiveWindowMinWidth, maxWidth: .infinity, minHeight: LayoutTokens.windowMinHeight, maxHeight: .infinity)
        .quickLookPreview($windowUIState.quickLookURL)
        .sheet(item: $windowUIState.propertiesItem) { item in
            FilePropertiesSheet(item: item, appState: appState)
        }
        .sheet(isPresented: $windowUIState.showNewFolderSheet) {
            NewFolderSheet(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showHelpSheet) {
            HelpSheet(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showAboutSheet) {
            AboutSheet(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showSettingsSheet) {
            SettingsView(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showAutoOrganizationSheet) {
            AutoOrganizationSheet(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showDuplicateCleanerSheet) {
            DuplicateCleanerSheetView(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showHttpShareSheet) {
            if let url = windowUIState.httpShareFolderURL {
                HttpShareSheet(appState: appState, folderURL: url)
            }
        }
        .sheet(item: $windowUIState.renameItem) { item in
            RenameSheetView(item: item, appState: appState)
        }
        .sheet(item: $windowUIState.imageConverterItem) { item in
            ImageConverterSheetView(item: item, appState: appState)
        }
        .sheet(isPresented: $windowUIState.showBatchRenameSheet) {
            let selectedItems = appState.fileSystem.items.filter { appState.selectedURLs.contains($0.url) }
            BatchRenameSheetView(items: selectedItems, appState: appState)
        }
        .sheet(isPresented: $windowUIState.showNewFileSheet) {
            NewFileSheetView(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showConnectToServerSheet) {
            ConnectToServerSheetView(appState: appState)
        }
        .sheet(item: $windowUIState.symlinkItem) { item in
            SymlinkSheetView(item: item, appState: appState)
        }
        .sheet(isPresented: $windowUIState.showSaveSmartFolderSheet) {
            SaveSmartFolderSheetView(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showPasswordCompressSheet) {
            PasswordCompressSheetView(appState: appState)
        }
        .sheet(isPresented: $windowUIState.showArchiveInspectionSheet) {
            if let url = windowUIState.inspectArchiveURL {
                ArchiveInspectionSheetView(archiveURL: url, appState: appState)
            }
        }
        .alert(appState.tr(.emptyTrash) + "?", isPresented: $windowUIState.showEmptyTrashAlert) {
            Button(appState.tr(.emptyTrash), role: .destructive) {
                appState.performEmptyTrash()
            }
            Button(appState.tr(.cancel), role: .cancel) {}
        } message: {
            Text(appState.tr(.emptyTrashConfirm))
        }
        .alert(appState.tr(.moveToTrash) + "?", isPresented: $windowUIState.showDeleteConfirmAlert) {
            Button(appState.tr(.moveToTrash), role: .destructive) {
                appState.performDeleteSelected()
            }
            Button(appState.tr(.cancel), role: .cancel) {}
        } message: {
            Text(appState.tr(.moveToTrashConfirm))
        }
        .alert(appState.tr(.errorAlertTitle), isPresented: $appState.modal.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appState.modal.errorMessage ?? "An error occurred.")
        }
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .underWindowBackground)
                Color(NSColor.windowBackgroundColor)
                    .opacity(appState.preferences.sidebarOverlayOpacity)
                keyboardShortcutsHandler
                GlobalKeyMonitor(appState: appState, windowUIState: windowUIState)
            }
        )
        if windowUIState.showShortcutsHUD {
            ShortcutsHUDOverlay(appState: appState, isPresented: $windowUIState.showShortcutsHUD)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
        }
        .environment(windowUIState)
        .focusedSceneValue(\.windowUIState, windowUIState)
    }

    /// The window's own minimum width must grow to cover whichever trailing inspector pane
    /// (Disk Usage or Preview) is currently visible, on top of the sidebar + content minimums —
    /// otherwise the window itself can be dragged smaller than what all the visible panes need
    /// combined, and `HSplitView` has nowhere to take the missing width from except by crushing
    /// a pane below its own declared `.frame(minWidth:)`.
    private var effectiveWindowMinWidth: CGFloat {
        let inspectorMinWidth: CGFloat
        if appState.preferences.showDiskUsageSidebar {
            inspectorMinWidth = 240
        } else if appState.preferences.showPreviewSidebar {
            inspectorMinWidth = 200
        } else {
            inspectorMinWidth = 0
        }
        return LayoutTokens.windowMinWidth + inspectorMinWidth
    }

    private var contentTranslucentBackground: some View {
        ZStack {
            TranslucentVisualEffectView(material: .sidebar)
            Color(NSColor.windowBackgroundColor)
                .opacity(appState.preferences.contentOverlayOpacity)
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
            appState.preferences.sidebarWidth = Double(newWidth)
        }
    }

    @ViewBuilder private var contentArea: some View {
        if appState.preferences.viewMode == .grid {
            FileGridView(appState: appState)
        } else if appState.preferences.viewMode == .list {
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
            Button("") { appState.selectedURLs.removeAll() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
                .disabled(windowUIState.showShortcutsHUD)
            Button("") { handleDownArrowKey() }.keyboardShortcut(.downArrow, modifiers: .command).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut(".", modifiers: [.command, .shift]).hidden()
            Button("") { toggleHiddenFiles() }.keyboardShortcut("h", modifiers: .control).hidden()
            Button("") { windowUIState.showHelpSheet = true }.keyboardShortcut("?", modifiers: [.command, .shift]).hidden()
            Button("") {
                withAnimation(MotionTokens.snappySpring) {
                    windowUIState.showShortcutsHUD.toggle()
                }
            }.keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom)).hidden()
        }
        .onDeleteCommand {
            appState.deleteSelected(windowUIState: windowUIState)
        }
    }

    private func triggerRenameForSelected() {
        if let first = appState.selectedURLs.first, let item = appState.fileSystem.items.first(where: { $0.url == first }) {
            windowUIState.renameItem = item
        }
    }

    private func toggleHiddenFiles() {
        appState.preferences.showHiddenFiles.toggle()
        appState.refreshCurrentDirectory()
    }

    private func handleDownArrowKey() {
        if appState.navigationMode == .macOS {
            appState.openSelectedItem()
        }
    }
}

struct GlobalKeyMonitor: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.appState = appState
        view.windowUIState = windowUIState
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {
        nsView.appState = appState
        nsView.windowUIState = windowUIState
    }

    class KeyMonitorNSView: NSView {
        var appState: AppState?
        var windowUIState: WindowUIState?
        private var monitor: Any?
        private var accumulatedScrollDelta: Double = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
                    self?.processLocalEvent(event)
                }
            }
        }

        private func processLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState = appState, let windowUIState = windowUIState else { return event }
            if let firstResponder = event.window?.firstResponder, firstResponder is NSTextView || firstResponder is NSTextField {
                return event
            }

            if event.type == .scrollWheel {
                return handleScrollEvent(event, appState: appState)
            } else if event.type == .keyDown {
                return handleKeyDownEvent(event, appState: appState, windowUIState: windowUIState)
            }
            return event
        }

        private func handleScrollEvent(_ event: NSEvent, appState: AppState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            guard isCmd || isCtrl else { return event }

            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard delta != 0 else { return event }

            accumulatedScrollDelta += delta
            let stepMagnitude = IconSizeToken.scrollWheelStep
            while abs(accumulatedScrollDelta) >= stepMagnitude {
                let step = accumulatedScrollDelta > 0 ? stepMagnitude : -stepMagnitude
                appState.preferences.iconSize = min(IconSizeToken.maxSize, max(IconSizeToken.minSize, appState.preferences.iconSize + step))
                accumulatedScrollDelta -= step
            }
            return nil
        }

        private func handleKeyDownEvent(_ event: NSEvent, appState: AppState, windowUIState: WindowUIState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            let code = event.keyCode

            if (isCmd || isCtrl) && handleZoomKeyDown(code: code, appState: appState) {
                return nil
            }
            if handleNavigationKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState) {
                return nil
            }
            return event
        }

        private func handleZoomKeyDown(code: UInt16, appState: AppState) -> Bool {
            switch code {
            case KeyCode.equals, KeyCode.keypadPlus, KeyCode.bracketRight:
                appState.preferences.iconSize = min(IconSizeToken.maxSize, appState.preferences.iconSize + IconSizeToken.step)
                return true
            case KeyCode.minus, KeyCode.keypadMinus:
                appState.preferences.iconSize = max(IconSizeToken.minSize, appState.preferences.iconSize - IconSizeToken.step)
                return true
            case KeyCode.zero:
                appState.preferences.iconSize = IconSizeToken.defaultSize
                return true
            default:
                return false
            }
        }

        private func handleNavigationKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if let arrowCode = ArrowKey(code: code) {
                if isCmd, let fav = windowUIState.selectedFavoriteURL,
                    fav.standardizedFileURL == appState.navigation.currentURL.standardizedFileURL,
                    arrowCode == .up || arrowCode == .down {
                    appState.moveSelectedFavorite(offset: arrowCode == .up ? -1 : 1, windowUIState: windowUIState)
                    return true
                }
                let isShift = NSEvent.modifierFlags.contains(.shift)
                handleArrowKeyDown(arrowCode, isShift: isShift, appState: appState)
                return true
            }
            return handleEditActionKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState)
        }

        private enum ArrowKey: Equatable {
            case up, down, left, right

            init?(code: UInt16) {
                switch code {
                case KeyCode.arrowUp: self = .up
                case KeyCode.arrowDown: self = .down
                case KeyCode.arrowLeft: self = .left
                case KeyCode.arrowRight: self = .right
                default: return nil
                }
            }
        }

        private func handleArrowKeyDown(_ key: ArrowKey, isShift: Bool, appState: AppState) {
            switch key {
            case .up:
                if appState.preferences.viewMode == .column {
                    appState.selection.columnViewVerticalDirection = -1
                    appState.selection.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.preferences.viewMode == .grid ? -appState.selection.gridColumnCount : -1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
            case .down:
                if appState.preferences.viewMode == .column {
                    appState.selection.columnViewVerticalDirection = 1
                    appState.selection.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.preferences.viewMode == .grid ? appState.selection.gridColumnCount : 1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
            case .left:
                if appState.preferences.viewMode == .grid {
                    moveSelection(by: -1, isShift: isShift, appState: appState)
                } else if appState.preferences.viewMode == .column {
                    appState.selection.columnViewMoveLeftTrigger += 1
                } else {
                    appState.goUp()
                }
            case .right:
                if appState.preferences.viewMode == .grid {
                    moveSelection(by: 1, isShift: isShift, appState: appState)
                } else if appState.preferences.viewMode == .column {
                    appState.selection.columnViewDrillRightTrigger += 1
                } else if let first = appState.selectedURLs.first,
                    let item = appState.fileSystem.items.first(where: { $0.url == first }), item.isDirectory {
                    appState.navigateTo(first)
                }
            }
        }

        private func handleEditActionKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if code == KeyCode.f2 {
                if !appState.selectedURLs.isEmpty {
                    triggerRenameForSelected(appState: appState, windowUIState: windowUIState)
                    return true
                }
            } else if code == KeyCode.backspace || code == KeyCode.forwardDelete {
                if !appState.selectedURLs.isEmpty {
                    appState.deleteSelected(windowUIState: windowUIState)
                    return true
                } else if appState.navigationMode == .gnome && !isCmd {
                    appState.goUp()
                    return true
                }
            } else if code == KeyCode.returnKey {
                return handleReturnKeyDown(isCmd: isCmd, appState: appState, windowUIState: windowUIState)
            }
            return false
        }

        private func handleReturnKeyDown(isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if isCmd && !appState.selectedURLs.isEmpty {
                appState.deleteSelected(windowUIState: windowUIState)
                return true
            } else if !isCmd {
                if appState.navigationMode == .gnome, let first = appState.selectedURLs.first {
                    appState.navigateTo(first)
                    return true
                } else if appState.navigationMode == .macOS, let first = appState.selectedURLs.first,
                    let item = appState.fileSystem.items.first(where: { $0.url == first }) {
                    windowUIState.renameItem = item
                    return true
                }
            }
            return false
        }

        private func moveSelection(by offset: Int, isShift: Bool, appState: AppState) {
            let items = appState.fileSystem.items
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

        private func triggerRenameForSelected(appState: AppState, windowUIState: WindowUIState) {
            if appState.selectedURLs.count > 1 {
                windowUIState.showBatchRenameSheet = true
            } else if let first = appState.selectedURLs.first, let item = appState.fileSystem.items.first(where: { $0.url == first }) {
                windowUIState.renameItem = item
            }
        }
    }
}
