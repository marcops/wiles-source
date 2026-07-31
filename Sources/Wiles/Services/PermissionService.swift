import Foundation
import AppKit

public struct PermissionService: Sendable {
    /// Opens macOS System Settings directly to Full Disk Access preference panel
    /// allowing the user to grant 1 single permission for all folders.
    public static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Legacy initial permissions call - now no-op to ensure zero permission dialogs on launch.
    /// Permissions are requested naturally when the user clicks or navigates to a folder.
    public static func requestInitialPermissions() {
        // Intentionally no-op to prevent annoying permission popups on startup.
    }
    
    public static func resetInitialPermissionsFlag() {
        // No-op
    }
}


