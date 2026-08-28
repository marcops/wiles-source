import AppKit
import Foundation

public struct PermissionService: Sendable {
    /// Opens macOS System Settings directly to Full Disk Access preference panel
    /// allowing the user to grant 1 single permission for all folders.
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private static let hasShownFullDiskAccessPromptKey = DefaultsKey.hasShownFullDiskAccessPrompt.rawValue

    /// Checks Full Disk Access by testing readability of TCC.db, the standard heuristic for this permission.
    public static func hasFullDiskAccess() -> Bool {
        FileManager.default.isReadableFile(atPath: "/Library/Application Support/com.apple.TCC/TCC.db")
    }

    /// Touches each protected folder once so macOS's native per-folder consent dialogs fire (if not
    /// already granted) and, critically, so TCC registers Wiles as a requester — without this, Wiles
    /// never appears as a selectable entry in System Settings' Full Disk Access list at all.
    private static func probeProtectedFolders() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        // A readability check is enough to trip TCC and register Wiles as a requester; enumerating
        // contents (the old approach) added a synchronous, potentially slow directory read per folder.
        for name in ["Desktop", "Documents", "Downloads", "Music", "Movies", "Pictures"] {
            _ = FileManager.default.isReadableFile(atPath: home.appendingPathComponent(name).path)
        }
    }

    /// Shows a single consolidated Full Disk Access prompt on first launch instead of letting
    /// macOS ask separately for every protected folder (Desktop, Documents, Downloads...) as
    /// the user happens to navigate into each one. Only ever shown once, regardless of the choice made.
    /// Probes every launch (not just the first) so these folders' TCC state is always settled on
    /// the main thread before any background scan (e.g. the sidebar's directory tree) touches them.
    @MainActor
    public static func requestInitialPermissions(language: AppLanguage) {
        probeProtectedFolders()
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasShownFullDiskAccessPromptKey) else { return }
        defaults.set(true, forKey: hasShownFullDiskAccessPromptKey)
        guard !hasFullDiskAccess() else { return }

        let alert = NSAlert()
        alert.messageText = L10n.string(.fullDiskAccessPromptTitle, lang: language)
        alert.informativeText = L10n.string(.fullDiskAccessPromptMessage, lang: language)
        alert.addButton(withTitle: L10n.string(.openSystemSettings, lang: language))
        alert.addButton(withTitle: L10n.string(.notNow, lang: language))
        if alert.runModal() == .alertFirstButtonReturn {
            openFullDiskAccessSettings()
        }
    }

    public static func resetInitialPermissionsFlag() {
        UserDefaults.standard.removeObject(forKey: hasShownFullDiskAccessPromptKey)
    }

    /// Test-only helper so automated tests can exercise the no-op path without triggering the real alert.
    public static func markFullDiskAccessPromptAsShown() {
        UserDefaults.standard.set(true, forKey: hasShownFullDiskAccessPromptKey)
    }
}
