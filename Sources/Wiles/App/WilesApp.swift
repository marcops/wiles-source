import AppKit
import GitBeacon
import SwiftUI

@main
struct WilesApp: App {
    @State private var sharedPreferences = PreferencesStore()
    @State private var sharedTransient = TransientStore()

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

        // App-global work, run once here — `onAppear` re-runs per window (e.g. Cmd+N).
        if !CommandLine.arguments.contains("--ui-testing") {
            PermissionService.requestInitialPermissions(language: sharedPreferences.appLanguage)
        }
        AutoOrganizationService.shared.startMonitoring()
        Task {
            await GitBeacon.processPendingReports()
        }
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
            AppMenuCommands(sharedPreferences: sharedPreferences)
            FileMenuCommands(sharedPreferences: sharedPreferences)
            EditMenuCommands(sharedPreferences: sharedPreferences)
            ViewMenuCommands(sharedPreferences: sharedPreferences)
            GoMenuCommands(sharedPreferences: sharedPreferences)
            ToolsMenuCommands(sharedPreferences: sharedPreferences)
            HelpMenuCommands(sharedPreferences: sharedPreferences)
        }
    }

    private var mainWindowContent: some View {
        MainContentView(sharedPreferences: sharedPreferences, sharedTransient: sharedTransient)
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
            }
    }
}
