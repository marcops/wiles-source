import Foundation
@testable import Wiles

@MainActor
public struct FilePermissionsTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("perms_test.txt")
        try? "test data".write(to: tempFile, atomically: true, encoding: .utf8)

        // POS: getPermissions returns valid POSIXPermissions
        if let perms = FilePermissionsService.getPermissions(for: tempFile) {
            TestReporter.report("Permissions", "POS: getPermissions returns valid octalString", result: !perms.octalString.isEmpty)

            // POS: setPermissions updates file attributes
            var updated = perms
            updated.ownerExecute = true
            try? FilePermissionsService.setPermissions(for: tempFile, permissions: updated)
            let check = FilePermissionsService.getPermissions(for: tempFile)
            TestReporter.report("Permissions", "POS: setPermissions updates ownerExecute", result: check?.ownerExecute ?? false)
        } else {
            TestReporter.report("Permissions", "POS: getPermissions returns valid octalString", result: false)
        }

        testRecursiveApplyReportsCount()

        // NEG: non-existent file returns nil
        let missing = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("missing-\(UUID().uuidString).txt")
        TestReporter.report(
            "Permissions",
            "NEG: getPermissions for a non-existent file returns nil",
            result: FilePermissionsService.getPermissions(for: missing) == nil)

        // POS: octalString reflects a known bit pattern (rwxr-xr--  = 0754)
        let perms754 = POSIXPermissions(posixPermissions: 0o754)
        TestReporter.report("Permissions", "POS: octalString renders 0o754 as \"0754\"", result: perms754.octalString == "0754")
        TestReporter.report(
            "Permissions",
            "POS: init(posixPermissions:) decodes owner rwx correctly for 0o754",
            result: perms754.ownerRead && perms754.ownerWrite && perms754.ownerExecute)
        TestReporter.report(
            "Permissions",
            "POS: init(posixPermissions:) decodes group r-x correctly for 0o754",
            result: perms754.groupRead && !perms754.groupWrite && perms754.groupExecute)
        TestReporter.report(
            "Permissions",
            "POS: init(posixPermissions:) decodes others r-- correctly for 0o754",
            result: perms754.othersRead && !perms754.othersWrite && !perms754.othersExecute)

        // POS: octalInt round-trips back to the same bit pattern
        TestReporter.report("Permissions", "POS: octalInt round-trips 0o754 losslessly", result: perms754.octalInt == 0o754)

        // L6: setuid/setgid/sticky bits survive a decode → re-encode round-trip and an rwx edit.
        var setuidPerms = POSIXPermissions(posixPermissions: 0o4755)
        TestReporter.report("Permissions", "POS: init preserves the setuid bit", result: setuidPerms.specialBits == 0o4000)
        TestReporter.report("Permissions", "POS: octalInt round-trips 0o4755 (setuid) losslessly", result: setuidPerms.octalInt == 0o4755)
        TestReporter.report("Permissions", "POS: octalString renders 0o4755 as \"4755\"", result: setuidPerms.octalString == "4755")
        setuidPerms.othersWrite = true
        TestReporter.report(
            "Permissions",
            "POS: editing an rwx bit keeps the setuid bit (0o4757)",
            result: setuidPerms.octalInt == 0o4757)

        let stickyPerms = POSIXPermissions(posixPermissions: 0o1777)
        TestReporter.report("Permissions", "POS: octalInt round-trips 0o1777 (sticky) losslessly", result: stickyPerms.octalInt == 0o1777)

        try? FileManager.default.removeItem(at: tempFile)
    }

    /// L12: `setPermissionsRecursively` returns `(applied:errors:)` so the sheet can show a count.
    private static func testRecursiveApplyReportsCount() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("perms_recursive_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("nested"), withIntermediateDirectories: true)
        try? "a".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try? "b".write(to: dir.appendingPathComponent("nested/b.txt"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: dir) }

        let result = FilePermissionsService.setPermissionsRecursively(
            for: dir, permissions: POSIXPermissions(posixPermissions: 0o755))
        TestReporter.report(
            "Permissions",
            "POS: setPermissionsRecursively applies to the folder plus all 3 nested items with no errors",
            result: result.applied == 4 && result.errors.isEmpty)
    }
}
