import AppKit
import QuickLook
import SwiftUI

struct MainContentView: View {
    private static let sidebarMaxWidth: CGFloat = 260.0
    private static let sidebarCollapsedWidth: CGFloat = 48.0
    private static let sidebarWidthSaveDebounceMs: Int = 400
    private static let contentMinWidth: CGFloat = 400.0
    private static let windowMinWidth: CGFloat = 650.0
    private static let windowMinHeight: CGFloat = 450.0
    private static let diskUsageSidebarMinWidth: CGFloat = 240.0
    private static let previewSidebarMinWidth: CGFloat = 200.0
    private static let terminalDrawerHeight: CGFloat = 200.0

    let sharedPreferences: PreferencesStore
    let sharedTransient: TransientStore
    @State private var appState: AppState
    @State private var windowUIState: WindowUIState
    @State private var sidebarWidthSaveTask: Task<Void, Never>?

    /// Constructs `AppState` directly with the shared stores it needs, instead of default-
    /// initializing throwaway stores and swapping them in later — a default `AppState()` would run
    /// its own Trash scan and smart-folder reload only to discard the result immediately.
    /// `ModalStore` (error alert state) is deliberately *not* one of the shared stores passed in
    /// here — each window gets its own fresh instance, since it holds a window-scoped, user-
    /// initiated action's error, not app-wide state (see `WindowUIState`'s doc comment on this
    /// exact bug class).
    ///
    /// Deliberately does NOT call `refreshCurrentDirectory()` here. `init()` runs on *every*
    /// reconstruction of this struct value (i.e. every time the parent view re-renders it) — that's
    /// normal, cheap SwiftUI behavior for the struct itself, but calling a real disk-scanning
    /// refresh here means every single one of those re-renders kicks off a full directory
    /// scan/icon-load on a throwaway `AppState` that's immediately discarded (`@State` only keeps
    /// its *first* `initialValue` per view identity), pegging CPU with wasted work. The refresh
    /// instead runs from `.task` below, which SwiftUI guarantees fires once per view identity.
    init(sharedPreferences: PreferencesStore, sharedTransient: TransientStore) {
        self.sharedPreferences = sharedPreferences
        self.sharedTransient = sharedTransient
        _appState = State(initialValue: AppState(preferences: sharedPreferences, modal: ModalStore(), transient: sharedTransient))
        _windowUIState = State(initialValue: WindowUIState(preferences: sharedPreferences))
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
        .task { appState.refreshCurrentDirectory() }
        .onDisappear { appState.fileSystem.tearDown() }
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
        .frame(minWidth: effectiveWindowMinWidth, maxWidth: .infinity, minHeight: Self.windowMinHeight, maxHeight: .infinity)
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

    /// Single `SidebarView` identity, only the frame width changes — swapping instances instead
    /// tore down the hover-tracking view mid-hover, firing a false exit and closing the rail early.
    private var isSidebarRail: Bool {
        appState.preferences.isSidebarCollapsed && !windowUIState.isSidebarPeeking
    }

    @ViewBuilder private var sidebarPane: some View {
        if appState.preferences.hasVisibleSidebarContent {
            SidebarView(appState: appState)
                .frame(
                    minWidth: isSidebarRail ? Self.sidebarCollapsedWidth : LayoutTokens.sidebarMinWidth,
                    idealWidth: isSidebarRail ? Self.sidebarCollapsedWidth : CGFloat(windowUIState.sidebarWidth),
                    maxWidth: isSidebarRail ? Self.sidebarCollapsedWidth : Self.sidebarMaxWidth,
                    maxHeight: .infinity)
                .background(sidebarWidthTracker)
                .background(SplitViewDividerSetter(position: CGFloat(windowUIState.sidebarWidth)))
                .layoutPriority(0)
        }
    }

    private var contentColumn: some View {
        VStack(spacing: 0) {
            HeaderBarView(appState: appState)
            contentAndInspectorRow
            terminalDrawer
            footer
        }
        .frame(minWidth: Self.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all, edges: .top)
        .background(contentTranslucentBackground)
        .layoutPriority(1)
    }

    private var contentAndInspectorRow: some View {
        HSplitView {
            contentArea
                .frame(minWidth: Self.contentMinWidth, maxWidth: .infinity, maxHeight: .infinity)
                .background(contentTranslucentBackground)
            inspectorPane
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var inspectorPane: some View {
        if windowUIState.showDiskUsageSidebar {
            DiskUsageSidebarView(appState: appState)
                .frame(maxHeight: .infinity)
        } else if windowUIState.showPreviewSidebar {
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
        if windowUIState.showTerminalDrawer {
            Divider()
            IntegratedTerminalView(appState: appState, windowUIState: windowUIState)
                .frame(height: Self.terminalDrawerHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder private var footer: some View {
        if appState.preferences.showFooter {
            FooterBarView(appState: appState, windowUIState: windowUIState)
        }
    }

    /// The window's own minimum width must grow to cover whichever trailing inspector pane
    /// (Disk Usage or Preview) is currently visible, on top of the sidebar + content minimums —
    /// otherwise the window itself can be dragged smaller than what all the visible panes need
    /// combined, and `HSplitView` has nowhere to take the missing width from except by crushing
    /// a pane below its own declared `.frame(minWidth:)`.
    private var effectiveWindowMinWidth: CGFloat {
        let inspectorMinWidth: CGFloat = if windowUIState.showDiskUsageSidebar {
            Self.diskUsageSidebarMinWidth
        } else if windowUIState.showPreviewSidebar {
            Self.previewSidebarMinWidth
        } else {
            0
        }
        return Self.windowMinWidth + inspectorMinWidth
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
        guard newWidth > 0, !isSidebarRail else { return }
        sidebarWidthSaveTask?.cancel()
        sidebarWidthSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.sidebarWidthSaveDebounceMs))
            guard !Task.isCancelled else { return }
            windowUIState.sidebarWidth = Double(newWidth)
        }
    }

    @ViewBuilder private var contentArea: some View {
        if appState.currentViewMode == .grid {
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
