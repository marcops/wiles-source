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
                .preferredColorScheme(appState.appAppearance.colorScheme)
                .sheet(item: $appState.propertiesItem) { item in
                    FilePropertiesSheet(item: item, appState: appState)
                }
                .sheet(isPresented: $appState.showNewFolderSheet) {
                    NewFolderSheet(appState: appState)
                }
                .sheet(isPresented: $appState.showHelpSheet) {
                    HelpSheet(appState: appState)
                }
                .sheet(isPresented: $appState.showAboutSheet) {
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
                    if !CommandLine.arguments.contains("--ui-testing") && !CommandLine.arguments.contains("--test") && !CommandLine.arguments.contains("--run-tests") {
                        PermissionService.requestInitialPermissions(language: appState.appLanguage)
                    }
                    if CommandLine.arguments.contains("--test") || CommandLine.arguments.contains("--run-tests") {
                        Task {
                            await AutomatedTestService.runAllTests()
                        }
                    } else {
                        appState.refreshCurrentDirectory()
                        AutoOrganizationService.shared.startMonitoring()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            appMenuCommands
            fileMenuCommands
            editMenuCommands
            viewMenuCommands
            CommandMenu("Go") { goMenuCommands }
            CommandMenu("Tools") { toolsMenuCommands }
            helpMenuCommands
        }
    }

    @CommandsBuilder
    private var appMenuCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(appState.tr(.aboutWiles)) { appState.showAboutSheet = true }
            Divider()
            Picker(appState.tr(.language), selection: $appState.appLanguage) {
                ForEach(AppLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
            }
            Picker("Theme", selection: $appState.appAppearance) {
                ForEach(AppAppearance.allCases) { appearance in Text(appearance.rawValue).tag(appearance) }
            }
            Picker("Shortcut Mode", selection: $appState.navigationMode) {
                ForEach(NavigationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
            }
            Menu(appState.tr(.translucentLevel)) {
                Menu(appState.tr(.sidebarTranslucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button(action: { appState.sidebarTranslucentLevel = level }) {
                            HStack {
                                Text("\(level)%")
                                if appState.sidebarTranslucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Menu(appState.tr(.contentTranslucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button(action: { appState.contentTranslucentLevel = level }) {
                            HStack {
                                Text("\(level)%")
                                if appState.contentTranslucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
        }
    }

    @CommandsBuilder
    private var fileMenuCommands: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Folder...") { appState.showNewFolderSheet = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Open") { appState.openSelectedItem() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button(appState.tr(.properties)) { appState.openPropertiesForSelected() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button("Quick Look") { appState.triggerQuickLookForSelected() }
                .keyboardShortcut(" ", modifiers: [])
                .disabled(appState.selectedURLs.isEmpty)
            Divider()
            Button("Move to Trash") { appState.deleteSelected() }
                .disabled(appState.selectedURLs.isEmpty)
        }
    }

    @CommandsBuilder
    private var editMenuCommands: some Commands {
        CommandGroup(after: .undoRedo) {
            Button("Undo") { appState.undoLastAction() }
                .keyboardShortcut("z", modifiers: .command)
            Button("Redo") { appState.redoLastAction() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") { appState.cutSelected() }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button("Copy") { appState.copySelected() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(appState.selectedURLs.isEmpty)
            Button("Paste") { appState.pasteToCurrentDirectory() }
                .keyboardShortcut("v", modifiers: .command)
            Divider()
            Button("Select All") { appState.selectAllItems() }
                .keyboardShortcut("a", modifiers: .command)
            Divider()
            Button("Find") { appState.toggleSearching() }
                .keyboardShortcut("f", modifiers: .command)
        }
    }

    @CommandsBuilder
    private var viewMenuCommands: some Commands {
        CommandGroup(after: .sidebar) {
            Divider()
            Button(appState.tr(.shortcutsCheatsheetTitle)) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    appState.showShortcutsHUD.toggle()
                }
            }
            .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
            Toggle(appState.showTerminalDrawer ? "Hide Terminal" : "Show Terminal", isOn: $appState.showTerminalDrawer)
                .keyboardShortcut("j", modifiers: .command)
            Toggle(appState.showPreviewSidebar ? "Hide Preview" : appState.tr(.showPreviewSidebar), isOn: $appState.showPreviewSidebar)
                .keyboardShortcut("p", modifiers: [.command, .shift])
            Divider()
            Toggle(appState.navigationMode == .gnome ? "Show Hidden Files (Ctrl+H)" : "Show Hidden Files (Cmd+Shift+.)", isOn: $appState.showHiddenFiles)
                .onChange(of: appState.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
            Toggle(appState.tr(.showTags), isOn: $appState.showTags)
            Toggle(appState.tr(.compactDensity), isOn: $appState.isCompactMode)
            Divider()
            Toggle(appState.tr(.showFavorites), isOn: $appState.showFavorites)
            Toggle(appState.tr(.showPlaces), isOn: $appState.showPlaces)
            Toggle(appState.tr(.showMacSection), isOn: $appState.showMacSection)
            Toggle(appState.tr(.showRecents), isOn: $appState.showRecents)
            Toggle(appState.tr(.showNetworkAndCloud), isOn: $appState.showNetworkAndCloud)
            Divider()
            Picker(appState.tr(.viewMode), selection: $appState.viewMode) {
                Text(appState.tr(.gridView)).tag(ViewMode.grid)
                Text(appState.tr(.listView)).tag(ViewMode.list)
                Text(appState.tr(.columnView)).tag(ViewMode.column)
            }
            Picker(appState.tr(.sidebarMode), selection: $appState.sidebarMode) {
                ForEach(SidebarMode.allCases) { mode in Text(appState.tr(mode.menuL10nKey)).tag(mode) }
            }
            Menu(appState.tr(.sortBy)) {
                Picker(appState.tr(.sortBy), selection: $appState.sortOption) {
                    ForEach(SortOption.allCases) { opt in Text(opt.rawValue).tag(opt) }
                }
                .onChange(of: appState.sortOption) { _, _ in appState.refreshCurrentDirectory() }
                Divider()
                Toggle(appState.tr(.ascending), isOn: $appState.sortAscending)
                    .onChange(of: appState.sortAscending) { _, _ in appState.refreshCurrentDirectory() }
            }
        }
    }

    @ViewBuilder
    private var goMenuCommands: some View {
        Button("Back") { appState.goBack() }
            .keyboardShortcut("[", modifiers: .command)
            .disabled(appState.historyBack.isEmpty)
        Button("Forward") { appState.goForward() }
            .keyboardShortcut("]", modifiers: .command)
            .disabled(appState.historyForward.isEmpty)
        Button("Enclosing Folder") { appState.goUp() }
        Divider()
        Button("Go to Folder...") { appState.startEditingPath() }
            .keyboardShortcut("l", modifiers: .command)
        Button("Connect to Server...") { appState.showConnectToServerSheet = true }
            .keyboardShortcut("k", modifiers: .command)
    }

    @ViewBuilder
    private var toolsMenuCommands: some View {
        Button(appState.tr(.actDiskVisualizer) + "...") { appState.showDiskUsageSheet = true }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        Button(appState.tr(.autoOrganization) + "...") { appState.showAutoOrganizationSheet = true }
        Divider()
        Button(appState.tr(.copyPath)) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(appState.currentURL.path, forType: .string)
        }
        Divider()
        Button(appState.tr(.shortcutsCheatsheetTitle)) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                appState.showShortcutsHUD.toggle()
            }
        }
        .keyboardShortcut(KeyboardShortcut("/", modifiers: .command, localization: .custom))
    }

    @CommandsBuilder
    private var helpMenuCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Wiles Help & Shortcuts") { appState.showHelpSheet = true }
                .keyboardShortcut("?", modifiers: .command)
        }
    }
}
