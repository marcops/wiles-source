import Foundation

@MainActor
public final class PermissionTests {
    public static func run() {
        print("\n--- Running PermissionTests ---")
        
        PermissionService.resetInitialPermissionsFlag()
        let key = "wiles_hasRequestedInitialPermissions"
        
        let before = !UserDefaults.standard.bool(forKey: key)
        TestReporter.report("Permission", "Flag initial state is false", result: before)
        
        PermissionService.requestInitialPermissions()
        let afterFirst = UserDefaults.standard.bool(forKey: key)
        TestReporter.report("Permission", "Flag is set to true on first request", result: afterFirst)
        
        PermissionService.requestInitialPermissions()
        let afterSecond = UserDefaults.standard.bool(forKey: key)
        TestReporter.report("Permission", "Flag remains true on subsequent requests", result: afterSecond)
    }
}

