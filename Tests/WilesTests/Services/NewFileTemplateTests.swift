@testable import Wiles
import Foundation

@MainActor
public struct NewFileTemplateTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Positive: Create Markdown Template
        let mdURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "README.md", template: .markdown)
        let mdPos = mdURL != nil && FileManager.default.fileExists(atPath: mdURL!.path)
        TestReporter.report("NewFileTemplate", "POS: createTemplateFile (.markdown)", result: mdPos)
        
        // Positive: Create Swift Template
        let swiftURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "Main.swift", template: .swift)
        let swiftPos = swiftURL != nil && FileManager.default.fileExists(atPath: swiftURL!.path)
        TestReporter.report("NewFileTemplate", "POS: createTemplateFile (.swift)", result: swiftPos)
        
        // Negative: Empty file name uses default file name
        let defaultURL = try? NewFileTemplateService.createTemplateFile(in: tempDir, fileName: "   ", template: .json)
        let defaultPos = defaultURL != nil && defaultURL!.lastPathComponent == FileTemplate.json.defaultFileName
        TestReporter.report("NewFileTemplate", "NEG: Empty file name falls back to template default name", result: defaultPos)
        
        try? FileManager.default.removeItem(at: tempDir)
    }
}
