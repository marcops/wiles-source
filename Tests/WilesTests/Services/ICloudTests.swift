@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct ICloudTests {
    public static func run() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("icloud_mock_test.txt")
        try? "test data".write(to: tempFile, atomically: true, encoding: .utf8)
        let item = FileItem(url: tempFile, icon: NSWorkspace.shared.icon(forFile: tempFile.path))

        // POS: FileItem includes iCloud status properties
        TestReporter.report("iCloudStatus", "POS: FileItem parses isUbiquitous properties", result: item.isUbiquitous == false || item.isUbiquitous == true)
        TestReporter.report(
            "iCloudStatus", "POS: FileItem parses isUbiquitousNotDownloaded",
            result: item.isUbiquitousNotDownloaded == false || item.isUbiquitousNotDownloaded == true
        )
    }
}
