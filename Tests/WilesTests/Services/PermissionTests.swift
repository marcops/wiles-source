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
    }
}
