@testable import Wiles
import Foundation

@MainActor
public struct FilePermissionsTests {
    public static func run() {
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("perms_test.txt")
        try? "test data".write(to: tempFile, atomically: true, encoding: .utf8)

        // POS: getPermissions returns valid POSIXPermissions
        if let perms = FilePermissionsService.getPermissions(for: tempFile) {
            TestReporter.report("Permissions", "POS: getPermissions returns valid octalString", result: !perms.octalString.isEmpty)

            // POS: setPermissions updates file attributes
            var updated = perms
            updated.ownerExecute = true
            try? FilePermissionsService.setPermissions(for: tempFile, permissions: updated)
            let check = FilePermissionsService.getPermissions(for: tempFile)
            TestReporter.report("Permissions", "POS: setPermissions updates ownerExecute", result: check?.ownerExecute == true)
        } else {
            TestReporter.report("Permissions", "POS: getPermissions returns valid octalString", result: false)
        }

        // NEG: non-existent file returns nil
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("missing-\(UUID().uuidString).txt")
        TestReporter.report("Permissions", "NEG: getPermissions for a non-existent file returns nil", result: FilePermissionsService.getPermissions(for: missing) == nil)

        // POS: octalString reflects a known bit pattern (rwxr-xr--  = 0754)
        let perms754 = POSIXPermissions(posixPermissions: 0o754)
        TestReporter.report("Permissions", "POS: octalString renders 0o754 as \"0754\"", result: perms754.octalString == "0754")
        TestReporter.report("Permissions", "POS: init(posixPermissions:) decodes owner rwx correctly for 0o754",
            result: perms754.ownerRead && perms754.ownerWrite && perms754.ownerExecute)
        TestReporter.report("Permissions", "POS: init(posixPermissions:) decodes group r-x correctly for 0o754",
            result: perms754.groupRead && !perms754.groupWrite && perms754.groupExecute)
        TestReporter.report("Permissions", "POS: init(posixPermissions:) decodes others r-- correctly for 0o754",
            result: perms754.othersRead && !perms754.othersWrite && !perms754.othersExecute)

        // POS: octalInt round-trips back to the same bit pattern
        TestReporter.report("Permissions", "POS: octalInt round-trips 0o754 losslessly", result: perms754.octalInt == 0o754)

        try? FileManager.default.removeItem(at: tempFile)
    }
}
