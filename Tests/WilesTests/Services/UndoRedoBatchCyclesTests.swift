import AppKit
import Foundation
@testable import Wiles

/// `UndoRedoTests` checks for the `.batch` cyclic-rename staging (MM-070) and the non-redoable
/// `.createFolder` reverse (LL-080). Split out of `UndoRedoTests.swift` to stay under `file_length`.
@MainActor
extension UndoRedoTests {
    static func runBatchAndCreateFolderChecks(tempDir: URL) async {
        await testCreateFolderUndoIsNotRedoableWhenFolderGainedContents(tempDir: tempDir)
        await testUndoAndRedoOfACyclicBatchRenameRoundTripExactly(tempDir: tempDir)
    }

    /// Finding LL-080: undoing `.createFolder` trashes the folder — but if an external process
    /// dropped a file into it after creation, redoing via `createDirectory` would resurrect an empty
    /// shell while the real contents stay in the Trash. Undo of a folder that is non-empty at reverse
    /// time must therefore leave NO redo entry (mirrors `.createFile`), so ⌘⇧Z is a silent no-op.
    private static func testCreateFolderUndoIsNotRedoableWhenFolderGainedContents(tempDir: URL) async {
        // A fresh service — the shared suite one may hold a deliberately-unundoable record from an
        // earlier test, and draining that spins forever (undo() re-pushes a failed record).
        let service = UndoRedoService()

        guard let createdURL = try? await FileSystemService.createDirectory(
            at: tempDir, name: "folder_that_gains_contents") else {
            TestReporter.report("UndoRedo", "LL-080: setup — createDirectory succeeded", result: false)
            return
        }
        service.recordAction(.createFolder(url: createdURL))
        // An external process writes into the folder between creation and the undo.
        try? "leaked".write(
            to: createdURL.appendingPathComponent("added_externally.txt"), atomically: true, encoding: .utf8)

        let undo = try? await service.undo()
        TestReporter.report(
            "UndoRedo",
            "POS (LL-080): undo() of a non-empty createFolder still trashes the folder",
            result: undo != nil && !FileManager.default.fileExists(atPath: createdURL.path))
        TestReporter.report(
            "UndoRedo",
            "POS (LL-080): undoing a createFolder that gained contents leaves nothing on the redo stack",
            result: !service.canRedo())

        var redoThrew = false
        var redoResult: URL?
        do { redoResult = try await service.redo() } catch { redoThrew = true }
        TestReporter.report(
            "UndoRedo",
            "NEG (LL-080): redo() after that undo is a silent no-op — no empty shell recreated",
            result: !redoThrew && redoResult == nil && !FileManager.default.fileExists(atPath: createdURL.path))
    }

    /// Finding MM-070: a batch-rename that rotated names (`r2, r3, r1` → `r1, r2, r3`) is recorded as
    /// a `.batch` of `.rename` pairs. Reversing them one by one hit `.keepBoth` (the target name is
    /// still held by a sibling) and stranded 2 of 3 files on `… 2`. `undoBatch`/`redoBatch` now stage
    /// a colliding rename permutation through hidden temps, so ⌘Z and ⌘⇧Z round-trip exactly.
    private static func testUndoAndRedoOfACyclicBatchRenameRoundTripExactly(tempDir: URL) async {
        let dir = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let service = UndoRedoService()

        // Names chosen so `.sequenceNumber(prefix: "r", …)` (which emits `r_1, r_2, r_3`) maps this
        // set onto itself — a rotation. Distinct contents so identity is verifiable through it.
        let startNames = ["r_2", "r_3", "r_1"]
        for name in startNames {
            try? "content-\(name)".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let items = startNames.map { name in
            FileItem.load(url: dir.appendingPathComponent(name), icon: NSWorkspace.shared.icon(forFile: dir.path))
        }

        func contents() -> [String: String] {
            var map: [String: String] = [:]
            for name in ["r_1", "r_2", "r_3"] {
                map[name] = try? String(contentsOf: dir.appendingPathComponent(name), encoding: .utf8)
            }
            return map
        }
        let beforeRename = contents()

        guard let result = try? await BatchRenameService.performBatchRename(
            items: items, mode: .sequenceNumber(prefix: "r", startNumber: 1, paddingDigits: 1)),
            result.failures.isEmpty, result.renamedPairs.count == 3,
            Set(result.renamedPairs.map(\.old.lastPathComponent))
            == Set(result.renamedPairs.map(\.new.lastPathComponent)) else {
            TestReporter.report("UndoRedo", "POS (MM-070): setup applied a name-permuting batch rename", result: false)
            return
        }
        service.recordActions(result.renamedPairs.map { .rename(oldURL: $0.old, newURL: $0.new) })

        let afterRename = contents()
        let forwardOK = afterRename.count == 3 && afterRename != beforeRename

        _ = try? await service.undo()
        let undoRestoredExactly = contents() == beforeRename
        let noKeepBothSuffix = ((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
            .allSatisfy { !$0.contains(" 2") && !$0.hasPrefix(".wiles-batch-rename-") }

        _ = try? await service.redo()
        let redoReappliedExactly = contents() == afterRename

        TestReporter.report("UndoRedo", "POS (MM-070): the cyclic batch rename applied as a rotation", result: forwardOK)
        TestReporter.report(
            "UndoRedo",
            "POS (MM-070): ⌘Z of a cyclic batch rename restores every file to its exact original name",
            result: undoRestoredExactly)
        TestReporter.report(
            "UndoRedo",
            "NEG (MM-070): the undo leaves no \" 2\" keep-both name and no stranded staging temp",
            result: noKeepBothSuffix)
        TestReporter.report(
            "UndoRedo",
            "POS (MM-070): ⌘⇧Z re-applies the rotation exactly",
            result: redoReappliedExactly)

        try? FileManager.default.removeItem(at: dir)
    }
}
