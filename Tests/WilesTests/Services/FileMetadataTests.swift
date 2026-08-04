@testable import Wiles
import Foundation

@MainActor
public struct FileMetadataTests {
    public static func run() async {
        await testFetchPropertiesForRealFile()
        await testFetchPropertiesForNonExistentFileDoesNotCrash()
    }

    private static func testFetchPropertiesForRealFile() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("metadata_test.txt")
        try? "hello".write(to: file, atomically: true, encoding: .utf8)

        let props = await FileMetadataService.shared.fetchProperties(for: file)
        report("FileMetadata", "POS: owner name is resolved for a real file", result: props.ownerName != nil && !(props.ownerName ?? "").isEmpty)
        report("FileMetadata", "POS: POSIX permissions string has the expected rwx-style length", result: (props.posixPermissions ?? "").count == 9)
    }

    private static func testFetchPropertiesForNonExistentFileDoesNotCrash() async {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("does-not-exist-\(UUID().uuidString).txt")
        let props = await FileMetadataService.shared.fetchProperties(for: missing)
        report("FileMetadata", "NEG: non-existent file returns nil owner/permissions instead of crashing", result: props.ownerName == nil && props.posixPermissions == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
