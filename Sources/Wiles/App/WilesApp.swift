import SwiftUI
import AppKit

@main
struct WilesApp: App {
    @State private var appState = AppState()
    @Environment(\.openWindow)
    private var openWindow
    @FocusedValue(\.windowUIState)
    private var windowUIState
    @FocusedValue(\.isRenamingActive)
    private var isRenamingActive

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// Never `nil` — "System" resolves to a concrete `.light`/`.dark` via `SystemAppearanceObserver`
    /// instead of passing `nil` to `.preferredColorScheme`, since `nil` doesn't reliably propagate
    /// back to an already-open window (see `SystemAppearanceObserver`'s doc comment).
    private var resolvedColorScheme: ColorScheme {
        switch appState.preferences.appAppearance {
        case .system: return SystemAppearanceObserver.shared.isDark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        WindowGroup(AppConstants.appName, id: AppConstants.mainWindowID) {
            mainWindowContent
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            appMenuCommands
            fileMenuCommands
            editMenuCommands
            viewMenuCommands
            CommandMenu(appState.tr(.goMenuTitle)) { goMenuCommands }
            CommandMenu(appState.tr(.toolsMenuTitle)) { toolsMenuCommands }
            helpMenuCommands
        }
    }

    @ViewBuilder private var mainWindowContent: some View {
        MainContentView(appState: appState)
            .preferredColorScheme(resolvedColorScheme)
            .onChange(of: resolvedColorScheme, initial: true) { _, newValue in
                // Belt-and-suspenders: force it explicitly too, since `resolvedColorScheme` is
                // always concrete now, this is the same code path already proven to propagate
                // live (explicit Light/Dark selection).
                let appearance = NSAppearance(named: newValue == .dark ? .darkAqua : .aqua)
                NSApplication.shared.appearance = appearance
                for window in NSApplication.shared.windows {
                    window.appearance = appearance
                }
            }
            .onAppear {
                NSApplication.shared.activate(ignoringOtherApps: true)
                let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png") ??
                              Bundle.main.resourceURL?.appendingPathComponent("Wiles_Wiles.bundle/AppIcon.png") ??
                              Bundle.main.bundleURL.appendingPathComponent("Wiles_Wiles.bundle/AppIcon.png")

                if let iconImage = NSImage(contentsOf: iconURL) {
                    NSApplication.shared.applicationIconImage = iconImage
                }
                // `appState` is shared by every window — every sheet/overlay toggle on it would
                // show in every open window at once if it lived there. All window-scoped sheets/
                // alerts/HUDs live on `WindowUIState` instead (one instance per window, published
                // to these menu commands via `.focusedSceneValue`/`@FocusedValue` — see
                // `WindowUIState.swift` and `WindowUIStateKey` in `MainContentView.swift`).
                // `isRestorable = false` keeps each launch starting clean instead of macOS
                // silently restoring however many windows were open at last quit.
                for window in NSApplication.shared.windows {
                    window.tabbingMode = .disallowed
                    window.isMovableByWindowBackground = false
                    window.setFrameAutosaveName("WilesMainWindow")
                    window.isRestorable = false
                }
                if !CommandLine.arguments.contains("--ui-testing") {
                    PermissionService.requestInitialPermissions(language: appState.preferences.appLanguage)
                }
                appState.refreshCurrentDirectory()
                AutoOrganizationService.shared.startMonitoring()
            }
    }

    @CommandsBuilder private var appMenuCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(appState.tr(.aboutWiles)) { windowUIState?.showAboutSheet = true }
        }
        // `SettingsView` is presented as a sheet (`windowUIState.showSettingsSheet`, wired in
        // `MainContentView`) rather than a `Settings { }` scene — a real scene always gets its own
        // native title bar/traffic-light window chrome that fights the app's own header/footer sheet
        // styling, and every attempt to strip that chrome via `NSWindow` still left rendering glitches.
        // A sheet has no window chrome to fight in the first place, matching `HelpSheet`/`AboutSheet`.
        // This also sidesteps the old duplicate-menu-item bug for good: that bug came from SwiftUI
        // auto-generating its own native "Settings…" item whenever a `Settings` scene exists, which
        // collided with `CommandGroup(replacing: .appSettings)` adding a second, translated one. With
        // no `Settings` scene at all, there's nothing left for SwiftUI to auto-generate.
        CommandGroup(replacing: .appSettings) {
            Button(appState.tr(.settingsMenuItem)) { windowUIState?.showSettingsSheet = true }
                .keyboardShortcut(",", modifiers: .command)
        }
    }

    @CommandsBuilder private var fileMenuCommands: some Commands {
        // SwiftUI's automatic "New Window" command is generated by AppKit from the OS locale, not
        // `appState.preferences.appLanguage` — it never respects the in-app language switcher.
        // Replacing `.newItem` gives full, translated control over it (see UI_TEST_BACKLOG.md).
        CommandGroup(replacing: .newItem) {
            // `appState` is a single instance shared by every window — every sheet/overlay flag on
            // it shows in every open window at once. Window-scoped presentation (New Folder,
            // Properties, Move to Trash confirmation, etc.) reads/writes `windowUIState` instead,
            // scoped to the focused window via `.focusedSceneValue` — see `WindowUIState.swift`.
            Button(appState.tr(.newWindow)) { openWindow(id: AppConstants.mainWindowID) }
                .keyboardShortcut("n", modifiers: .command)
        }
        // Same story for "Close": it has no dedicated CommandGroupPlacement, so it rides along
        // inside `.saveItem` (the only remaining File-menu placement for non-document scenes).
        CommandGroup(replacing: .saveItem) {
            Button(appState.tr(.close)) { NSApplication.shared.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
            fileItemActionCommands
        }
    }

    @ViewBuilder private var fileItemActionCommands: some View {
        Button(appState.tr(.newFolder)) {
            if let windowUIState { appState.createNewFolderAndRename(windowUIState: windowUIState) }
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])
        Button(appState.tr(.newFileTitle)) {
            if let windowUIState { appState.createNewFileAndRename(windowUIState: windowUIState) }
        }
        Divider()
        Button(appState.tr(.open)) { appState.openSelectedItem() }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(appState.selectedURLs.isEmpty)
        Button(appState.tr(.properties)) {
            if let windowUIState { appState.openPropertiesForSelected(windowUIState: windowUIState) }
        }
        .keyboardShortcut("i", modifiers: .command)
        .disabled(appState.selectedURLs.isEmpty)
        Button(appState.tr(.quickLook)) {
            if let windowUIState { appState.triggerQuickLookForSelected(windowUIState: windowUIState) }
        }
        .keyboardShortcut(" ", modifiers: [])
        .disabled(appState.selectedURLs.isEmpty)
        Divider()
        Button(appState.tr(.moveToTrash)) {
            if let windowUIState { appState.deleteSelected(windowUIState: windowUIState) }
        }
        .disabled(appState.selectedURLs.isEmpty)
    }

    @CommandsBuilder private var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(appState.tr(.undo)) { appState.undoLastAction() }
                .keyboardShortcut("z", modifiers: .command)
            Button(appState.tr(.redo)) { appState.redoLastAction() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .pasteboard) {
            // While renaming, these keep their shortcut but forward to the system's standard text
            // editing actions instead, so the rename field's own text gets cut/copied/pasted/selected.
            let isRenaming = isRenamingActive ?? false
            Button(appState.tr(.cut)) {
                if isRenaming { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) } else { appState.cutSelected() }
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(!isRenaming && appState.selectedURLs.isEmpty)
            Button(appState.tr(.copy)) {
                if isRenaming { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) } else { appState.copySelected() }
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!isRenaming && appState.selectedURLs.isEmpty)
            Button(appState.tr(.paste)) {
                if isRenaming { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) } else { appState.pasteToCurrentDirectory() }
            }
            .keyboardShortcut("v", modifiers: .command)
            Divider()
            Button(appState.tr(.selectAll)) {
                if isRenaming { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) } else { appState.selectAllItems() }
            }
            .keyboardShortcut("a", modifiers: .command)
            Divider()
            Button(appState.tr(.find)) { appState.toggleSearching() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    // Everyday, frequently-toggled panels/actions stay here for quick keyboard access. Lower-
    // frequency display preferences (hidden files, tags, compact density, sidebar sections/mode)
    // moved into the new `Settings` scene (⌘,) — see `Views/Settings/*.swift` — to declutter the
    // menu bar per the redesign; those bindings still live on the same `PreferencesStore`, so
    // toggling them in Settings updates the UI live with zero behavior change.
    @CommandsBuilder private var viewMenuCommands: some Commands {
        CommandGroup(after: .sidebar) {
            sidebarViewMenuItems
        }
    }

    @ViewBuilder private var sidebarViewMenuItems: some View {
        Divider()
        Toggle(appState.tr(appState.preferences.showTerminalDrawer ? .hideTerminal : .showTerminal), isOn: $appState.preferences.showTerminalDrawer)
            .keyboardShortcut("j", modifiers: .command)
        Toggle(appState.tr(appState.preferences.showPreviewSidebar ? .hidePreview : .showPreviewSidebar), isOn: $appState.preferences.showPreviewSidebar)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        Toggle(appState.tr(appState.preferences.showDiskUsageSidebar ? .hideDiskUsageSidebar : .showDiskUsageSidebar), isOn: $appState.preferences.showDiskUsageSidebar)
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Menu(appState.tr(.sidebarMenuTitle)) {
            Toggle(appState.tr(.showFavorites), isOn: $appState.preferences.showFavorites)
            Toggle(appState.tr(.showPlaces), isOn: $appState.preferences.showPlaces)
            Toggle(appState.tr(.showRecents), isOn: $appState.preferences.showRecents)
            Toggle(appState.tr(.showNetworkAndCloud), isOn: $appState.preferences.showNetworkAndCloud)
            Toggle(appState.tr(.showDirectoryTree), isOn: $appState.preferences.showDirectoryTree)
            Toggle(appState.tr(.showSidebarSectionTitles), isOn: $appState.preferences.showSidebarSectionTitles)
            Toggle(appState.tr(.showTags), isOn: $appState.preferences.showTags)
        }
        Divider()
        Picker(selection: $appState.preferences.viewMode) {
            Text(appState.tr(.gridView)).tag(ViewMode.grid)
            Text(appState.tr(.listView)).tag(ViewMode.list)
            Text(appState.tr(.columnView)).tag(ViewMode.column)
        } label: {
            Label(appState.tr(.viewMode), systemImage: "square.grid.2x2")
        }
        Menu {
            Picker(appState.tr(.sortBy), selection: $appState.preferences.sortOption) {
                ForEach(SortOption.allCases) { opt in Text(appState.tr(opt.l10nKey)).tag(opt) }
            }
            .onChange(of: appState.preferences.sortOption) { _, _ in appState.refreshCurrentDirectory() }
            Divider()
            Toggle(appState.tr(.ascending), isOn: $appState.preferences.sortAscending)
                .onChange(of: appState.preferences.sortAscending) { _, _ in appState.refreshCurrentDirectory() }
        } label: {
            Label(appState.tr(.sortBy), systemImage: "arrow.up.arrow.down")
        }
    }

    @ViewBuilder private var goMenuCommands: some View {
        Button(appState.tr(.back)) { appState.goBack() }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(appState.navigation.historyBack.isEmpty)
        Button(appState.tr(.forward)) { appState.goForward() }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(appState.navigation.historyForward.isEmpty)
        Button(appState.tr(.enclosingFolder)) { appState.goUp() }
        Divider()
        Button(appState.tr(.goToFolder)) {
            if let windowUIState { appState.startEditingPath(windowUIState: windowUIState) }
        }
        .keyboardShortcut("l", modifiers: .command)
        Button(appState.tr(.connectToServer) + "...") { windowUIState?.showConnectToServerSheet = true }
            .keyboardShortcut("k", modifiers: .command)
    }

    @ViewBuilder private var toolsMenuCommands: some View {
        Button(appState.tr(.autoOrganization) + "...") { windowUIState?.showAutoOrganizationSheet = true }
        Button(appState.tr(.findDuplicates)) { windowUIState?.showDuplicateCleanerSheet = true }
        Divider()
        Menu(appState.tr(.copyPath)) {
            Button(appState.tr(.copyPathAbsolute)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .absolute)
            }
            Button(appState.tr(.copyPathRelative)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .relative, relativeTo: appState.navigation.currentURL.deletingLastPathComponent())
            }
            Button(appState.tr(.copyPathURL)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .fileURL)
            }
            Button(appState.tr(.copyPathTerminal)) {
                CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .terminalEscaped)
            }
        }
    }

    @CommandsBuilder private var helpMenuCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button(appState.tr(.wilesHelpAndShortcuts)) { windowUIState?.showHelpSheet = true }
                .keyboardShortcut("?", modifiers: .command)
            Button(appState.tr(.shortcutsCheatsheetTitle)) {
                withAnimation(MotionTokens.snappySpring) {
                    windowUIState?.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
        }
    }
}
