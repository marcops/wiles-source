import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct UndoRedoTests {
    public static func run() async {
        let service = UndoRedoService()

        await testEmptyStackOperations(service: service)

        // Positive: Record & Undo Action
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileA = tempDir.appendingPathComponent("fileA.txt")
        try? "Data".write(to: fileA, atomically: true, encoding: .utf8)

        await testRenameAndMoveRoundTrip(service: service, tempDir: tempDir, fileA: fileA)
        await testCreateTrashAndHistoryCap(service: service, tempDir: tempDir, fileA: fileA)
        await testCreateFileRedoThrowsExplicitError(service: service, tempDir: tempDir)
        await testCreateFolderUndoIsNotRedoableWhenFolderGainedContents(service: service, tempDir: tempDir)
        await testHistoryCap(service: service, tempDir: tempDir)
        await testTrashRedoAndGhostFailures(service: service, tempDir: tempDir)
        await testFailedUndoDoesNotCorruptStack(service: service, tempDir: tempDir)
        await testRelocationHookFiresOnMoveUndoRedo(tempDir: tempDir)
        await testUndoOfMoveRemapsFavorites(tempDir: tempDir)
        await testConcurrentUndoConsumesOnlyOneStep(tempDir: tempDir)
        await testChmodUndoRestoresPreviousPermissions(tempDir: tempDir)
        await testRestoreDivergenceFiresWhenOriginalNameIsTaken(tempDir: tempDir)
        await testRestoreDivergenceSilentOnCleanUndo(tempDir: tempDir)
        await testUndoAndRedoOfACyclicBatchRenameRoundTripExactly(tempDir: tempDir)

        try? FileManager.default.removeItem(at: tempDir)
    }

    /// MM-091: undoing `A`→`B` after a new `A` was created can't restore the file as `A` (taken),
    /// so `.keepBoth` lands it on `A 2`. The step still succeeds, but `onRestoreDiverged` must fire
    /// so the user isn't left believing the state was fully reverted.
    private static func testRestoreDivergenceFiresWhenOriginalNameIsTaken(tempDir: URL) async {
        let service = UndoRedoService()
        let dir = tempDir.appendingPathComponent("diverge-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = dir.appendingPathComponent("A.txt")
        try? "payload".write(to: original, atomically: true, encoding: .utf8)

        let renamed = await (try? FileSystemService.renameItem(at: original, newName: "B.txt")) ?? original
        service.recordAction(.rename(oldURL: original, newURL: renamed))
        // The original name is re-taken before the undo runs.
        try? "squatter".write(to: original, atomically: true, encoding: .utf8)

        var reported: (intended: String, actual: String)?
        service.onRestoreDiverged = { intended, actual in reported = (intended, actual) }

        let result = try? await service.undo()

        let firedWithRightNames = reported?.intended == "A.txt" && (reported?.actual.hasPrefix("A ") ?? false)
        let landedOnFreeName = result?.lastPathComponent != "A.txt" && result != nil
        TestReporter.report(
            "UndoRedo",
            "POS: onRestoreDiverged fires (intended 'A.txt', actual 'A 2.txt') when undo can't reclaim the original name",
            result: firedWithRightNames && landedOnFreeName)
    }

    /// The signal must NOT fire on a normal undo where the original name is free.
    private static func testRestoreDivergenceSilentOnCleanUndo(tempDir: URL) async {
        let service = UndoRedoService()
        let dir = tempDir.appendingPathComponent("noverge-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let original = dir.appendingPathComponent("X.txt")
        try? "x".write(to: original, atomically: true, encoding: .utf8)

        let renamed = await (try? FileSystemService.renameItem(at: original, newName: "Y.txt")) ?? original
        service.recordAction(.rename(oldURL: original, newURL: renamed))

        var fired = false
        service.onRestoreDiverged = { _, _ in fired = true }
        let result = try? await service.undo()

        TestReporter.report(
            "UndoRedo",
            "NEG: onRestoreDiverged stays silent when undo restores the file under its original name",
            result: !fired && result?.lastPathComponent == "X.txt")
    }

    /// A second ⌘Z fired while the first is still mid-`await` must be rejected, not pop the next
    /// record and run both reverse actions interleaved.
    private static func testConcurrentUndoConsumesOnlyOneStep(tempDir: URL) async {
        let service = UndoRedoService()
        let one = tempDir.appendingPathComponent("concurrent-1.txt")
        let two = tempDir.appendingPathComponent("concurrent-2.txt")
        try? "1".write(to: one, atomically: true, encoding: .utf8)
        try? "2".write(to: two, atomically: true, encoding: .utf8)
        let oneRenamed = try? await FileSystemService.renameItem(at: one, newName: "concurrent-1b.txt")
        let twoRenamed = try? await FileSystemService.renameItem(at: two, newName: "concurrent-2b.txt")
        service.recordAction(.rename(oldURL: one, newURL: oneRenamed ?? one))
        service.recordAction(.rename(oldURL: two, newURL: twoRenamed ?? two))

        async let first = service.undo()
        async let second = service.undo()
        _ = try? await first
        _ = try? await second

        TestReporter.report(
            "UndoRedo",
            "POS: two concurrent undo() calls consume exactly one step (the second is rejected while the first runs)",
            result: service.canUndo())
    }

    private static func testChmodUndoRestoresPreviousPermissions(tempDir: URL) async {
        let service = UndoRedoService()
        let file = tempDir.appendingPathComponent("chmod-target.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)
        guard let original = FilePermissionsService.getPermissions(for: file) else {
            TestReporter.report("UndoRedo", "SKIP: could not read permissions for the chmod test target", result: true)
            return
        }

        var changed = original
        changed.othersWrite.toggle()
        try? FilePermissionsService.setPermissions(for: file, permissions: changed)
        service.recordAction(.chmod(url: file, previous: original))

        _ = try? await service.undo()
        let afterUndo = FilePermissionsService.getPermissions(for: file)
        TestReporter.report(
            "UndoRedo",
            "POS: undoing a .chmod restores the file's previous POSIX permissions",
            result: afterUndo == original)

        _ = try? await service.redo()
        let afterRedo = FilePermissionsService.getPermissions(for: file)
        TestReporter.report(
            "UndoRedo",
            "POS: redoing a .chmod re-applies the changed permissions",
            result: afterRedo == changed)
    }

    /// `onFileRelocated` must fire for every undo/redo step that moves a file on disk, with the
    /// pre- and post-relocation URLs — this is what lets `AppState` keep favorites in sync.
    private static func testRelocationHookFiresOnMoveUndoRedo(tempDir: URL) async {
        let service = UndoRedoService()
        var relocations: [(from: URL, to: URL)] = []
        service.onFileRelocated = { from, to in relocations.append((from, to)) }

        let src = tempDir.appendingPathComponent("hook-src", isDirectory: true)
        let dst = tempDir.appendingPathComponent("hook-dst", isDirectory: true)
        try? FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        let file = src.appendingPathComponent("f.txt")
        try? "x".write(to: file, atomically: true, encoding: .utf8)

        guard let moved = try? await FileSystemService.moveItem(at: file, toFolder: dst) else {
            TestReporter.report("UndoRedo", "POS: onFileRelocated fires on move undo/redo", result: false)
            return
        }
        service.recordAction(.move(sourceURL: file, destinationURL: moved))
        _ = try? await service.undo()
        _ = try? await service.redo()

        let undoHop = relocations.first
        let redoHop = relocations.count >= 2 ? relocations[1] : nil
        let ok = undoHop?.from == moved && undoHop?.to == file
            && redoHop?.from == file && redoHop?.to == moved
        TestReporter.report("UndoRedo", "POS: onFileRelocated reports (from,to) for both the move undo and redo", result: ok)
    }

    /// End-to-end: undoing the move of a favorited folder must leave the favorite pointing at the
    /// folder's restored location, not the now-empty post-move path.
    private static func testUndoOfMoveRemapsFavorites(tempDir: URL) async {
        let appState = AppState()
        let src = tempDir.appendingPathComponent("fav-src", isDirectory: true)
        let dst = tempDir.appendingPathComponent("fav-dst", isDirectory: true)
        try? FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        let favFolder = src.appendingPathComponent("Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: favFolder, withIntermediateDirectories: true)

        appState.preferences.favorites.favoriteURLs = [favFolder.standardizedFileURL]
        guard let moved = try? await appState.moveItem(at: favFolder, toFolder: dst) else {
            TestReporter.report("UndoRedo", "POS: undo of a favorited folder's move remaps the favorite", result: false)
            return
        }
        appState.undoRedoService.recordAction(.move(sourceURL: favFolder, destinationURL: moved))
        _ = try? await appState.undoRedoService.undo()

        let favNowPointsBack = appState.preferences.favorites.favoriteURLs.map { $0.resolvingSymlinksInPath().path }
            == [favFolder.resolvingSymlinksInPath().path]
        TestReporter.report(
            "UndoRedo",
            "POS: undo of a favorited folder's move remaps the favorite to its restored path",
            result: favNowPointsBack)
    }

    /// `service` is a fresh instance owned only by this test run, but undo()/redo() always relocate
    /// a record to the opposite stack rather than discarding it — so only assert the nil-on-empty
    /// behavior when the stack is verifiably empty going in.
    private static func testEmptyStackOperations(service: UndoRedoService) async {
        if !service.canUndo() {
            do {
                let emptyUndo = try await service.undo()
                TestReporter.report("UndoRedo", "NEG: undo() on empty stack returns nil", result: emptyUndo == nil)
            } catch {
                TestReporter.report("UndoRedo", "NEG: undo() on empty stack returns nil", result: false)
            }
        }

        if !service.canRedo() {
            do {
                let emptyRedo = try await service.redo()
                TestReporter.report("UndoRedo", "NEG: redo() on empty stack returns nil", result: emptyRedo == nil)
            } catch {
                TestReporter.report("UndoRedo", "NEG: redo() on empty stack returns nil", result: false)
            }
        }
    }

    private static func testRenameAndMoveRoundTrip(service: UndoRedoService, tempDir: URL, fileA: URL) async {
        let fileB = tempDir.appendingPathComponent("fileB.txt")

        let renamed = try? await FileSystemService.renameItem(at: fileA, newName: "fileB.txt")
        if let newURL = renamed {
            service.recordAction(.rename(oldURL: fileA, newURL: newURL))
            TestReporter.report("UndoRedo", "POS: canUndo() is true after recording action", result: service.canUndo())

            let undoResult = try? await service.undo()
            let undoPos = undoResult != nil && FileManager.default.fileExists(atPath: fileA.path) && !FileManager.default.fileExists(atPath: fileB.path)
            TestReporter.report("UndoRedo", "POS: undo() reverses rename operation", result: undoPos)
        }

        // POS: move undo/redo round trip
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")
        try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        let movable = sourceDir.appendingPathComponent("movable.txt")
        try? "move me".write(to: movable, atomically: true, encoding: .utf8)

        if let movedURL = try? await FileSystemService.moveItem(at: movable, toFolder: destDir) {
            service.recordAction(.move(sourceURL: movable, destinationURL: movedURL))
            let undoMove = try? await service.undo()
            let undoMovePos = undoMove != nil && FileManager.default.fileExists(atPath: movable.path) && !FileManager.default.fileExists(atPath: movedURL.path)
            TestReporter.report("UndoRedo", "POS: undo() reverses a move operation", result: undoMovePos)

            TestReporter.report("UndoRedo", "POS: canRedo() is true right after an undo", result: service.canRedo())
            let redoMove = try? await service.redo()
            let redoMovePos = redoMove != nil && FileManager.default.fileExists(atPath: movedURL.path) && !FileManager.default.fileExists(atPath: movable.path)
            TestReporter.report("UndoRedo", "POS: redo() re-applies the move operation", result: redoMovePos)
        }
    }

    private static func testCreateTrashAndHistoryCap(service: UndoRedoService, tempDir: URL, fileA _: URL) async {
        // POS: create undo/redo round trip (undoing a "create" trashes it, redoing recreates the folder)
        let createdFolderName = "created_by_test"
        if let createdURL = try? await FileSystemService.createDirectory(at: tempDir, name: createdFolderName) {
            service.recordAction(.createFolder(url: createdURL))
            let undoCreate = try? await service.undo()
            let undoCreatePos = undoCreate != nil && !FileManager.default.fileExists(atPath: createdURL.path)
            TestReporter.report("UndoRedo", "POS: undo() on a create action trashes the created item", result: undoCreatePos)

            let redoCreate = try? await service.redo()
            let redoCreatePos = redoCreate != nil && FileManager.default.fileExists(atPath: createdURL.path)
            TestReporter.report("UndoRedo", "POS: redo() on a create action recreates the folder", result: redoCreatePos)
        }

        // POS: trash undo/redo round trip
        let trashable = tempDir.appendingPathComponent("trashable.txt")
        try? "trash me".write(to: trashable, atomically: true, encoding: .utf8)
        if let trashedURL = try? await FileSystemService.moveToTrash(url: trashable) {
            service.recordAction(.trash(originalURL: trashable, trashedURL: trashedURL))
            let undoTrash = try? await service.undo()
            let undoTrashPos = undoTrash != nil && FileManager.default.fileExists(atPath: trashable.path)
            TestReporter.report("UndoRedo", "POS: undo() on a trash action restores the file from Trash", result: undoTrashPos)
        }

        // NEG: recording a new action clears the redo stack. Must back this with a real,
        // successfully-completed rename (not a no-op self-rename on a URL that may no longer
        // exist) — the drain loop below undoes every queued record for real, and Fix 2's retry
        // semantics re-push any record whose undo fails, so a permanently-unrecoverable dummy
        // record here would make that loop spin forever.
        let redoClearDummy = tempDir.appendingPathComponent("redo_clear_dummy.txt")
        try? "x".write(to: redoClearDummy, atomically: true, encoding: .utf8)
        if let renamedDummy = try? await FileSystemService.renameItem(at: redoClearDummy, newName: "redo_clear_dummy_renamed.txt") {
            service.recordAction(.rename(oldURL: redoClearDummy, newURL: renamedDummy))
        }
        TestReporter.report("UndoRedo", "NEG: recording a new action clears the redo stack", result: !service.canRedo())
    }

    /// Regression coverage for the `.create(url:)` → `.createFolder`/`.createFile` split plus
    /// finding ML-135: `.createFile`'s content was never stored, so undoing a file creation must
    /// NOT leave a redo entry behind — ⌘⇧Z afterwards is a silent no-op, not a re-thrown
    /// `fileCreationNotRedoable` error that also stays stuck on the redo stack. (`.createFolder`'s
    /// redo still recreates fine, covered by `testCreateTrashAndHistoryCap` above.)
    private static func testCreateFileRedoThrowsExplicitError(service: UndoRedoService, tempDir: URL) async {
        let createdFile = tempDir.appendingPathComponent("created_by_test.txt")
        try? "created file content".write(to: createdFile, atomically: true, encoding: .utf8)
        service.recordAction(.createFile(url: createdFile))

        let undoCreateFile = try? await service.undo()
        let undoCreateFilePos = undoCreateFile != nil && !FileManager.default.fileExists(atPath: createdFile.path)
        TestReporter.report("UndoRedo", "POS: undo() on a createFile action trashes the created file", result: undoCreateFilePos)

        TestReporter.report(
            "UndoRedo",
            "POS: undoing a createFile leaves nothing on the redo stack (ML-135)",
            result: !service.canRedo())

        var redoThrew = false
        var redoResult: URL?
        do {
            redoResult = try await service.redo()
        } catch {
            redoThrew = true
        }
        TestReporter.report(
            "UndoRedo",
            "POS: redo() after an undone createFile is a silent no-op — returns nil, throws nothing (ML-135)",
            result: !redoThrew && redoResult == nil)
        TestReporter.report(
            "UndoRedo",
            "NEG: redo() after an undone createFile does not recreate a file/folder at the former path",
            result: !FileManager.default.fileExists(atPath: createdFile.path))
    }

    /// Finding LL-080: undoing `.createFolder` trashes the folder — but if an external process
    /// dropped a file into it after creation, redoing via `createDirectory` would resurrect an empty
    /// shell while the real contents stay in the Trash. Undo of a folder that is non-empty at reverse
    /// time must therefore leave NO redo entry (mirrors `.createFile`), so ⌘⇧Z is a silent no-op.
    private static func testCreateFolderUndoIsNotRedoableWhenFolderGainedContents(
        service: UndoRedoService, tempDir: URL) async {
        while service.canUndo() { _ = try? await service.undo() }

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

        while service.canUndo() { _ = try? await service.undo() }
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
            Set(result.renamedPairs.map { $0.old.lastPathComponent })
                == Set(result.renamedPairs.map { $0.new.lastPathComponent }) else {
            TestReporter.report("UndoRedo", "POS (MM-070): setup applied a name-permuting batch rename", result: false)
            return
        }
        service.recordActions(result.renamedPairs.map { .rename(oldURL: $0.old, newURL: $0.new) })

        let afterRename = contents()
        let forwardOK = afterRename.values.allSatisfy { $0 != nil } && afterRename != beforeRename

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

    private static func testHistoryCap(service: UndoRedoService, tempDir: URL) async {
        // POS/NEG: history is capped at maxHistoryLimit (50) - oldest actions are evicted.
        // NOTE: this drain relies on every queued record undoing successfully - it must run
        // before any test that deliberately poisons the stack with a record that fails to
        // undo, otherwise the failed record gets re-pushed on every attempt (Fix 2's retry
        // semantics) and this loop would never terminate.
        while service.canUndo() {
            _ = try? await service.undo()
        }
        // Each dummy must be a real, undo-able rename (not a same-URL self-rename, which always
        // fails and — under Fix 2's retry semantics — gets re-pushed onto the same stack position
        // forever instead of ever being removed) so the 50 undo() calls below genuinely shrink the
        // stack by one each time, leaving exactly 1 of the 51.
        for i in 0 ..< 51 {
            let dummyURL = tempDir.appendingPathComponent("cap_dummy_\(i).txt")
            let dummyRenamedURL = tempDir.appendingPathComponent("cap_dummy_\(i)_renamed.txt")
            try? "x".write(to: dummyRenamedURL, atomically: true, encoding: .utf8)
            service.recordAction(.rename(oldURL: dummyURL, newURL: dummyRenamedURL))
        }
        for _ in 0 ..< 50 {
            _ = try? await service.undo()
        }
        TestReporter.report(
            "UndoRedo",
            "POS: history is capped at maxHistoryLimit(50) - only 50 of 51 recorded actions remain undoable",
            result: !service.canUndo())

        // Drain the one remaining (real, undo-able) record so it doesn't leak into later tests in
        // this file.
        while service.canUndo() {
            _ = try? await service.undo()
        }
    }

    private static func testTrashRedoAndGhostFailures(service: UndoRedoService, tempDir: URL) async {
        // POS: redo() on a trash action re-trashes the restored file (executeForwardAction .trash case)
        let trashable2 = tempDir.appendingPathComponent("trashable2.txt")
        let trashFolder = tempDir.appendingPathComponent("trash_dir")
        try? FileManager.default.createDirectory(at: trashFolder, withIntermediateDirectories: true)
        let simulatedTrash2 = trashFolder.appendingPathComponent("trashable2.txt")
        try? "trash me again".write(to: simulatedTrash2, atomically: true, encoding: .utf8)
        service.recordAction(.trash(originalURL: trashable2, trashedURL: simulatedTrash2))

        let undoTrash2 = try? await service.undo()
        let undoTrash2Pos = undoTrash2 != nil && FileManager.default.fileExists(atPath: trashable2.path)
        TestReporter.report("UndoRedo", "POS: undo() on a trash action restores the file (setup for redo)", result: undoTrash2Pos)

        let redoTrash2 = try? await service.redo()
        let redoTrash2Pos = redoTrash2 != nil && !FileManager.default.fileExists(atPath: trashable2.path)
        TestReporter.report("UndoRedo", "POS: redo() on a trash action re-trashes the restored file", result: redoTrash2Pos)

        // NEG: redo() throws when the underlying forward file operation fails
        // (record a rename action, undo it back onto the undo stack via redo pending state,
        // then externally delete the file the redo would try to rename)
        let ghostSource2 = tempDir.appendingPathComponent("ghostSource2.txt")
        let ghostRenamed2 = tempDir.appendingPathComponent("ghostRenamed2.txt")
        // undo() reverses a rename by renaming the file found at newURL back to oldURL's name, so
        // the fixture file must exist at newURL (ghostRenamed2), not oldURL.
        try? "ghost2".write(to: ghostRenamed2, atomically: true, encoding: .utf8)
        service.recordAction(.rename(oldURL: ghostSource2, newURL: ghostRenamed2))
        let ghostUndo2 = try? await service.undo()
        let ghostUndo2Pos = ghostUndo2 != nil && FileManager.default.fileExists(atPath: ghostSource2.path)
        TestReporter.report("UndoRedo", "POS: undo() reverses rename action (setup for redo failure test)", result: ghostUndo2Pos)
        try? FileManager.default.removeItem(at: ghostSource2) // remove the file the redo would try to rename

        var ghostRedo2Threw = false
        do {
            _ = try await service.redo()
        } catch {
            ghostRedo2Threw = true
        }
        TestReporter.report("UndoRedo", "NEG: redo() throws when the underlying file operation fails (source file externally deleted)", result: ghostRedo2Threw)

        // NEG: undo() throws for a create action whose folder was already externally removed
        let ghostCreatedURL = tempDir.appendingPathComponent("ghost_created_dir")
        service.recordAction(.createFolder(url: ghostCreatedURL)) // never actually created on disk
        var ghostCreateUndoThrew = false
        do {
            _ = try await service.undo()
        } catch {
            ghostCreateUndoThrew = true
        }
        TestReporter.report("UndoRedo", "NEG: undo() on a create action for a non-existent path throws", result: ghostCreateUndoThrew)
    }

    /// Fix 2 regression coverage: undo()/redo() must (a) propagate errors instead of silently
    /// swallowing them, and (b) only push a record onto the opposite stack AFTER the reverse/
    /// forward action actually succeeds - a failed undo must not corrupt the stack into a bogus
    /// available redo. This must run last: a failed undo re-pushes its record back onto the undo
    /// stack for retry, and nothing after this function relies on `service`'s stack being empty.
    private static func testFailedUndoDoesNotCorruptStack(service: UndoRedoService, tempDir: URL) async {
        let ghostSource = tempDir.appendingPathComponent("corruption_ghost_source.txt")
        let ghostRenamed = tempDir.appendingPathComponent("corruption_ghost_renamed.txt")
        try? "ghost".write(to: ghostRenamed, atomically: true, encoding: .utf8)

        service.recordAction(.rename(oldURL: ghostSource, newURL: ghostRenamed))
        let redoStackWasEmptyBeforeFailure = !service.canRedo()

        try? FileManager.default.removeItem(at: ghostRenamed) // simulate external interference

        var undoThrew = false
        do {
            _ = try await service.undo()
        } catch {
            undoThrew = true
        }
        TestReporter.report(
            "UndoRedo", "NEG: undo() propagates (throws) an error instead of silently swallowing it when the underlying rename fails",
            result: undoThrew)

        TestReporter.report(
            "UndoRedo", "NEG: a failed undo() does not push its record onto the redo stack (no stack corruption)",
            result: redoStackWasEmptyBeforeFailure && !service.canRedo())

        // redo() must be a no-op after the failed undo, not attempt to redo a rename that never happened.
        do {
            let bogusRedo = try await service.redo()
            TestReporter.report(
                "UndoRedo", "POS: redo() after a failed undo() is a no-op instead of attempting a bogus redo",
                result: bogusRedo == nil)
        } catch {
            TestReporter.report(
                "UndoRedo", "POS: redo() after a failed undo() is a no-op instead of attempting a bogus redo",
                result: false)
        }
    }
}
