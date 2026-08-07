@testable import Wiles
import Foundation

@MainActor
public struct AutoOrganizationTests {
    public static func run() async {
        let baseTemp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let inputDir = baseTemp.appendingPathComponent("Input")
        let targetDir = baseTemp.appendingPathComponent("Target")

        try? FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        // Files must exist before `service.rules` is assigned: the assignment's didSet calls
        // restartMonitoring(), which starts a DispatchSource watcher on inputDir. Creating the
        // files afterward races that watcher's own async handling against this test's explicit
        // processFolder() call below (this order matches the original, verified-working test).
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

        await testActiveRuleExecution(service: service, matchingFile: matchingFile, nonMatchingFile: nonMatchingFile, inputDir: inputDir, targetDir: targetDir)
        await testDisabledRuleExecution(service: service, inputDir: inputDir, baseRule: rule)
        await testNameContainsCondition(service: service, inputDir: inputDir, targetDir: targetDir)
        await testNamePrefixCondition(service: service, inputDir: inputDir, targetDir: targetDir)
        await testGrowingFileIsNotMoved(service: service, inputDir: inputDir, targetDir: targetDir)
        await testScheduleProcessFolderDebounces(service: service, inputDir: inputDir, targetDir: targetDir)
        testRuleMutationMethods(service: service, rule: rule)

        service.rules = oldRules
        try? FileManager.default.removeItem(at: baseTemp)
    }

    private static func testActiveRuleExecution(service: AutoOrganizationService, matchingFile: URL, nonMatchingFile: URL, inputDir: URL, targetDir: URL) async {
        // Positive: Active Rule Execution
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let movedPDF = targetDir.appendingPathComponent("invoice.pdf")
        let posOrgPassed = FileManager.default.fileExists(atPath: movedPDF.path)
        TestReporter.report("AutoOrganization", "POS: Rule routes matching .pdf file to destination", result: posOrgPassed)

        // Negative: Non-Matching File Remains Intact
        let nonMatchIntact = FileManager.default.fileExists(atPath: nonMatchingFile.path)
        TestReporter.report("AutoOrganization", "NEG: Non-matching .txt file remains untouched in source directory", result: nonMatchIntact)
    }

    private static func testDisabledRuleExecution(service: AutoOrganizationService, inputDir: URL, baseRule: AutoOrganizationRule) async {
        // Negative: Disabled Rule Execution
        let matchingFile2 = inputDir.appendingPathComponent("contract.pdf")
        try? "PDF 2".write(to: matchingFile2, atomically: true, encoding: .utf8)
        var disabledRule = baseRule
        disabledRule.isEnabled = false
        service.rules = [disabledRule]

        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)

        let disabledIntact = FileManager.default.fileExists(atPath: matchingFile2.path)
        TestReporter.report("AutoOrganization", "NEG: Disabled rule ignores matching file", result: disabledIntact)
    }

    private static func testNameContainsCondition(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        // POS: nameContains condition type
        let containsFile = inputDir.appendingPathComponent("draft_report.txt")
        try? "x".write(to: containsFile, atomically: true, encoding: .utf8)
        let containsRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .nameContains, conditionValue: "report", isEnabled: true
        )
        service.rules = [containsRule]
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report(
            "AutoOrganization",
            "POS: .nameContains rule matches a substring anywhere in the filename",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("draft_report.txt").path)
        )
    }

    private static func testNamePrefixCondition(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        // POS: namePrefix condition type
        let prefixFile = inputDir.appendingPathComponent("IMG_1234.jpg")
        try? "x".write(to: prefixFile, atomically: true, encoding: .utf8)
        let prefixRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .namePrefix, conditionValue: "img_", isEnabled: true
        )
        service.rules = [prefixRule]
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 300_000_000)
        TestReporter.report(
            "AutoOrganization",
            "POS: .namePrefix rule matches case-insensitively",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("IMG_1234.jpg").path)
        )
    }

    /// Regression coverage for the CPU-spin fix: a file that's still actively growing (simulating an
    /// in-progress download) must not be moved mid-write — moving it is deferred until its size
    /// stops changing. The writer here appends every 15ms — a wide margin under the service's 150ms
    /// size-stability window (10x) — and keeps writing well past the check, so even under heavy
    /// system load (e.g. a concurrent build competing for CPU) the "still growing" case stays a
    /// comfortable margin, not a close race.
    private static func testGrowingFileIsNotMoved(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let growingFile = inputDir.appendingPathComponent("downloading.zip")
        FileManager.default.createFile(atPath: growingFile.path, contents: Data("start".utf8))
        let zipRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "zip", isEnabled: true
        )
        service.rules = [zipRule]

        let writer = Task.detached(priority: .utility) {
            guard let handle = try? FileHandle(forWritingTo: growingFile) else { return }
            defer { try? handle.close() }
            for _ in 0..<60 {
                handle.seekToEndOfFile()
                handle.write(Data("chunk".utf8))
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000) // let the writer get going first
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 500_000_000) // generous span across the 150ms stability check while still writing

        let stillInSourceWhileWriting = FileManager.default.fileExists(atPath: growingFile.path)
        let notYetInTarget = !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("downloading.zip").path)
        TestReporter.report(
            "AutoOrganization", "NEG: processFolder() does not move a .zip file that's still actively growing",
            result: stillInSourceWhileWriting && notYetInTarget
        )

        await writer.value // let the writer finish so the file's size settles
        try? await Task.sleep(nanoseconds: 100_000_000) // let the filesystem settle after the last write
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 500_000_000)
        TestReporter.report(
            "AutoOrganization", "POS: processFolder() moves the same file once its size has stopped changing",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("downloading.zip").path)
        )
    }

    /// Regression coverage for the CPU-spin fix's other half: scheduleProcessFolder() (what the
    /// DispatchSource .write handler now calls instead of processFolder() directly) must not scan
    /// immediately — it debounces on a fixed 500ms timer, which is deterministic to test (a timer
    /// firing after N seconds isn't a race, unlike waiting on real disk/XPC I/O to finish).
    private static func testScheduleProcessFolderDebounces(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let debouncedFile = inputDir.appendingPathComponent("debounced.pdf")
        try? "PDF".write(to: debouncedFile, atomically: true, encoding: .utf8)
        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true
        )
        service.rules = [pdfRule]

        // Simulate several rapid-fire .write events, as a large file being written would trigger.
        service.scheduleProcessFolder(inputDir)
        service.scheduleProcessFolder(inputDir)
        service.scheduleProcessFolder(inputDir)

        try? await Task.sleep(nanoseconds: 150_000_000) // comfortably under the 500ms debounce interval
        TestReporter.report(
            "AutoOrganization", "NEG: scheduleProcessFolder() does not scan immediately (still debouncing)",
            result: FileManager.default.fileExists(atPath: debouncedFile.path)
        )

        // Past debounce (500ms) + the move's own stability check (150ms) + a generous margin for
        // system load (e.g. a concurrent build competing for CPU).
        try? await Task.sleep(nanoseconds: 900_000_000)
        TestReporter.report(
            "AutoOrganization", "POS: scheduleProcessFolder() eventually scans and moves the matching file once debouncing settles",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("debounced.pdf").path)
        )
    }

    private static func testRuleMutationMethods(service: AutoOrganizationService, rule: AutoOrganizationRule) {
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
    }
}
