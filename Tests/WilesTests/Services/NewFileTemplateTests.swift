import Foundation
@testable import Wiles

/// `NewFileTemplateService` was collapsed (finding SL-123) from a speculative `FileTemplate` /
/// `fileName` / `language` API with a single always-`""`/`.text` caller down to one method that
/// makes a blank text file the user then renames inline.
@MainActor
public struct NewFileTemplateTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let first = try? NewFileTemplateService.createTextFile(in: tempDir)
        let firstOK = first.map {
            FileManager.default.fileExists(atPath: $0.path)
                && $0.lastPathComponent == NewFileTemplateService.defaultFileName
                && (try? Data(contentsOf: $0))?.isEmpty == true
        } ?? false
        TestReporter.report(
            "NewFileTemplate", "POS: createTextFile writes an empty file named the default placeholder", result: firstOK)

        let second = try? NewFileTemplateService.createTextFile(in: tempDir)
        let third = try? NewFileTemplateService.createTextFile(in: tempDir)
        let names = [first, second, third].compactMap { $0?.lastPathComponent }
        TestReporter.report(
            "NewFileTemplate",
            "POS: createTextFile \" 2\"/\" 3\"-suffixes instead of overwriting an existing file",
            result: names == ["Document.txt", "Document 2.txt", "Document 3.txt"])
    }
}
