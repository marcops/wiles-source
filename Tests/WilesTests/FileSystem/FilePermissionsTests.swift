@testable import Wiles
import Foundation

@MainActor
public struct FilePermissionsTests {
    public static func run() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("perms_test.txt")
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
    }
}
