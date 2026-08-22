import Foundation
@testable import Wiles

@MainActor
public struct NewFileTemplateTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Positive: Create Markdown Template
        let mdURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "README.md", template: .markdown)
        let mdPos = mdURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report("NewFileTemplate", "POS: createTemplateFile (.markdown)", result: mdPos)

        // Positive: Create Swift Template
        let swiftURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "Main.swift", template: .swift)
        let swiftPos = swiftURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report("NewFileTemplate", "POS: createTemplateFile (.swift)", result: swiftPos)

        // Negative: Empty file name uses default file name
        let defaultURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "   ", template: .json)
        let defaultPos = defaultURL?.lastPathComponent == FileTemplate.json.defaultFileName
        TestReporter.report("NewFileTemplate", "NEG: Empty file name falls back to template default name", result: defaultPos)

        testFileTemplateIDMatchesRawValue()
        testCreateTemplateFileWithoutExtensionAppendsTemplateExtension(tempDir: tempDir)
        testCreateTemplateFileGeneratesUniqueNameWhenFileAlreadyExists(tempDir: tempDir)

        try? FileManager.default.removeItem(at: tempDir)
    }

    // POS: FileTemplate's Identifiable `id` mirrors its rawValue for every case
    private static func testFileTemplateIDMatchesRawValue() {
        let allMatch = FileTemplate.allCases.allSatisfy { $0.id == $0.rawValue }
        TestReporter.report("NewFileTemplate", "POS: FileTemplate.id matches rawValue for every case", result: allMatch)
    }

    // POS: a file name with no extension at all gets the template's extension appended
    // (covers the `!targetURL.pathExtension.isEmpty == false` branch, which is true when there's no extension)
    private static func testCreateTemplateFileWithoutExtensionAppendsTemplateExtension(tempDir: URL) {
        let url = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "NoExtensionName", template: .python)
        let matches = url?.pathExtension == FileTemplate.python.rawValue && url?.lastPathComponent == "NoExtensionName.py"
        TestReporter.report("NewFileTemplate", "POS: createTemplateFile appends template extension when file name has none", result: matches)
    }

    // POS: creating a file with the same name twice (then a third time) exercises generateUniqueURL's
    // repeat-while loop, producing "Name 2.ext" then "Name 3.ext" instead of overwriting the original.
    private static func testCreateTemplateFileGeneratesUniqueNameWhenFileAlreadyExists(tempDir: URL) {
        let first = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "Duplicate.txt", template: .text)
        let second = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "Duplicate.txt", template: .text)
        let third = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "Duplicate.txt", template: .text)

        let names = [first, second, third].compactMap { $0?.lastPathComponent }
        let expected = ["Duplicate.txt", "Duplicate 2.txt", "Duplicate 3.txt"]
        TestReporter.report(
            "NewFileTemplate",
            "POS: createTemplateFile generates unique incrementing names when the file already exists",
            result: names == expected)
    }

    // NOTE ON COVERAGE GAP: generateUniqueURL's `ext.isEmpty ? "\(baseName) \(counter)" : ...` true
    // branch (no-extension case) is unreachable via any public call path — createTemplateFile always
    // appends the template's extension first when one is missing, and no FileTemplate case has an
    // empty rawValue, so `ext` is never empty by the time generateUniqueURL runs. The function is
    // `private`, so it can't be called directly from @testable tests either. Leaving this one line
    // uncovered rather than adding a contrived test for an unreachable branch.
}
