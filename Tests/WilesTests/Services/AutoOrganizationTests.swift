import Foundation
@testable import Wiles

@MainActor
public struct AutoOrganizationTests {
    public static func run() async {
        let baseTemp = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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
            isEnabled: true)

        let service = AutoOrganizationService.shared
        let oldRules = service.rules
        service.rules = [rule]

        await testActiveRuleExecution(service: service, matchingFile: matchingFile, nonMatchingFile: nonMatchingFile, inputDir: inputDir, targetDir: targetDir)
        await testDisabledRuleExecution(service: service, inputDir: inputDir, baseRule: rule)
        await testNameContainsCondition(service: service, inputDir: inputDir, targetDir: targetDir)
        await testNamePrefixCondition(service: service, inputDir: inputDir, targetDir: targetDir)
        await testGrowingFileIsNotMoved(service: service, inputDir: inputDir, targetDir: targetDir)
        await testFileWithChangingMtimeButStableSizeIsNotMoved(service: service, inputDir: inputDir, targetDir: targetDir)
        await testDirectoryEntriesAreNeverMoved(service: service, inputDir: inputDir, targetDir: targetDir)
        await testHiddenFilesAreNeverProcessed(service: service, inputDir: inputDir, targetDir: targetDir)
        testInProgressDownloadExtensionCheck()
        await testInProgressDownloadFilesAreNeverMoved(service: service, inputDir: inputDir, targetDir: targetDir)
        await testScheduleProcessFolderDebounces(service: service, inputDir: inputDir, targetDir: targetDir)
        testRuleMutationMethods(service: service, rule: rule)
        testStartMonitoringPublicEntryPoint(service: service)
        testProcessFolderOnNonexistentFolderReturnsEarly(service: service, targetDir: targetDir)
        await testMoveFailureIsReportedNotCrashed(service: service, inputDir: inputDir)
        await testFileDeletedDuringStabilityCheckIsSkippedNotCrashed(service: service, inputDir: inputDir, targetDir: targetDir)
        await testCrossVolumeStabilityHelpers(baseTemp: baseTemp)

