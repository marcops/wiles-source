import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct BatchRenameFeatureTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("file_a.txt")
        try? "test".write(to: file1, atomically: true, encoding: .utf8)
        let item1 = FileItem.load(url: file1, icon: NSWorkspace.shared.icon(forFile: file1.path))

        let prefixMode = BatchRenameMode.addPrefixSuffix(prefix: "PRE_", suffix: "_POST")
        let previews = BatchRenameService.previewNewNames(items: [item1], mode: prefixMode)
        report("Feature/BatchRename", "POS: Prefix and suffix added correctly", result: previews.first?.newName == "PRE_file_a_POST.txt")

        let regexMode = BatchRenameMode.regex(pattern: "file_(.*)", template: "document_$1")
        let regexPreviews = BatchRenameService.previewNewNames(items: [item1], mode: regexMode)
        report("Feature/BatchRename", "POS: Regex replace template works", result: regexPreviews.first?.newName == "document_a.txt")

        await testInvalidRegexPatternThrowsInsteadOfSilentlyNoOpingRename()
        await testValidRegexPatternIsResolvedOnceAndAppliedByPerform()
        testValidateTargets()
        testSequenceNumberPaddingIsClamped(item1: item1)
        await testPerformBatchRenameAbortsUpFrontOnCollision()
        testAssertNoCollisionsCanBeCalledDirectlyForPreValidation()
        await testPerformBatchRenameSurfacesCancellation()
        await testPermutationRenameStagesThroughTempNames()
        await testStagePermutationCyclesRollsBackEveryGroupNotJustTheFailingOne()
        await testRecoverStrandedStagingTempsDeHidesCrashLeftovers()
        await testCancelledPermutationRenameLeavesNoHiddenStagingTemp()
    }

    /// MM-113: a batch rename that crashed between staging and the final rename leaves the file
    /// parked under a hidden `.wiles-batch-rename-*` name. The next batch rename in that folder
    /// renames it to a visible `Recovered …` name (never deletes it — it's the only copy). A temp
    /// younger than the age gate (this run's own in-flight staging) is left untouched.
    private static func testRecoverStrandedStagingTempsDeHidesCrashLeftovers() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default

        let stale = dir.appendingPathComponent("\(BatchRenameService.stagingTempPrefix)DEAD-1234")
        try? "user data".write(to: stale, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.modificationDate: Date().addingTimeInterval(-120)], ofItemAtPath: stale.path)

        let fresh = dir.appendingPathComponent("\(BatchRenameService.stagingTempPrefix)LIVE-5678")
        try? "in flight".write(to: fresh, atomically: true, encoding: .utf8)

        await BatchRenameService.recoverStrandedStagingTemps(in: [dir])

        let entries = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        let staleDeHidden = !fm.fileExists(atPath: stale.path)
            && entries.contains { $0.hasPrefix("Recovered ") }
            && (try? String(contentsOf: dir.appendingPathComponent("Recovered DEAD-1234"))) == "user data"
        let freshLeftAlone = fm.fileExists(atPath: fresh.path)
        report(
            "Feature/BatchRename",
            "POS: recoverStrandedStagingTemps de-hides a crash leftover to a visible 'Recovered' name and never deletes it (MM-113)",
            result: staleDeHidden && freshLeftAlone)
    }

    /// MM-113: cancelling a permutation batch rename (which stages participants under hidden temp
    /// names first) must not leave any file stranded under `.wiles-batch-rename-*`.
    private static func testCancelledPermutationRenameLeavesNoHiddenStagingTemp() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default

        var items: [FileItem] = []
        for i in 1 ... 6 {
            let url = dir.appendingPathComponent("f_\(i).txt")
            try? "\(i)".write(to: url, atomically: true, encoding: .utf8)
            items.append(FileItem.load(url: url, icon: NSWorkspace.shared.icon(forFile: url.path)))
        }
        // Shift-up renumber = a rename cycle ⇒ staging kicks in.
        let task = Task {
            try await BatchRenameService.performBatchRename(
                items: items, mode: .sequenceNumber(prefix: "f", startNumber: 2, paddingDigits: 1))
        }
        task.cancel()
        _ = try? await task.value

        // Whatever the outcome (finished or aborted), no file may be left under the hidden prefix.
        let noHiddenTemp = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? [])
            .allSatisfy { !$0.hasPrefix(BatchRenameService.stagingTempPrefix) }
        let sameFileCount = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).count == 6
        report(
            "Feature/BatchRename",
            "POS: a cancelled permutation batch rename strands no file under a hidden .wiles-batch-rename- name (MM-113)",
            result: noHiddenTemp && sameFileCount)
    }

    /// A shift-up renumber (`file_2 → file_3`, `file_3 → file_4`) is a rename cycle: the sequential
    /// executor used to fail the first step because `file_3` was still occupied by the other source.
    private static func testPermutationRenameStagesThroughTempNames() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let two = dir.appendingPathComponent("file_2.txt")
        let three = dir.appendingPathComponent("file_3.txt")
        try? "2".write(to: two, atomically: true, encoding: .utf8)
        try? "3".write(to: three, atomically: true, encoding: .utf8)
        let items = [
            FileItem.load(url: two, icon: NSWorkspace.shared.icon(forFile: two.path)),
            FileItem.load(url: three, icon: NSWorkspace.shared.icon(forFile: three.path))
        ]

        let result = try? await BatchRenameService.performBatchRename(
            items: items, mode: .sequenceNumber(prefix: "file", startNumber: 3, paddingDigits: 1))

        let fm = FileManager.default
        let bothFinalsExist = fm.fileExists(atPath: dir.appendingPathComponent("file_3.txt").path)
            && fm.fileExists(atPath: dir.appendingPathComponent("file_4.txt").path)
        let originalGoneAndContentFollowed = !fm.fileExists(atPath: two.path)
            && (try? String(contentsOf: dir.appendingPathComponent("file_4.txt"))) == "3"
        let noLeftoverTemp = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).allSatisfy { !$0.hasPrefix(".wiles-batch-rename-") }
        report(
            "Feature/BatchRename",
            "POS: a rename cycle renames every file (staged through temp names) instead of failing the first step",
            result: (result?.failures.isEmpty ?? false) && bothFinalsExist && originalGoneAndContentFollowed && noLeftoverTemp)
    }

    private static func allInvariantsHold(threw: Bool, noStagedTempInGoodDir: Bool, goodDirNamesRestored: Bool) -> Bool {
        threw && noStagedTempInGoodDir && goodDirNamesRestored
    }

    /// R6: `stagePermutationCycles` stages one rename-cycle group per source directory in the same
    /// batch. If a later group's staging fails, every group staged so far must roll back — not just
    /// the failing one — or an earlier, already-succeeded directory is left with its files parked
    /// under hidden temp names with nothing left to resolve them. Directory iteration order isn't
    /// controlled by the caller (`Dictionary(grouping:)` iterates in hash order), so this repeats
    /// the scenario across several distinct temp-directory pairs to exercise both relative orderings.
    private static func testStagePermutationCyclesRollsBackEveryGroupNotJustTheFailingOne() async {
        let fm = FileManager.default
        var allInvariantsHeld = true

        for _ in 0 ..< 6 {
            let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            let goodDir = root.appendingPathComponent("good")
            let badDir = root.appendingPathComponent("bad")
            try? fm.createDirectory(at: goodDir, withIntermediateDirectories: true)
            try? fm.createDirectory(at: badDir, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: root) }

            let goodA = goodDir.appendingPathComponent("a.txt")
            let goodB = goodDir.appendingPathComponent("b.txt")
            try? "a".write(to: goodA, atomically: true, encoding: .utf8)
            try? "b".write(to: goodB, atomically: true, encoding: .utf8)

            let badA = badDir.appendingPathComponent("a.txt")
            let badB = badDir.appendingPathComponent("b.txt")
            try? "a".write(to: badA, atomically: true, encoding: .utf8)
            // badB is deliberately never created — its rename fails with "no such file", forcing
            // badDir's group to fail mid-staging.

            let pairs: [(url: URL, newName: String)] = [
                (goodA, "b.txt"), (goodB, "a.txt"),
                (badA, "b.txt"), (badB, "a.txt")
            ]

            var threw = false
            do {
                _ = try await BatchRenameService.stagePermutationCycles(pairs: pairs)
            } catch {
                threw = true
            }

            let goodDirEntries = (try? fm.contentsOfDirectory(atPath: goodDir.path)) ?? []
            let noStagedTempInGoodDir = goodDirEntries.allSatisfy { !$0.hasPrefix(BatchRenameService.stagingTempPrefix) }
            let goodDirNamesRestored = Set(goodDirEntries) == Set(["a.txt", "b.txt"])

            if !allInvariantsHold(threw: threw, noStagedTempInGoodDir: noStagedTempInGoodDir, goodDirNamesRestored: goodDirNamesRestored) {
                allInvariantsHeld = false
            }
        }

        report(
            "Feature/BatchRename",
            "POS: a later group's staging failure rolls back an earlier, already-staged group too (R6)",
            result: allInvariantsHeld)
    }

    /// Lote 15 (M61): `validateTargets` is the pure pre-flight collision check.
    private static func testValidateTargets() {
        let dup = BatchRenameService.validateTargets(
            targetNames: ["report.txt", "report.txt", "notes.txt"], renamedOriginalNames: [], directoryContents: [])
        report(
            "Feature/BatchRename",
            "POS: validateTargets reports two batch entries mapping to one target once as .duplicateWithinBatch",
            result: dup == [BatchRenameConflict(targetName: "report.txt", kind: .duplicateWithinBatch)])

        let onDisk = BatchRenameService.validateTargets(
            targetNames: ["taken.txt"], renamedOriginalNames: [], directoryContents: ["taken.txt", "other.txt"])
        report(
            "Feature/BatchRename",
            "POS: validateTargets reports a target that already exists on disk as .existsOnDisk",
            result: onDisk == [BatchRenameConflict(targetName: "taken.txt", kind: .existsOnDisk)])

        let selfRenamed = BatchRenameService.validateTargets(
            targetNames: ["b.txt"], renamedOriginalNames: ["b.txt"], directoryContents: ["b.txt"])
        report(
            "Feature/BatchRename",
            "NEG: validateTargets does not flag an on-disk target that is itself being renamed away (swap/rotate)",
            result: selfRenamed.isEmpty)

        let clean = BatchRenameService.validateTargets(
            targetNames: ["x1.txt", "x2.txt"], renamedOriginalNames: ["a.txt", "b.txt"],
            directoryContents: ["a.txt", "b.txt", "unrelated.txt"])
        report("Feature/BatchRename", "NEG: validateTargets returns empty when there are no collisions", result: clean.isEmpty)
    }

    /// L60: `.sequenceNumber` clamps `paddingDigits` into `1...10` instead of trusting the caller.
    private static func testSequenceNumberPaddingIsClamped(item1: FileItem) {
        let tooWide = BatchRenameService.previewNewNames(
            items: [item1], mode: .sequenceNumber(prefix: "P", startNumber: 1, paddingDigits: 99))
        report(
            "Feature/BatchRename",
            "POS: .sequenceNumber padding of 99 is clamped to 10 digits",
            result: tooWide.first?.newName == "P_0000000001.txt")

        let tooNarrow = BatchRenameService.previewNewNames(
            items: [item1], mode: .sequenceNumber(prefix: "P", startNumber: 5, paddingDigits: 0))
        report(
            "Feature/BatchRename",
            "POS: .sequenceNumber padding of 0 is clamped to 1 digit",
            result: tooNarrow.first?.newName == "P_5.txt")
    }

    /// M61: a batch whose targets would collapse to one name throws up front — nothing is renamed on disk.
    private static func testPerformBatchRenameAbortsUpFrontOnCollision() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let urlA = dir.appendingPathComponent("IMG_001.txt")
        let urlB = dir.appendingPathComponent("IMG_002.txt")
        try? "a".write(to: urlA, atomically: true, encoding: .utf8)
        try? "b".write(to: urlB, atomically: true, encoding: .utf8)
        let itemA = FileItem.load(url: urlA, icon: NSWorkspace.shared.icon(forFile: urlA.path))
        let itemB = FileItem.load(url: urlB, icon: NSWorkspace.shared.icon(forFile: urlB.path))

        var threw = false
        do {
            _ = try await BatchRenameService.performBatchRename(items: [itemA, itemB], mode: .regex(pattern: "IMG_\\d+", template: "IMG"))
        } catch {
            threw = true
        }
        report("Feature/BatchRename", "NEG: performBatchRename throws up front when two targets collapse to one name", result: threw)
        report(
            "Feature/BatchRename",
            "NEG: performBatchRename leaves both originals on disk when it aborts on a collision (no partial renames)",
            result: FileManager.default.fileExists(atPath: urlA.path) && FileManager.default.fileExists(atPath: urlB.path))
    }

    /// SL-046: `assertNoCollisions` is called directly by `BatchRenameSheetView` to pre-validate on
    /// "Apply" and show the same collision message inline, instead of only surfacing it after
    /// `performBatchRename` throws asynchronously post-dismissal. Exercises it standalone (not via
    /// `performBatchRename`) with both a colliding and a clean preview set.
    private static func testAssertNoCollisionsCanBeCalledDirectlyForPreValidation() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let urlA = dir.appendingPathComponent("IMG_001.txt")
        let urlB = dir.appendingPathComponent("IMG_002.txt")
        try? "a".write(to: urlA, atomically: true, encoding: .utf8)
        try? "b".write(to: urlB, atomically: true, encoding: .utf8)
        let itemA = FileItem.load(url: urlA, icon: NSWorkspace.shared.icon(forFile: urlA.path))
        let itemB = FileItem.load(url: urlB, icon: NSWorkspace.shared.icon(forFile: urlB.path))

        let collidingPreviews: [(original: FileItem, newName: String)] = [(itemA, "IMG.txt"), (itemB, "IMG.txt")]
        var threw = false
        do {
            try BatchRenameService.assertNoCollisions(in: collidingPreviews)
        } catch {
            threw = true
        }
        report(
            "Feature/BatchRename",
            "NEG (SL-046): assertNoCollisions throws standalone for a colliding preview, without going through performBatchRename",
            result: threw)

        let cleanPreviews: [(original: FileItem, newName: String)] = [(itemA, "Renamed_001.txt"), (itemB, "Renamed_002.txt")]
        var cleanThrew = false
        do {
            try BatchRenameService.assertNoCollisions(in: cleanPreviews)
        } catch {
            cleanThrew = true
        }
        report(
            "Feature/BatchRename",
            "POS (SL-046): assertNoCollisions does not throw for a clean, non-colliding preview",
            result: !cleanThrew)
    }

    /// R7: a cancelled `performBatchRename` does NOT throw `CancellationError` out of the rename
    /// loop — it returns the `BatchRenameResult` built from whatever completed before cancellation,
    /// so the caller's own undo/reporting code (which only runs on a normal return, not a catch)
    /// still sees the renames that genuinely happened on disk. Renames done before the cancellation
    /// stay on disk either way (the loop checks `Task.isCancelled` per iteration).
    private static func testPerformBatchRenameSurfacesCancellation() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var items: [FileItem] = []
        for i in 0 ..< 40 {
            let url = dir.appendingPathComponent(String(format: "f%02d.txt", i))
            try? "x".write(to: url, atomically: true, encoding: .utf8)
            items.append(FileItem.load(url: url, icon: NSWorkspace.shared.icon(forFile: url.path)))
        }

        let task = Task { try await BatchRenameService.performBatchRename(items: items, mode: .addPrefixSuffix(prefix: "R_", suffix: "")) }
        task.cancel()

        var result: BatchRenameResult?
        var threw = false
        do {
            result = try await task.value
        } catch {
            threw = true
        }
        let renamedCount = (try? FileManager.default.contentsOfDirectory(atPath: dir.path))?.filter { $0.hasPrefix("R_") }.count ?? -1
        report(
            "Feature/BatchRename",
            "POS: a cancelled performBatchRename returns a BatchRenameResult instead of throwing (R7)",
            result: !threw && result != nil)
        report(
            "Feature/BatchRename",
            "POS: the returned result's renamedURLs count matches what's actually renamed on disk",
            result: result?.renamedURLs.filter { $0.lastPathComponent.hasPrefix("R_") }.count == renamedCount)
        report(
            "Feature/BatchRename",
            "POS: cancellation before any iteration completed still leaves a well-formed (possibly empty) partial result",
            result: renamedCount >= 0 && renamedCount < items.count)
    }

    /// Bug: performBatchRename used to fall through NSRegularExpression's `try?` failure by
    /// leaving `newBaseName = baseName` - an invalid user-typed regex pattern silently pretended
    /// no rename was requested instead of telling the user their pattern was invalid. This proves
    /// performBatchRename now throws for an invalid regex pattern, and that it aborts before
    /// touching the filesystem (the file keeps its original name) rather than silently no-op'ing.
    private static func testInvalidRegexPatternThrowsInsteadOfSilentlyNoOpingRename() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("file_gamma.txt")
        try? "gamma".write(to: file, atomically: true, encoding: .utf8)
        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))

        let invalidRegexMode = BatchRenameMode.regex(pattern: "[", template: "X")

        var didThrow = false
        do {
            _ = try await BatchRenameService.performBatchRename(items: [item], mode: invalidRegexMode)
        } catch {
            didThrow = true
        }

        report(
            "Feature/BatchRename",
            "NEG: performBatchRename throws instead of silently no-oping for an invalid regex pattern",
            result: didThrow)
        report(
            "Feature/BatchRename",
            "NEG: file keeps its original name when the regex pattern is invalid",
            result: FileManager.default.fileExists(atPath: file.path))
    }

    /// B9-5: the mode's regex is now compiled once (`resolveRegex`) and shared by the preview and
    /// the rename, instead of compiling it twice. A valid pattern must still preview and perform to
    /// the same target name.
    private static func testValidRegexPatternIsResolvedOnceAndAppliedByPerform() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file = tempDir.appendingPathComponent("IMG_0042.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        let item = FileItem.load(url: file, icon: NSWorkspace.shared.icon(forFile: file.path))

        let mode = BatchRenameMode.regex(pattern: "IMG_(\\d+)", template: "photo-$1")
        let preview = BatchRenameService.previewNewNames(items: [item], mode: mode).first?.newName

        var performedName: String?
        if let result = try? await BatchRenameService.performBatchRename(items: [item], mode: mode) {
            performedName = result.renamedURLs.first?.lastPathComponent
        }

        report(
            "Feature/BatchRename",
            "POS: a valid regex pattern previews and performs to the same name (photo-0042.txt)",
            result: preview == "photo-0042.txt" && performedName == "photo-0042.txt")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
