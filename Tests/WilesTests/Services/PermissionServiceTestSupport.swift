import Foundation
@testable import Wiles

/// Test-only manipulation of the "Full Disk Access prompt already shown" flag. Lives here, not in
/// `Sources/`, per DEV_RULES.md — production code carries no test-only hooks. Tests use these to
/// drive `PermissionService.requestInitialPermissions`'s already-shown / not-yet-shown branches
/// without touching the real one-shot `NSAlert`.
extension PermissionService {
    static func markFullDiskAccessPromptAsShown() {
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasShownFullDiskAccessPrompt.rawValue)
    }

    static func resetInitialPermissionsFlag() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.hasShownFullDiskAccessPrompt.rawValue)
    }
}