        service.rules = oldRules
        try? FileManager.default.removeItem(at: baseTemp)
    }

    /// LL-063: before a **cross-volume** auto-move (a non-atomic copy+delete) the service now
    /// requires several more consecutive unchanged stability windows, so a download that stalls for
    /// one window and resumes isn't truncated at the destination. Same-volume moves (atomic rename)
    /// keep the single-window check.
    private static func testCrossVolumeStabilityHelpers(baseTemp: URL) async {
        let dir = baseTemp.appendingPathComponent("llo63")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // sameVolume: two paths under the same temp tree share a volume.
        let fileA = dir.appendingPathComponent("a.txt")
        try? "a".write(to: fileA, atomically: true, encoding: .utf8)
        TestReporter.report(
            "AutoOrganization", "POS: sameVolume() is true for two paths on the same mounted volume",
            result: AutoOrganizationService.sameVolume(fileA, dir.appendingPathComponent("dest.txt")))

        // sameVolume: an unresolvable path → treated as cross-volume (the safer default).
        let ghost = URL(fileURLWithPath: "/no-such-volume-\(UUID().uuidString)/x")
        TestReporter.report(
            "AutoOrganization", "NEG: sameVolume() returns false when a volume can't be resolved (safer = cross-volume)",
            result: !AutoOrganizationService.sameVolume(ghost, fileA))

        // confirmStableAcrossExtraWindows: a file that isn't changing passes.
        let stable = dir.appendingPathComponent("stable.bin")
        try? Data(count: 16).write(to: stable)
        let stablePassed = await AutoOrganizationService.confirmStableAcrossExtraWindows(stable, window: .milliseconds(15))
        TestReporter.report(
            "AutoOrganization", "POS: confirmStableAcrossExtraWindows() is true for a file whose size/mtime stay put",
            result: stablePassed)

        // confirmStableAcrossExtraWindows: a file still being appended fails.
        let growing = dir.appendingPathComponent("growing.bin")
        try? Data(count: 1).write(to: growing)
        let appender = Task.detached {
            for _ in 0 ..< 40 {
                if let handle = try? FileHandle(forWritingTo: growing) {
                    _ = try? handle.seekToEnd()
                    _ = try? handle.write(contentsOf: Data(count: 32))
                    _ = try? handle.close()
                }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        let growingPassed = await AutoOrganizationService.confirmStableAcrossExtraWindows(growing, window: .milliseconds(15))
        appender.cancel()
        TestReporter.report(
            "AutoOrganization", "NEG: confirmStableAcrossExtraWindows() is false for a file that is still growing",
            result: !growingPassed)
    }

    /// The service's own pipeline (folder scan → 150ms size-stability check → move) can take longer
    /// than any single fixed sleep under load, which made tests waiting on a flat `Task.sleep` flaky
    /// — poll for the expected outcome instead, up to a generous ceiling.
    private static func waitUntil(timeoutSeconds: Double = 5.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private static func testActiveRuleExecution(
        service: AutoOrganizationService,
        matchingFile _: URL,
        nonMatchingFile: URL,
        inputDir: URL,
        targetDir: URL) async {
        // Positive: Active Rule Execution
        service.processFolder(inputDir)
        let movedPDF = targetDir.appendingPathComponent("invoice.pdf")
        await waitUntil { FileManager.default.fileExists(atPath: movedPDF.path) }

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
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .nameContains, conditionValue: "report", isEnabled: true)
        service.rules = [containsRule]
        service.processFolder(inputDir)
        let movedContainsFile = targetDir.appendingPathComponent("draft_report.txt")
        await waitUntil { FileManager.default.fileExists(atPath: movedContainsFile.path) }
        TestReporter.report(
            "AutoOrganization",
            "POS: .nameContains rule matches a substring anywhere in the filename",
            result: FileManager.default.fileExists(atPath: movedContainsFile.path))
    }

    private static func testNamePrefixCondition(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        // POS: namePrefix condition type
        let prefixFile = inputDir.appendingPathComponent("IMG_1234.jpg")
        try? "x".write(to: prefixFile, atomically: true, encoding: .utf8)
        let prefixRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .namePrefix, conditionValue: "img_", isEnabled: true)
        service.rules = [prefixRule]
        service.processFolder(inputDir)
        let movedPrefixFile = targetDir.appendingPathComponent("IMG_1234.jpg")
        await waitUntil { FileManager.default.fileExists(atPath: movedPrefixFile.path) }
        TestReporter.report(
            "AutoOrganization",
            "POS: .namePrefix rule matches case-insensitively",
            result: FileManager.default.fileExists(atPath: movedPrefixFile.path))
    }

    /// Regression coverage for the N+1 fileExists fix: processFolder() now prefetches
    /// [.isDirectoryKey, .isHiddenKey] via `includingPropertiesForKeys` and reads them back through
    /// `resourceValues(forKeys:)` instead of a per-entry `fm.fileExists(atPath:isDirectory:)` call.
    /// A subdirectory named exactly like a matching rule's condition value (a real file with that
    /// name would be moved) proves the resourceValues-based isDirectory check still correctly
    /// excludes directories — if it had regressed to "always false" (as an N+1 refactor bug could),
    /// the directory would incorrectly get moved right alongside the real matching file.
    private static func testDirectoryEntriesAreNeverMoved(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let trapDir = inputDir.appendingPathComponent("archive.pdf")
        try? FileManager.default.createDirectory(at: trapDir, withIntermediateDirectories: true)
        let realFile = inputDir.appendingPathComponent("statement.pdf")
        try? "PDF".write(to: realFile, atomically: true, encoding: .utf8)

        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [pdfRule]

        service.processFolder(inputDir)
        let movedRealFile = targetDir.appendingPathComponent("statement.pdf")
        await waitUntil { FileManager.default.fileExists(atPath: movedRealFile.path) }

        let dirStillInPlace = FileManager.default.fileExists(atPath: trapDir.path)
        var dirIsStillADirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: trapDir.path, isDirectory: &dirIsStillADirectory)
        TestReporter.report(
            "AutoOrganization", "NEG: a directory whose name matches a rule's condition (e.g. \"archive.pdf/\") is never moved",
            result: dirStillInPlace && dirIsStillADirectory.boolValue)
        TestReporter.report(
            "AutoOrganization", "POS: a real matching file alongside the trap directory is still moved correctly",
            result: FileManager.default.fileExists(atPath: movedRealFile.path))

        try? FileManager.default.removeItem(at: trapDir)
    }

    /// `processFolder()` skips any entry whose name starts with "." (`file.lastPathComponent.hasPrefix(".")`)
    /// before even reaching the per-rule `matches(file:rule:)` check, so a dotfile that would otherwise
    /// match a rule's condition must never be moved. This branch is pure synchronous filtering logic
    /// (unlike the cross-volume `Task.detached` move dispatch this file's backlog item is about), so it's
    /// directly unit-testable: create a hidden file matching an active rule, run processFolder(), and
    /// confirm it's still in place after enough time has passed for a real match to have been moved.
    private static func testHiddenFilesAreNeverProcessed(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let hiddenMatchingFile = inputDir.appendingPathComponent(".secret.pdf")
        try? "PDF".write(to: hiddenMatchingFile, atomically: true, encoding: .utf8)
        let visibleMatchingFile = inputDir.appendingPathComponent("visible-alongside-hidden.pdf")
        try? "PDF".write(to: visibleMatchingFile, atomically: true, encoding: .utf8)

        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [pdfRule]

        service.processFolder(inputDir)
        let movedVisibleFile = targetDir.appendingPathComponent("visible-alongside-hidden.pdf")
        await waitUntil { FileManager.default.fileExists(atPath: movedVisibleFile.path) }

        TestReporter.report(
            "AutoOrganization", "NEG: a dotfile matching a rule's condition (e.g. \".secret.pdf\") is never moved",
            result: FileManager.default.fileExists(atPath: hiddenMatchingFile.path)
                && !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent(".secret.pdf").path))
        TestReporter.report(
            "AutoOrganization", "POS: a real matching file alongside the dotfile is still moved correctly",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("visible-alongside-hidden.pdf").path))

        try? FileManager.default.removeItem(at: hiddenMatchingFile)
    }

    /// MM-209: the pure denylist decision — the closed set of browser/torrent partial-download
    /// extensions that auto-org must never touch.
    private static func testInProgressDownloadExtensionCheck() {
        let partials = ["a.pdf.crdownload", "b.zip.download", "c.iso.part", "d.dmg.partial",
                        "e.mp4.opdownload", "movie.!ut", "linux.aria2"]
        let normal = ["report.pdf", "photo.jpeg", "archive.zip", "notes.download.txt", "x"]
        let allPartialsRejected = partials.allSatisfy {
            AutoOrganizationService.isInProgressDownload(URL(fileURLWithPath: "/tmp/\($0)"))
        }
        let noNormalRejected = normal.allSatisfy {
            !AutoOrganizationService.isInProgressDownload(URL(fileURLWithPath: "/tmp/\($0)"))
        }
        TestReporter.report(
            "AutoOrganization", "POS: every known in-progress-download extension is recognized",
            result: allPartialsRejected)
        TestReporter.report(
            "AutoOrganization", "NEG: a normal file (incl. one merely named *.download.txt) is not treated as a partial download",
            result: noNormalRejected)
    }

    /// MM-209: a `nameContains` rule can match a browser's temp download name (`report.pdf.crdownload`),
    /// and the size+mtime stability window is beatable by a download that pauses through it — so a
    /// cross-volume auto-move would strand a truncated file. Partial-download extensions are now
    /// skipped deterministically, before the stability check.
    private static func testInProgressDownloadFilesAreNeverMoved(
        service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let partial = inputDir.appendingPathComponent("report.pdf.crdownload")
        let partial2 = inputDir.appendingPathComponent("dataset.part")
        try? "half".write(to: partial, atomically: true, encoding: .utf8)
        try? "half".write(to: partial2, atomically: true, encoding: .utf8)
        let realMatch = inputDir.appendingPathComponent("report-final.pdf")
        try? "PDF".write(to: realMatch, atomically: true, encoding: .utf8)

        let containsRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir,
            conditionType: .nameContains, conditionValue: "report", isEnabled: true)
        service.rules = [containsRule]

        service.processFolder(inputDir)
        let movedReal = targetDir.appendingPathComponent("report-final.pdf")
        await waitUntil { FileManager.default.fileExists(atPath: movedReal.path) }

        TestReporter.report(
            "AutoOrganization",
            "NEG: a *.crdownload / *.part file matching a nameContains rule is never auto-moved",
            result: FileManager.default.fileExists(atPath: partial.path)
                && FileManager.default.fileExists(atPath: partial2.path)
                && !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("report.pdf.crdownload").path))
        TestReporter.report(
            "AutoOrganization", "POS: a real matching file alongside the partial downloads is still moved",
            result: FileManager.default.fileExists(atPath: movedReal.path))

        try? FileManager.default.removeItem(at: partial)
        try? FileManager.default.removeItem(at: partial2)
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
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "zip", isEnabled: true)
        service.rules = [zipRule]

        let writer = Task.detached(priority: .utility) {
            guard let handle = try? FileHandle(forWritingTo: growingFile) else { return }
            defer { try? handle.close() }
            for _ in 0 ..< 60 {
                handle.seekToEndOfFile()
                handle.write(Data("chunk".utf8))
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000) // let the writer get going first
        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 700_000_000) // span while the writer is still appending, well inside the stability window

        let stillInSourceWhileWriting = FileManager.default.fileExists(atPath: growingFile.path)
        let notYetInTarget = !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("downloading.zip").path)
        TestReporter.report(
            "AutoOrganization", "NEG: processFolder() does not move a .zip file that's still actively growing",
            result: stillInSourceWhileWriting && notYetInTarget)

        await writer.value // let the writer finish so the file's size settles
        try? await Task.sleep(nanoseconds: 100_000_000) // let the filesystem settle after the last write
        service.processFolder(inputDir)
        await waitUntil { FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("downloading.zip").path) }
        TestReporter.report(
            "AutoOrganization", "POS: processFolder() moves the same file once its size has stopped changing",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("downloading.zip").path))
    }

    /// The stability check compares size AND modification date. A writer that rewrites the same
    /// number of bytes (size unchanged, mtime advancing) must still count as "still writing" and
    /// not be moved mid-write — size alone would have moved it.
    private static func testFileWithChangingMtimeButStableSizeIsNotMoved(
        service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let file = inputDir.appendingPathComponent("rewriting.pdf")
        let payload = Data(repeating: 0x41, count: 4096)
        try? payload.write(to: file)
        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [pdfRule]

        // Keep rewriting the same 4096 bytes (size never changes, mtime keeps advancing) for longer
        // than the stability window.
        let rewriter = Task.detached(priority: .utility) {
            for _ in 0 ..< 12 {
                try? payload.write(to: file)
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        service.processFolder(inputDir)
        try? await Task.sleep(nanoseconds: 2_500_000_000) // spans the 2s window while mtime keeps moving
        let notMovedWhileRewriting = FileManager.default.fileExists(atPath: file.path)
            && !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("rewriting.pdf").path)
        TestReporter.report(
            "AutoOrganization",
            "NEG: a file whose size is stable but modification date keeps changing is not moved (still being written)",
            result: notMovedWhileRewriting)

        await rewriter.value
        try? await Task.sleep(nanoseconds: 100_000_000)
        service.processFolder(inputDir)
        await waitUntil { FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("rewriting.pdf").path) }
        TestReporter.report(
            "AutoOrganization",
            "POS: the same file moves once its modification date also settles",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("rewriting.pdf").path))
    }

    /// Regression coverage for the CPU-spin fix's other half: scheduleProcessFolder() (what the
    /// DispatchSource .write handler now calls instead of processFolder() directly) must not scan
    /// immediately — it debounces on a fixed 500ms timer, which is deterministic to test (a timer
    /// firing after N seconds isn't a race, unlike waiting on real disk/XPC I/O to finish).
    private static func testScheduleProcessFolderDebounces(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let debouncedFile = inputDir.appendingPathComponent("debounced.pdf")
        try? "PDF".write(to: debouncedFile, atomically: true, encoding: .utf8)
        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [pdfRule]

        // Simulate several rapid-fire .write events, as a large file being written would trigger.
        service.scheduleProcessFolder(inputDir)
        service.scheduleProcessFolder(inputDir)
        service.scheduleProcessFolder(inputDir)

        try? await Task.sleep(nanoseconds: 150_000_000) // comfortably under the 500ms debounce interval
        TestReporter.report(
            "AutoOrganization", "NEG: scheduleProcessFolder() does not scan immediately (still debouncing)",
            result: FileManager.default.fileExists(atPath: debouncedFile.path))

        // Past debounce (500ms) + the move's own stability window + a margin for system load.
        await waitUntil { FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("debounced.pdf").path) }
        TestReporter.report(
            "AutoOrganization", "POS: scheduleProcessFolder() eventually scans and moves the matching file once debouncing settles",
            result: FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("debounced.pdf").path))
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
        TestReporter.report(
            "AutoOrganization",
            "POS: deleteRule() removes the rule with matching id",
            result: !service.rules.contains(where: { $0.id == rule.id }))
    }

    /// `startMonitoring()` is the public entry point apps call once at launch; it just forwards to
    /// the same `restartMonitoring()` already exercised indirectly by every `service.rules = ...`
    /// assignment above (via the property's `didSet`). No new async wait is introduced here — the
    /// point of this test is only to execute `startMonitoring()`'s own two lines directly (they
    /// were previously uncovered), and confirm the call is a safe, non-mutating no-op with respect
    /// to the current rule list.
    private static func testStartMonitoringPublicEntryPoint(service: AutoOrganizationService) {
        let rulesBefore = service.rules
        service.startMonitoring()
        TestReporter.report(
            "AutoOrganization", "POS: startMonitoring() can be called directly and leaves the current rules unchanged",
            result: service.rules.map(\.id) == rulesBefore.map(\.id))
    }

    /// Covers the early-`return` branch in `processFolder()` when `contentsOfDirectory(at:...)`
    /// throws because the source folder does not exist on disk (e.g. deleted between the watcher
    /// firing and the scan running). Purely synchronous — no sleep needed since there's no
    /// detached move task to wait on when the directory read itself fails.
    private static func testProcessFolderOnNonexistentFolderReturnsEarly(service: AutoOrganizationService, targetDir: URL) {
        let missingDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let rule = AutoOrganizationRule(
            sourceURL: missingDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [rule]

        service.processFolder(missingDir)

        TestReporter.report(
            "AutoOrganization",
            "NEG: processFolder() on a nonexistent source folder returns early without crashing and leaves rules intact",
            result: service.rules.contains(where: { $0.id == rule.id }))
    }

    /// Covers `matchAndDispatchMoves`'s `catch` block: `FileSystemService.moveItem` throws
    /// `.itemAlreadyInDestination` when source and destination standardize to the same path. A rule
    /// whose destination IS its own source folder forces every match through that throw, proving the
    /// failure is reported (not silently swallowed or crashed) and the source file survives untouched.
    private static func testMoveFailureIsReportedNotCrashed(service: AutoOrganizationService, inputDir: URL) async {
        let selfDestFile = inputDir.appendingPathComponent("self_dest.pdf")
        try? "PDF".write(to: selfDestFile, atomically: true, encoding: .utf8)
        // destinationURL == sourceURL: matchAndDispatchMoves computes destURL = inputDir/self_dest.pdf,
        // which standardizes to the same path as the source file itself.
        let selfDestRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: inputDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [selfDestRule]

        service.processFolder(inputDir)
        // Stability window (2s) + the failing move attempt + a margin for system load.
        try? await Task.sleep(nanoseconds: 2_800_000_000)

        TestReporter.report(
            "AutoOrganization",
            "NEG: a move that fails (source == destination) is reported via ErrorReporter and leaves the source file intact, not crashed",
            result: FileManager.default.fileExists(atPath: selfDestFile.path))

        try? FileManager.default.removeItem(at: selfDestFile)
    }

    /// Covers the "still being written" guard's other failure mode: `Self.fileSize` returning `nil`
    /// on the second read (not just size mismatch). Deleting the file mid-stability-check makes the
    /// second `attributesOfItem` call throw, exercising `guard let sizeAfter = ... else { return }`
    /// via a genuinely nil `sizeAfter` rather than a numeric mismatch.
    private static func testFileDeletedDuringStabilityCheckIsSkippedNotCrashed(
        service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let vanishingFile = inputDir.appendingPathComponent("vanishing.pdf")
        try? "PDF".write(to: vanishingFile, atomically: true, encoding: .utf8)
        let pdfRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir, conditionType: .extensionEquals, conditionValue: "pdf", isEnabled: true)
        service.rules = [pdfRule]

        service.processFolder(inputDir)
        // Delete well inside the stability window so the post-window snapshot read returns nil.
        try? await Task.sleep(nanoseconds: 200_000_000)
        try? FileManager.default.removeItem(at: vanishingFile)
        try? await Task.sleep(nanoseconds: 2_600_000_000)

        TestReporter.report(
            "AutoOrganization",
            "NEG: a file deleted mid-stability-check is skipped (nil sizeAfter) without crashing or appearing in the destination",
            result: !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("vanishing.pdf").path))
    }
}
