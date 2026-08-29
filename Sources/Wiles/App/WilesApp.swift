import AppKit
import GitBeacon
import SwiftUI

@main
struct WilesApp: App {
    @State private var sharedPreferences = PreferencesStore()
    @State private var sharedTransient = TransientStore()

    /// Only the cheap, must-run-before-any-window setup lives in `init()`. The crash handler is
    /// installed here (not deferred) so a crash during the first frame is still captured; anything
    /// heavier — the Full Disk Access prompt, auto-organization monitoring, pending-report upload,
    /// the app icon load — runs once from `.task` after the first window renders, keeping it off
    /// the synchronous launch path (see SWIFT_LANG_RULES.md "SwiftUI init() side effects").
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
        switch sharedPreferences.appearance.appAppearance {
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
            .task { await performLaunchSetupOnce() }
            .onAppear { configureNewWindows() }
    }

    /// App-global launch work, guarded so it runs exactly once no matter how many windows open
    /// (Cmd+N re-fires `.task`).
    @MainActor private static var didRunLaunchSetup = false

    @MainActor
    private func performLaunchSetupOnce() async {
        guard !Self.didRunLaunchSetup else { return }
        Self.didRunLaunchSetup = true

        setApplicationIcon()
        if !CommandLine.arguments.contains("--ui-testing") {
            PermissionService.requestInitialPermissions(language: sharedPreferences.appearance.appLanguage)
        }
        AutoOrganizationService.shared.startMonitoring()
        await GitBeacon.processPendingReports()
    }

    private func setApplicationIcon() {
        let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png") ??
            Bundle.main.resourceURL?.appendingPathComponent("Wiles_Wiles.bundle/AppIcon.png") ??
            Bundle.main.bundleURL.appendingPathComponent("Wiles_Wiles.bundle/AppIcon.png")
        if let iconImage = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = iconImage
        }
    }

    /// Per-window chrome, applied only to windows not yet configured (identified by an empty frame
    /// autosave name). Each window gets its own autosave name so multiple windows don't all compete
    /// for one saved frame and stack on top of each other.
    private func configureNewWindows() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        for window in NSApplication.shared.windows where window.frameAutosaveName.isEmpty {
            window.tabbingMode = .disallowed
            window.isMovableByWindowBackground = false
            // `isRestorable = false` keeps each launch starting clean instead of macOS silently
            // restoring however many windows were open at last quit.
            window.isRestorable = false
            window.setFrameAutosaveName("WilesMainWindow-\(Self.nextWindowFrameIndex)")
            Self.nextWindowFrameIndex += 1
        }
    }

    @MainActor private static var nextWindowFrameIndex = 0
}
