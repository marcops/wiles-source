@testable import Wiles
import Foundation

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

        // POS: nameContains condition type
        let containsFile = inputDir.appendingPathComponent("draft_report.txt")
        try? "x".write(to: containsFile, atomically: true, encoding: .utf8)
        let containsRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .nameContains, conditionValue: "report", isEnabled: true
        )
        service.rules = [containsRule]
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report("AutoOrganization", "POS: .nameContains rule matches a substring anywhere in the filename", result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("draft_report.txt").path))

        // POS: namePrefix condition type
        let prefixFile = inputDir.appendingPathComponent("IMG_1234.jpg")
        try? "x".write(to: prefixFile, atomically: true, encoding: .utf8)
        let prefixRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .namePrefix, conditionValue: "img_", isEnabled: true
        )
        service.rules = [prefixRule]
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report("AutoOrganization", "POS: .namePrefix rule matches case-insensitively", result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("IMG_1234.jpg").path))

        // POS: addRule / updateRule / deleteRule mutate the rules array directly
        service.rules = []
        service.addRule(rule)
        TestReporter.report("AutoOrganization", "POS: addRule() appends a new rule", result: service.rules.contains(where: { $0.id == rule.id }))

        var updated = rule
        updated.conditionValue = "docx"
        service.updateRule(updated)
        TestReporter.report("AutoOrganization", "POS: updateRule() replaces the rule with matching id", result: service.rules.first?.conditionValue == "docx")

        service.deleteRule(id: rule.id)
        TestReporter.report("AutoOrganization", "POS: deleteRule() removes the rule with matching id", result: !service.rules.contains(where: { $0.id == rule.id }))

        service.rules = oldRules
        try? FileManager.default.removeItem(at: baseTemp)
    }
}
