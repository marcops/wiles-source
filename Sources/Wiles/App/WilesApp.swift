import SwiftUI
import AppKit

@main
struct WilesApp: App {
    @State private var appState = AppState()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup(AppConstants.appName) {
            MainContentView(appState: appState)
                .preferredColorScheme(appState.preferences.appAppearance.colorScheme)
                .sheet(item: $appState.propertiesItem) { item in
                    FilePropertiesSheet(item: item, appState: appState)
                }
                .sheet(isPresented: $appState.showNewFolderSheet) {
                    NewFolderSheet(appState: appState)
                }
                .sheet(isPresented: $appState.modal.showHelpSheet) {
                    HelpSheet(appState: appState)
                }
                .sheet(isPresented: $appState.modal.showAboutSheet) {
                    AboutSheet(appState: appState)
                }
                .sheet(isPresented: $appState.showAutoOrganizationSheet) {
                    AutoOrganizationSheet(appState: appState)
                }
                .sheet(isPresented: $appState.showHttpShareSheet) {
                    if let url = appState.httpShareFolderURL {
                        HttpShareSheet(appState: appState, folderURL: url)
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
                    for window in NSApplication.shared.windows {
                        window.tabbingMode = .disallowed
                        window.isMovableByWindowBackground = false
                        window.setFrameAutosaveName("WilesMainWindow")
                    }
                    if !CommandLine.arguments.contains("--ui-testing") {
                        PermissionService.requestInitialPermissions(language: appState.preferences.appLanguage)
                    }
                    appState.refreshCurrentDirectory()
                    AutoOrganizationService.shared.startMonitoring()
                }
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

    @CommandsBuilder private var appMenuCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(appState.tr(.aboutWiles)) { appState.modal.showAboutSheet = true }
            Divider()
            Picker(appState.tr(.language), selection: $appState.preferences.appLanguage) {
                ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
            }
            Picker("Theme", selection: $appState.preferences.appAppearance) {
                ForEach(AppAppearance.allCases) { appearance in Text(appearance.rawValue).tag(appearance) }
            }
            Picker("Shortcut Mode", selection: $appState.navigationMode) {
                ForEach(NavigationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            Menu(appState.tr(.translucentLevel)) {
                Menu(appState.tr(.sidebarTranslucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button { appState.preferences.sidebarTranslucentLevel = level } label: {
                            HStack {
                                Text("\(level)%")
                                if appState.preferences.sidebarTranslucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Menu(appState.tr(.contentTranslucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button { appState.preferences.contentTranslucentLevel = level } label: {
                            HStack {
                                Text("\(level)%")
                                if appState.preferences.contentTranslucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
        }
    }

    @CommandsBuilder private var fileMenuCommands: some Commands {
        CommandGroup(after: .newItem) {
            Button(appState.tr(.newFolder)) { appState.showNewFolderSheet = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button(appState.tr(.open)) { appState.openSelectedItem() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(appState.tr(.properties)) { appState.openPropertiesForSelected() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(appState.tr(.quickLook)) { appState.triggerQuickLookForSelected() }
                .keyboardShortcut(" ", modifiers: [])
                .disabled(appState.selectedURLs.isEmpty)
            Divider()
            Button(appState.tr(.moveToTrash)) { appState.deleteSelected() }
                .disabled(appState.selectedURLs.isEmpty)
        }
    }

    @CommandsBuilder private var editMenuCommands: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(appState.tr(.undo)) { appState.undoLastAction() }
                .keyboardShortcut("z", modifiers: .command)
            Button(appState.tr(.redo)) { appState.redoLastAction() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .pasteboard) {
            Button(appState.tr(.cut)) { appState.cutSelected() }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(appState.tr(.copy)) { appState.copySelected() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(appState.tr(.paste)) { appState.pasteToCurrentDirectory() }
                .keyboardShortcut("v", modifiers: .command)
            Divider()
            Button(appState.tr(.selectAll)) { appState.selectAllItems() }
                .keyboardShortcut("a", modifiers: .command)
            Divider()
            Button(appState.tr(.find)) { appState.toggleSearching() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    @CommandsBuilder private var viewMenuCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button(appState.tr(.shortcutsCheatsheetTitle)) {
                withAnimation(MotionTokens.snappySpring) {
                    appState.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
            Toggle(appState.preferences.showTerminalDrawer ? "Hide Terminal" : "Show Terminal", isOn: $appState.preferences.showTerminalDrawer)
                .keyboardShortcut("j", modifiers: .command)
            Toggle(appState.preferences.showPreviewSidebar ? "Hide Preview" : appState.tr(.showPreviewSidebar), isOn: $appState.preferences.showPreviewSidebar)
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Toggle(appState.navigationMode == .gnome ? "Show Hidden Files (Ctrl+H)" : "Show Hidden Files (Cmd+Shift+.)", isOn: $appState.preferences.showHiddenFiles)
                .onChange(of: appState.preferences.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
            Toggle(appState.tr(.showTags), isOn: $appState.preferences.showTags)
            Toggle(appState.tr(.compactDensity), isOn: $appState.isCompactMode)
            Divider()
            Toggle(appState.tr(.showFavorites), isOn: $appState.preferences.showFavorites)
            Toggle(appState.tr(.showPlaces), isOn: $appState.preferences.showPlaces)
            Toggle(appState.tr(.showRecents), isOn: $appState.preferences.showRecents)
            Toggle(appState.tr(.showNetworkAndCloud), isOn: $appState.preferences.showNetworkAndCloud)
            Toggle(appState.tr(.showSidebarSectionTitles), isOn: $appState.preferences.showSidebarSectionTitles)
            Divider()
            Picker(appState.tr(.viewMode), selection: $appState.preferences.viewMode) {
                Text(appState.tr(.gridView)).tag(ViewMode.grid)
                Text(appState.tr(.listView)).tag(ViewMode.list)
                Text(appState.tr(.columnView)).tag(ViewMode.column)
            }
            Picker(appState.tr(.sidebarMode), selection: $appState.preferences.sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in Text(appState.tr(mode.menuL10nKey)).tag(mode) }
            }
            Menu(appState.tr(.sortBy)) {
                Picker(appState.tr(.sortBy), selection: $appState.preferences.sortOption) {
                    ForEach(SortOption.allCases) { opt in Text(opt.rawValue).tag(opt) }
                }
                .onChange(of: appState.preferences.sortOption) { _, _ in appState.refreshCurrentDirectory() }
                Divider()
                Toggle(appState.tr(.ascending), isOn: $appState.preferences.sortAscending)
                    .onChange(of: appState.preferences.sortAscending) { _, _ in appState.refreshCurrentDirectory() }
            }
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
        Button(appState.tr(.goToFolder)) { appState.startEditingPath() }
            .keyboardShortcut("l", modifiers: .command)
        Button(appState.tr(.connectToServer) + "...") { appState.showConnectToServerSheet = true }
            .keyboardShortcut("k", modifiers: .command)
    }

    @ViewBuilder private var toolsMenuCommands: some View {
        Button(appState.tr(.actDiskVisualizer) + "...") { appState.showDiskUsageSheet = true }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Button(appState.tr(.autoOrganization) + "...") { appState.showAutoOrganizationSheet = true }
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
        Divider()
        Button(appState.tr(.shortcutsCheatsheetTitle)) {
            withAnimation(MotionTokens.snappySpring) {
                appState.showShortcutsHUD.toggle()
            }
        }
        .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
    }

    @CommandsBuilder private var helpMenuCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button(appState.tr(.wilesHelpAndShortcuts)) { appState.modal.showHelpSheet = true }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}
