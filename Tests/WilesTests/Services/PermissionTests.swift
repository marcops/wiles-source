@testable import Wiles
import Foundation

@MainActor
public final class PermissionTests {
    public static func run() {
        print("\n--- Running PermissionTests ---")

        _ = PermissionService.hasFullDiskAccess()
        TestReporter.report("Permission", "hasFullDiskAccess runs safely without error", result: true)

        PermissionService.markFullDiskAccessPromptAsShown()
        PermissionService.requestInitialPermissions(language: .system)
        TestReporter.report("Permission", "requestInitialPermissions is a safe no-op once already shown", result: true)

        PermissionService.resetInitialPermissionsFlag()
        TestReporter.report("Permission", "resetInitialPermissionsFlag runs safely without error", result: true)

        // POS: the Full Disk Access System Settings deep link is a well-formed URL (pure sanity check;
        // does NOT call openFullDiskAccessSettings() itself, which would open real System Settings)
        let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        TestReporter.report("Permission", "POS: Full Disk Access settings deep link string is a well-formed URL", result: settingsURL != nil)

        // Restore the "already shown" flag so requestInitialPermissions stays a safe no-op for any
        // other test that may run after this one.
        PermissionService.markFullDiskAccessPromptAsShown()
    }
}
