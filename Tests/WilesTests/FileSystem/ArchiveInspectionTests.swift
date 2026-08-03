@testable import Wiles
import Foundation

@MainActor
public struct ArchiveInspectionTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileToZip = tempDir.appendingPathComponent("inspect_test_file.txt")
        try? "test data for zip".write(to: fileToZip, atomically: true, encoding: .utf8)

        let zipURL = tempDir.appendingPathComponent("inspect_test_file.zip")
        try? ZipArchiveService.compressToZIP(urls: [fileToZip], in: tempDir)

        let entries = ArchiveInspectionService.listEntries(in: zipURL)
        TestReporter.report("ArchiveInspection", "POS: listEntries lists files in zip", result: entries.contains(where: { $0.name.contains("inspect_test_file.txt") }))
    }
}
