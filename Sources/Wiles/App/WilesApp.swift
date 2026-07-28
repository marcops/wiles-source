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
        WindowGroup("Wiles") {
            MainContentView(appState: appState)
                .sheet(item: $appState.propertiesItem) { item in
                    FilePropertiesSheet(item: item)
                }
                .sheet(isPresented: $appState.showNewFolderSheet) {
                    NewFolderSheet(appState: appState)
                }
                .sheet(isPresented: $appState.showHelpSheet) {
                    HelpSheet(appState: appState)
                }
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
                       let iconImage = NSImage(contentsOf: iconURL) {
                        NSApplication.shared.applicationIconImage = iconImage
                    }
                    for window in NSApplication.shared.windows {
                        window.tabbingMode = .disallowed
                        window.isMovableByWindowBackground = false
                        window.setFrameAutosaveName("WilesMainWindow")
                    }
                    appState.refreshCurrentDirectory()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Folder...") { appState.showNewFolderSheet = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
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
