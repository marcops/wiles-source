import AppKit
import QuickLook
import SwiftUI

struct MainContentView: View {
    let sharedPreferences: PreferencesStore
    let sharedModal: ModalStore
    let sharedTransient: TransientStore
    @State private var appState: AppState
    @State private var windowUIState = WindowUIState()
    @State private var sidebarWidthSaveTask: Task<Void, Never>?

    /// Constructs `AppState` directly with the shared stores it needs, instead of default-
    /// initializing throwaway stores and swapping them in later — a default `AppState()` would run
    /// its own Trash scan and smart-folder reload only to discard the result immediately.
    init(sharedPreferences: PreferencesStore, sharedModal: ModalStore, sharedTransient: TransientStore) {
        self.sharedPreferences = sharedPreferences
        self.sharedModal = sharedModal
        self.sharedTransient = sharedTransient
        let newAppState = AppState(preferences: sharedPreferences, modal: sharedModal, transient: sharedTransient)
        newAppState.refreshCurrentDirectory()
        _appState = State(initialValue: newAppState)
    }

    var body: some View {
        ZStack {
            mainSplitView
            shortcutsHUDOverlay
        }
        .environment(windowUIState)
        .focusedSceneValue(\.windowUIState, windowUIState)
        .focusedSceneValue(\.appState, appState)
        .focusedSceneValue(\.isTextFieldEditingActive, windowUIState.renameItem != nil || windowUIState.isEditingPath)
    }

    /// The primary sidebar/content split plus its full modifier chain (window sizing, Quick Look,
    /// rename-cancellation observers, all sheets/alerts, and the translucent background). Extracted
    /// out of `body`'s `ZStack` closure so that closure stays trivially short — this is purely a
    /// relocation: the modifier chain still attaches to `HSplitView` exactly as before, and the
    /// `ZStack` still lays the shortcuts HUD on top of this content, unchanged.
    private var mainSplitView: some View {
        @Bindable var windowUIState = windowUIState
        return HSplitView {
            sidebarPane
            contentColumn
        }
        .ignoresSafeArea(.all, edges: .top)
        .frame(minWidth: effectiveWindowMinWidth, maxWidth: .infinity, minHeight: LayoutTokens.windowMinHeight, maxHeight: .infinity)
        .quickLookPreview($windowUIState.quickLookURL)
        .onChange(of: appState.navigation.currentURL) { oldURL, newURL in
            windowUIState.cancelRenameIfNavigated(from: oldURL, to: newURL)
        }
        .onChange(of: appState.selection.selectedURLs) { _, newSelection in
            windowUIState.cancelRenameIfSelectionChanged(selectedURLs: newSelection)
        }
        .onChange(of: appState.preferences.sortOption) { _, _ in appState.refreshCurrentDirectory() }
        .onChange(of: appState.preferences.sortAscending) { _, _ in appState.refreshCurrentDirectory() }
        .onChange(of: appState.preferences.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
        .modifier(WilesModalSheets(appState: appState, windowUIState: windowUIState))
        .background(mainBackgroundLayer)
    }

    private var mainBackgroundLayer: some View {
        ZStack {
            TranslucentVisualEffectView(material: .underWindowBackground)
            Color(NSColor.windowBackgroundColor)
                .opacity(appState.preferences.sidebarOverlayOpacity)
            keyboardShortcutsHandler
            GlobalKeyMonitor(appState: appState, windowUIState: windowUIState)
        }
    }

    @ViewBuilder private var shortcutsHUDOverlay: some View {
        @Bindable var windowUIState = windowUIState
        if windowUIState.showShortcutsHUD {
            ShortcutsHUDOverlay(appState: appState, isPresented: $windowUIState.showShortcutsHUD)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var sidebarPane: some View {
        SidebarView(appState: appState)
            .frame(
                minWidth: LayoutTokens.sidebarMinWidth,
                idealWidth: CGFloat(appState.preferences.sidebarWidth),
                maxWidth: LayoutTokens.sidebarMaxWidth,
                maxHeight: .infinity)
            .background(sidebarWidthTracker)
            .background(SplitViewDividerSetter(position: CGFloat(appState.preferences.sidebarWidth)))
            .layoutPriority(0)
    }

    private var contentColumn: some View {
        VStack(spacing: 0) {
            HeaderBarView(appState: appState)
            contentAndInspectorRow
            terminalDrawer
            footer
        }
        .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .background(contentTranslucentBackground)
        .layoutPriority(1)
    }

    private var contentAndInspectorRow: some View {
        HSplitView {
            contentArea
                .frame(minWidth: LayoutTokens.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .background(contentTranslucentBackground)
            inspectorPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var inspectorPane: some View {
        if appState.preferences.showDiskUsageSidebar {
            DiskUsageSidebarView(appState: appState)
                .frame(maxHeight: .infinity)
        } else if appState.preferences.showPreviewSidebar {
            PreviewSidebarView(appState: appState)
                .frame(maxHeight: .infinity)
        }
    }

    /// Plain SwiftUI VStack, not VSplitView/NSSplitView: the latter animates a pane
    /// *resizing* smoothly but not adding/removing an arranged subview, which made the
    /// terminal's close animation snap instead of collapse. A real VStack properly
    /// animates insertion/removal with `.transition`, sliding down instead of shrinking
    /// toward center. The PTY process itself survives unmount via TerminalViewCache, so
    /// removing the view here doesn't crash or leave anything running orphaned.
    @ViewBuilder private var terminalDrawer: some View {
        if appState.preferences.showTerminalDrawer {
            Divider()
            IntegratedTerminalView(appState: appState, windowUIState: windowUIState)
                .frame(height: LayoutTokens.terminalDrawerHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private var footer: some View {
        if appState.preferences.showFooter {
            FooterBarView(appState: appState)
        }
    }

    /// The window's own minimum width must grow to cover whichever trailing inspector pane
    /// (Disk Usage or Preview) is currently visible, on top of the sidebar + content minimums —
    /// otherwise the window itself can be dragged smaller than what all the visible panes need
    /// combined, and `HSplitView` has nowhere to take the missing width from except by crushing
    /// a pane below its own declared `.frame(minWidth:)`.
    private var effectiveWindowMinWidth: CGFloat {
        let inspectorMinWidth: CGFloat = if appState.preferences.showDiskUsageSidebar {
            LayoutTokens.diskUsageSidebarMinWidth
        } else if appState.preferences.showPreviewSidebar {
            LayoutTokens.previewSidebarMinWidth
        } else {
            0
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
        } else {
            FileListView(appState: appState)
        }
    }

    /// Shortcuts kept invisible on purpose: they're aliases for actions already discoverable
    /// elsewhere (a menu item, a toolbar button, or a mode-dependent alternate binding),
    /// so a second menu row for the same command would just be noise.
    private var keyboardShortcutsHandler: some View {
        HStack {
            Button("") { appState.selection.selectedURLs.removeAll() }
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

    private func toggleHiddenFiles() {
        appState.preferences.showHiddenFiles.toggle()
        appState.refreshCurrentDirectory()
    }

    private func handleDownArrowKey() {
        if appState.preferences.navigationMode == .macOS {
            appState.openSelectedItem()
        }
    }
}
