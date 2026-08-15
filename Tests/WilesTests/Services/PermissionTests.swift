import Foundation
@testable import Wiles

@MainActor
public final class PermissionTests {
    public static func run() {
        print("\n--- Running PermissionTests ---")

        let key = DefaultsKey.hasShownFullDiskAccessPrompt.rawValue
        let priorFlagValue = UserDefaults.standard.object(forKey: key)
        defer {
            if let priorFlagValue {
                UserDefaults.standard.set(priorFlagValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

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

        testFlagPersistenceRoundTrip()
        testHasFullDiskAccessMatchesDirectCheck()
        testRequestInitialPermissionsIsNoOpWhenAlreadyShown()
        testSettingsDeepLinkURLComponents()
        testResetIsIdempotent()
    }

    private static func testFlagPersistenceRoundTrip() {
        let key = DefaultsKey.hasShownFullDiskAccessPrompt.rawValue
        let defaults = UserDefaults.standard
        let priorValue = defaults.object(forKey: key)
        defer {
            if let priorValue {
                defaults.set(priorValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)
        TestReporter.report(
            "Permission",
            "NEG: flag key absent after removeObject reads as false via bool(forKey:)",
            result: defaults.bool(forKey: key) == false)

        PermissionService.markFullDiskAccessPromptAsShown()
        TestReporter.report("Permission", "POS: markFullDiskAccessPromptAsShown sets the UserDefaults flag to true", result: defaults.bool(forKey: key) == true)

        PermissionService.resetInitialPermissionsFlag()
        TestReporter.report(
            "Permission",
            "POS: resetInitialPermissionsFlag removes the flag key entirely (object(forKey:) is nil)",
            result: defaults.object(forKey: key) == nil)
    }

    private static func testHasFullDiskAccessMatchesDirectCheck() {
        let path = "/Library/Application Support/com.apple.TCC/TCC.db"
        let expected = FileManager.default.isReadableFile(atPath: path)
        let actual = PermissionService.hasFullDiskAccess()
        TestReporter.report("Permission", "POS: hasFullDiskAccess matches a direct FileManager.isReadableFile check on TCC.db", result: actual == expected)
    }

    private static func testRequestInitialPermissionsIsNoOpWhenAlreadyShown() {
        let key = DefaultsKey.hasShownFullDiskAccessPrompt.rawValue
        let defaults = UserDefaults.standard
        let priorValue = defaults.object(forKey: key)
        defer {
            if let priorValue {
                defaults.set(priorValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        PermissionService.markFullDiskAccessPromptAsShown()
        let before = defaults.bool(forKey: key)
        PermissionService.requestInitialPermissions(language: .system)
        let after = defaults.bool(forKey: key)
        TestReporter.report(
            "Permission",
            "POS: requestInitialPermissions leaves the flag unchanged (still true) when already shown",
            result: before == true && after == true)
    }

    private static func testSettingsDeepLinkURLComponents() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
        TestReporter.report(
            "Permission",
            "POS: settings deep link scheme parses as x-apple.systempreferences",
            result: url?.scheme == "x-apple.systempreferences")
        TestReporter.report("Permission", "POS: settings deep link query parses as Privacy_AllFiles", result: url?.query == "Privacy_AllFiles")
        TestReporter.report("Permission", "NEG: settings deep link scheme is not https", result: url?.scheme != "https")
    }

    private static func testResetIsIdempotent() {
        let key = DefaultsKey.hasShownFullDiskAccessPrompt.rawValue
        let defaults = UserDefaults.standard
        let priorValue = defaults.object(forKey: key)
        defer {
            if let priorValue {
                defaults.set(priorValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        PermissionService.resetInitialPermissionsFlag()
        PermissionService.resetInitialPermissionsFlag()
        TestReporter.report(
            "Permission",
            "NEG: calling resetInitialPermissionsFlag twice on an already-absent key stays absent without crashing",
            result: defaults.object(forKey: key) == nil)
    }
}
