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
                    PermissionService.requestInitialPermissions()
                    if CommandLine.arguments.contains("--test") || CommandLine.arguments.contains("--run-tests") {
                        Task {
                            await AutomatedTestSuite.runAllTests()
                        }
                    } else {
                        appState.refreshCurrentDirectory()
                        AutoOrganizationService.shared.startMonitoring()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(appState.tr(.aboutWiles)) {
                    appState.showAboutSheet = true
                }
                Divider()
                Menu(appState.tr(.translucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button(action: { appState.translucentLevel = level }) {
                            HStack {
                                Text("\(level)%")
                                if appState.translucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
            CommandGroup(after: .newItem) {
                Button("New Folder...") { appState.showNewFolderSheet = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .sidebar) {
                Menu(appState.tr(.translucentLevel)) {
                    ForEach([0, 20, 40, 50, 60, 80, 100], id: \.self) { level in
                        Button(action: { appState.translucentLevel = level }) {
                            HStack {
                                Text("\(level)%")
                                if appState.translucentLevel == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Toggle(appState.showFooter ? "Hide Status Bar" : "Show Status Bar", isOn: $appState.showFooter)
                    .keyboardShortcut("/", modifiers: .command)
                Toggle(appState.showTerminalDrawer ? "Hide Terminal" : "Show Terminal", isOn: $appState.showTerminalDrawer)
                    .keyboardShortcut("j", modifiers: .command)
                Toggle(appState.showPreviewSidebar ? "Hide Preview" : appState.tr(.showPreviewSidebar), isOn: $appState.showPreviewSidebar)
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                Toggle(appState.navigationMode == .gnome ? "Show Hidden Files (Ctrl+H)" : "Show Hidden Files (Cmd+Shift+.)", isOn: $appState.showHiddenFiles)
                    .onChange(of: appState.showHiddenFiles) { _, _ in appState.refreshCurrentDirectory() }
                Toggle(appState.tr(.showTags), isOn: $appState.showTags)
                Divider()
                Toggle("Show Favorites", isOn: $appState.showFavorites)
                Toggle("Show MAC Section", isOn: $appState.showMacSection)
                if appState.showMacSection {
                    Toggle("Show Recents", isOn: $appState.showRecents)
                }
                Toggle("Show Network & Cloud", isOn: $appState.showNetworkAndCloud)
                Divider()
                Button("Auto-Organization Rules...") {
                    appState.showAutoOrganizationSheet = true
                }
                Divider()
                Picker("View Mode", selection: $appState.viewMode) {
                    Text("Grid View").tag(ViewMode.grid)
                    Text("List View").tag(ViewMode.list)
                }
                Picker("Sidebar Mode", selection: $appState.sidebarMode) {
                    ForEach(SidebarMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
                Picker("Shortcut Mode", selection: $appState.navigationMode) {
                    ForEach(NavigationMode.allCases) { mode in Text(mode.rawValue).tag(mode) }
                }
            }
            CommandGroup(replacing: .help) {
                Button("Wiles Help & Shortcuts") {
                    appState.showHelpSheet = true
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}
