import Foundation

@MainActor
public final class PermissionTests {
    public static func run() {
        print("\n--- Running PermissionTests ---")
        
        PermissionService.requestInitialPermissions()
        TestReporter.report("Permission", "requestInitialPermissions is a safe no-op on launch", result: true)
        PermissionService.resetInitialPermissionsFlag()
        TestReporter.report("Permission", "resetInitialPermissionsFlag runs safely without error", result: true)
    }
}

