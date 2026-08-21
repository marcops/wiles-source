import AppKit
import GitBeacon
import SwiftUI

@main
struct WilesApp: App {
    @State private var sharedPreferences = PreferencesStore()
    @State private var sharedModal = ModalStore()
    @State private var sharedTransient = TransientStore()
    @Environment(\.openWindow)
    private var openWindow
    @FocusedValue(\.appState)
    private var appState
    @FocusedValue(\.windowUIState)
    private var windowUIState
    @FocusedValue(\.isTextFieldEditingActive)
    private var isTextFieldEditingActive

    private func tr(_ key: L10n.Key) -> String {
        L10n.string(key, lang: sharedPreferences.appLanguage)
    }

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false

        GitBeacon.configure(
            owner: CrashReportingConstants.githubOwner,
            repo: CrashReportingConstants.githubRepo,
            token: CrashReportingConstants.githubToken,
            appVersion: AppConstants.appVersion,
            build: AppConstants.appBuild)
        GitBeacon.installCrashHandler()
    }

    /// Never `nil` — "System" resolves to a concrete `.light`/`.dark` via `SystemAppearanceObserver`
    /// instead of passing `nil` to `.preferredColorScheme`, since `nil` doesn't reliably propagate
    /// back to an already-open window (see `SystemAppearanceObserver`'s doc comment).
    private var resolvedColorScheme: ColorScheme {
        switch sharedPreferences.appAppearance {
        case .system: SystemAppearanceObserver.shared.isDark ? .dark : .light
        case .light: .light
        case .dark: .dark
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
            CommandMenu(tr(.goMenuTitle)) { goMenuCommands }
            CommandMenu(tr(.toolsMenuTitle)) { toolsMenuCommands }
            helpMenuCommands
        }
    }

    private var mainWindowContent: some View {
        MainContentView(sharedPreferences: sharedPreferences, sharedModal: sharedModal, sharedTransient: sharedTransient)
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
                // `isRestorable = false` keeps each launch starting clean instead of macOS silently
                // restoring however many windows were open at last quit.
                for window in NSApplication.shared.windows {
                    window.tabbingMode = .disallowed
                    window.isMovableByWindowBackground = false
                    window.setFrameAutosaveName("WilesMainWindow")
                    window.isRestorable = false
                }
                if !CommandLine.arguments.contains("--ui-testing") {
                    PermissionService.requestInitialPermissions(language: sharedPreferences.appLanguage)
                }
                AutoOrganizationService.shared.startMonitoring()
                Task {
                    await GitBeacon.processPendingReports()
                }
            }
    }

    @CommandsBuilder private var appMenuCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(tr(.aboutWiles)) { windowUIState?.showAboutSheet = true }
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
            Button(tr(.settingsMenuItem)) { windowUIState?.showSettingsSheet = true }
                .keyboardShortcut(",", modifiers: .command)
        }
    }

    @CommandsBuilder private var fileMenuCommands: some Commands {
        // SwiftUI's automatic "New Window" command is generated by AppKit from the OS locale, not
        // `appState.preferences.appLanguage` — it never respects the in-app language switcher.
        // Replacing `.newItem` gives full, translated control over it (see UI_TEST_BACKLOG.md).
        CommandGroup(replacing: .newItem) {
            Button(tr(.newWindow)) { openWindow(id: AppConstants.mainWindowID) }
                .keyboardShortcut("n", modifiers: .command)
        }
        // Same story for "Close": it has no dedicated CommandGroupPlacement, so it rides along
        // inside `.saveItem` (the only remaining File-menu placement for non-document scenes).
        CommandGroup(replacing: .saveItem) {
            Button(tr(.close)) { NSApplication.shared.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: .command)
        }
        CommandGroup(after: .newItem) {
            fileItemActionCommands
        }
    }

    @ViewBuilder private var fileItemActionCommands: some View {
        if let appState, let windowUIState {
            Button(tr(.newFolder)) { appState.createNewFolderAndRename(windowUIState: windowUIState) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button(tr(.newFileTitle)) { appState.createNewFileAndRename(windowUIState: windowUIState) }
            Divider()
            Button(tr(.open)) { appState.openSelectedItem() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(tr(.properties)) { appState.openPropertiesForSelected(windowUIState: windowUIState) }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(tr(.quickLook)) { appState.triggerQuickLookForSelected(windowUIState: windowUIState) }
                .keyboardShortcut(" ", modifiers: [])
                .disabled(appState.selectedURLs.isEmpty)
            Divider()
            Button(tr(.moveToTrash)) { appState.deleteSelected(windowUIState: windowUIState) }
                .disabled(appState.selectedURLs.isEmpty)
        }
    }

    @CommandsBuilder private var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(tr(.undo)) { appState?.undoLastAction() }
                .keyboardShortcut("z", modifiers: .command)
            Button(tr(.redo)) { appState?.redoLastAction() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .pasteboard) {
            // While the rename field or the path bar's text field is active, these keep their
            // shortcut but forward to the system's standard text editing actions instead, so that
            // field's own text gets cut/copied/pasted/selected instead of the selected files.
            let isRenaming = isTextFieldEditingActive ?? false
            cutCommandButton(isRenaming: isRenaming)
            copyCommandButton(isRenaming: isRenaming)
            pasteCommandButton(isRenaming: isRenaming)
            Divider()
            selectAllCommandButton(isRenaming: isRenaming)
            Divider()
            Button(tr(.find)) { appState?.toggleSearching() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    private func cutCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.cut)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            } else {
                appState?.cutSelected()
            }
        }
        .keyboardShortcut("x", modifiers: .command)
        .disabled(!isRenaming && (appState?.selectedURLs.isEmpty ?? true))
    }

    private func copyCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.copy)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            } else {
                appState?.copySelected()
            }
        }
        .keyboardShortcut("c", modifiers: .command)
        .disabled(!isRenaming && (appState?.selectedURLs.isEmpty ?? true))
    }

    private func pasteCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.paste)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            } else {
                appState?.pasteToCurrentDirectory()
            }
        }
        .keyboardShortcut("v", modifiers: .command)
    }

    private func selectAllCommandButton(isRenaming: Bool) -> some View {
        Button(tr(.selectAll)) {
            if isRenaming {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            } else {
                appState?.selectAllItems()
            }
        }
        .keyboardShortcut("a", modifiers: .command)
    }

    /// Everyday, frequently-toggled panels/actions stay here for quick keyboard access. Lower-
    /// frequency display preferences (hidden files, tags, compact density, sidebar sections/mode)
    /// moved into the new `Settings` scene (⌘,) — see `Views/Settings/*.swift` — to declutter the
    /// menu bar per the redesign; those bindings still live on the same `PreferencesStore`, so
    /// toggling them in Settings updates the UI live with zero behavior change.
    @CommandsBuilder private var viewMenuCommands: some Commands {
        CommandGroup(after: .sidebar) {
            sidebarViewMenuItems
        }
    }

    @ViewBuilder private var sidebarViewMenuItems: some View {
        @Bindable var sharedPreferences = sharedPreferences
        Divider()
        Toggle(tr(sharedPreferences.showTerminalDrawer ? .hideTerminal : .showTerminal), isOn: $sharedPreferences.showTerminalDrawer)
            .keyboardShortcut("j", modifiers: .command)
        Toggle(tr(sharedPreferences.showPreviewSidebar ? .hidePreview : .showPreviewSidebar), isOn: $sharedPreferences.showPreviewSidebar)
            .keyboardShortcut("p", modifiers: [.command, .shift])
        Toggle(
            tr(sharedPreferences.showDiskUsageSidebar ? .hideDiskUsageSidebar : .showDiskUsageSidebar),
            isOn: $sharedPreferences.showDiskUsageSidebar)
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Menu(tr(.sidebarMenuTitle)) {
            Toggle(tr(.showFavorites), isOn: $sharedPreferences.showFavorites)
            Toggle(tr(.showPlaces), isOn: $sharedPreferences.showPlaces)
            Toggle(tr(.showRecents), isOn: $sharedPreferences.showRecents)
            Toggle(tr(.showNetworkAndCloud), isOn: $sharedPreferences.showNetworkAndCloud)
            Toggle(tr(.showDirectoryTree), isOn: $sharedPreferences.showDirectoryTree)
            Toggle(tr(.showSidebarSectionTitles), isOn: $sharedPreferences.showSidebarSectionTitles)
            Toggle(tr(.showTags), isOn: $sharedPreferences.showTags)
        }
        Divider()
        Picker(selection: $sharedPreferences.viewMode) {
            Text(tr(.gridView)).tag(ViewMode.grid)
            Text(tr(.listView)).tag(ViewMode.list)
        } label: {
            Label(tr(.viewMode), systemImage: "square.grid.2x2")
        }
        Menu {
            Picker(tr(.sortBy), selection: $sharedPreferences.sortOption) {
                ForEach(SortOption.allCases) { opt in Text(tr(opt.l10nKey)).tag(opt) }
            }
            Divider()
            Toggle(tr(.ascending), isOn: $sharedPreferences.sortAscending)
        } label: {
            Label(tr(.sortBy), systemImage: "arrow.up.arrow.down")
        }
    }

    @ViewBuilder private var goMenuCommands: some View {
        Button(tr(.back)) { appState?.goBack() }
            .keyboardShortcut("[", modifiers: .command)
            .disabled((appState?.navigation.historyBack.isEmpty) ?? true)
        Button(tr(.forward)) { appState?.goForward() }
            .keyboardShortcut("]", modifiers: .command)
            .disabled((appState?.navigation.historyForward.isEmpty) ?? true)
        Button(tr(.enclosingFolder)) { appState?.goUp() }
        Divider()
        Button(tr(.goToFolder)) {
            if let appState, let windowUIState {
                appState.startEditingPath(windowUIState: windowUIState)
            }
        }
        .keyboardShortcut("l", modifiers: .command)
        Button(tr(.connectToServerEllipsis)) { windowUIState?.showConnectToServerSheet = true }
            .keyboardShortcut("k", modifiers: .command)
    }

    @ViewBuilder private var toolsMenuCommands: some View {
        Button(tr(.autoOrganizationEllipsis)) { windowUIState?.showAutoOrganizationSheet = true }
        Button(tr(.findDuplicates)) { windowUIState?.showDuplicateCleanerSheet = true }
        Divider()
        if let appState {
            Menu(tr(.copyPath)) {
                Button(tr(.copyPathAbsolute)) {
                    CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .absolute)
                }
                Button(tr(.copyPathRelative)) {
                    CopyPathService.copy(
                        urls: [appState.navigation.currentURL],
                        variant: .relative,
                        relativeTo: appState.navigation.currentURL.deletingLastPathComponent())
                }
                Button(tr(.copyPathURL)) {
                    CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .fileURL)
                }
                Button(tr(.copyPathTerminal)) {
                    CopyPathService.copy(urls: [appState.navigation.currentURL], variant: .terminalEscaped)
                }
            }
        }
    }

    @CommandsBuilder private var helpMenuCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button(tr(.wilesHelpAndShortcuts)) { windowUIState?.showHelpSheet = true }
                .keyboardShortcut("?", modifiers: .command)
            Button(tr(.feedbackMenuItem)) { windowUIState?.showFeedbackSheet = true }
            Button(tr(.shortcutsCheatsheetTitle)) {
                withAnimation(MotionTokens.snappySpring) {
                    windowUIState?.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
        }
    }
}
