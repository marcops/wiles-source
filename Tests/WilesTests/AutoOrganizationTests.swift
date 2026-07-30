import Foundation
import WilesCore

@MainActor
public struct AutoOrganizationTests {
    public static func run() async {
        let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let inputDir = baseTemp.appendingPathComponent("Input")
        let targetDir = baseTemp.appendingPathComponent("Target")
        
        try? FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        let matchingFile = inputDir.appendingPathComponent("invoice.pdf")
        let nonMatchingFile = inputDir.appendingPathComponent("notes.txt")
        try? "PDF".write(to: matchingFile, atomically: true, encoding: .utf8)
        try? "TXT".write(to: nonMatchingFile, atomically: true, encoding: .utf8)
        
        let rule = AutoOrganizationRule(
            sourceURL: inputDir,
            destinationURL: targetDir,
            conditionType: .extensionEquals,
            conditionValue: "pdf",
            isEnabled: true
        )
        
        let service = AutoOrganizationService.shared
        let oldRules = service.rules
        service.rules = [rule]
        
        // Positive: Active Rule Execution
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        let movedPDF = targetDir.appendingPathComponent("invoice.pdf")
        let posOrgPassed = FileManager.default.fileExists(atPath: movedPDF.path)
        TestReporter.report("AutoOrganization", "POS: Rule routes matching .pdf file to destination", result: posOrgPassed)
        
        // Negative: Non-Matching File Remains Intact
        let nonMatchIntact = FileManager.default.fileExists(atPath: nonMatchingFile.path)
        TestReporter.report("AutoOrganization", "NEG: Non-matching .txt file remains untouched in source directory", result: nonMatchIntact)
        
        // Negative: Disabled Rule Execution
        let matchingFile2 = inputDir.appendingPathComponent("contract.pdf")
        try? "PDF 2".write(to: matchingFile2, atomically: true, encoding: .utf8)
        var disabledRule = rule
        disabledRule.isEnabled = false
        service.rules = [disabledRule]
        
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        let disabledIntact = FileManager.default.fileExists(atPath: matchingFile2.path)
        TestReporter.report("AutoOrganization", "NEG: Disabled rule ignores matching file", result: disabledIntact)
        
        service.rules = oldRules
        try? FileManager.default.removeItem(at: baseTemp)
    }
}
