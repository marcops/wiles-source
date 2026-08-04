@testable import Wiles
import Foundation

@MainActor
public struct UndoRedoTests {
    public static func run() async {
        let service = UndoRedoService.shared

        // Negative: Undo on empty stack
        let emptyUndo = await service.undo()
        TestReporter.report("UndoRedo", "NEG: undo() on empty stack returns nil", result: emptyUndo == nil)

        let emptyRedo = await service.redo()
        TestReporter.report("UndoRedo", "NEG: redo() on empty stack returns nil", result: emptyRedo == nil)

        // Positive: Record & Undo Action
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let fileA = tempDir.appendingPathComponent("fileA.txt")
        let fileB = tempDir.appendingPathComponent("fileB.txt")
        try? "Data".write(to: fileA, atomically: true, encoding: .utf8)

        let renamed = try? FileSystemService.renameItem(at: fileA, newName: "fileB.txt")
        if let newURL = renamed {
            service.recordAction(.rename(oldURL: fileA, newURL: newURL))
            TestReporter.report("UndoRedo", "POS: canUndo() is true after recording action", result: service.canUndo())

            let undoResult = await service.undo()
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

        if let movedURL = try? FileSystemService.moveItem(at: movable, toFolder: destDir) {
            service.recordAction(.move(sourceURL: movable, destinationURL: movedURL))
            let undoMove = await service.undo()
            let undoMovePos = undoMove != nil && FileManager.default.fileExists(atPath: movable.path) && !FileManager.default.fileExists(atPath: movedURL.path)
            TestReporter.report("UndoRedo", "POS: undo() reverses a move operation", result: undoMovePos)

            TestReporter.report("UndoRedo", "POS: canRedo() is true right after an undo", result: service.canRedo())
            let redoMove = await service.redo()
            let redoMovePos = redoMove != nil && FileManager.default.fileExists(atPath: movedURL.path) && !FileManager.default.fileExists(atPath: movable.path)
            TestReporter.report("UndoRedo", "POS: redo() re-applies the move operation", result: redoMovePos)
        }

        // POS: create undo/redo round trip (undoing a "create" trashes it, redoing recreates the folder)
        let createdFolderName = "created_by_test"
        if let createdURL = try? FileSystemService.createDirectory(at: tempDir, name: createdFolderName) {
            service.recordAction(.create(url: createdURL))
            let undoCreate = await service.undo()
            let undoCreatePos = undoCreate != nil && !FileManager.default.fileExists(atPath: createdURL.path)
            TestReporter.report("UndoRedo", "POS: undo() on a create action trashes the created item", result: undoCreatePos)

            let redoCreate = await service.redo()
            let redoCreatePos = redoCreate != nil && FileManager.default.fileExists(atPath: createdURL.path)
            TestReporter.report("UndoRedo", "POS: redo() on a create action recreates the folder", result: redoCreatePos)
        }

        // POS: trash undo/redo round trip
        let trashable = tempDir.appendingPathComponent("trashable.txt")
        try? "trash me".write(to: trashable, atomically: true, encoding: .utf8)
        if let trashedURL = try? FileSystemService.moveToTrash(url: trashable) {
            service.recordAction(.trash(originalURL: trashable, trashedURL: trashedURL))
            let undoTrash = await service.undo()
            let undoTrashPos = undoTrash != nil && FileManager.default.fileExists(atPath: trashable.path)
            TestReporter.report("UndoRedo", "POS: undo() on a trash action restores the file from Trash", result: undoTrashPos)
        }

        // NEG: recording a new action clears the redo stack
        service.recordAction(.rename(oldURL: fileA, newURL: fileA))
        TestReporter.report("UndoRedo", "NEG: recording a new action clears the redo stack", result: !service.canRedo())

        // NEG: undo() returns nil when the underlying file operation throws
        // (record a rename action, then externally delete the renamed file before calling undo)
        let ghostSource = tempDir.appendingPathComponent("ghostSource.txt")
        let ghostRenamed = tempDir.appendingPathComponent("ghostRenamed.txt")
        try? "ghost".write(to: ghostRenamed, atomically: true, encoding: .utf8)
        service.recordAction(.rename(oldURL: ghostSource, newURL: ghostRenamed))
        try? FileManager.default.removeItem(at: ghostRenamed) // remove the file the undo would try to rename
        let ghostUndo = await service.undo()
        TestReporter.report("UndoRedo", "NEG: undo() returns nil when the underlying file operation throws (renamed file externally deleted)", result: ghostUndo == nil)

        // POS/NEG: history is capped at maxHistoryLimit (50) - oldest actions are evicted
        while service.canUndo() { _ = await service.undo() }
        for i in 0..<51 {
            let dummyURL = tempDir.appendingPathComponent("cap_dummy_\(i).txt")
            service.recordAction(.rename(oldURL: dummyURL, newURL: dummyURL))
        }
        for _ in 0..<50 { _ = await service.undo() }
        TestReporter.report("UndoRedo", "POS: history is capped at maxHistoryLimit(50) - only 50 of 51 recorded actions remain undoable", result: !service.canUndo())

        // POS: redo() on a trash action re-trashes the restored file (executeForwardAction .trash case)
        let trashable2 = tempDir.appendingPathComponent("trashable2.txt")
        try? "trash me again".write(to: trashable2, atomically: true, encoding: .utf8)
        if let trashedURL2 = try? FileSystemService.moveToTrash(url: trashable2) {
            service.recordAction(.trash(originalURL: trashable2, trashedURL: trashedURL2))
            let undoTrash2 = await service.undo()
            let undoTrash2Pos = undoTrash2 != nil && FileManager.default.fileExists(atPath: trashable2.path)
            TestReporter.report("UndoRedo", "POS: undo() on a trash action restores the file (setup for redo)", result: undoTrash2Pos)

            let redoTrash2 = await service.redo()
            let redoTrash2Pos = redoTrash2 != nil && !FileManager.default.fileExists(atPath: trashable2.path)
            TestReporter.report("UndoRedo", "POS: redo() on a trash action re-trashes the restored file", result: redoTrash2Pos)
        }

        // NEG: redo() returns nil when the underlying forward file operation throws
        // (record a rename action, undo it back onto the undo stack via redo pending state,
        // then externally delete the file the redo would try to rename)
        let ghostSource2 = tempDir.appendingPathComponent("ghostSource2.txt")
        let ghostRenamed2 = tempDir.appendingPathComponent("ghostRenamed2.txt")
        // undo() reverses a rename by renaming the file found at newURL back to oldURL's name, so
        // the fixture file must exist at newURL (ghostRenamed2), not oldURL.
        try? "ghost2".write(to: ghostRenamed2, atomically: true, encoding: .utf8)
        service.recordAction(.rename(oldURL: ghostSource2, newURL: ghostRenamed2))
        let ghostUndo2 = await service.undo()
        let ghostUndo2Pos = ghostUndo2 != nil && FileManager.default.fileExists(atPath: ghostSource2.path)
        TestReporter.report("UndoRedo", "POS: undo() reverses rename action (setup for redo failure test)", result: ghostUndo2Pos)
        try? FileManager.default.removeItem(at: ghostSource2) // remove the file the redo would try to rename
        let ghostRedo2 = await service.redo()
        TestReporter.report("UndoRedo", "NEG: redo() returns nil when the underlying file operation throws (source file externally deleted)", result: ghostRedo2 == nil)

        // NEG: undo() on a create action whose folder was already externally removed returns nil
        let ghostCreatedURL = tempDir.appendingPathComponent("ghost_created_dir")
        service.recordAction(.create(url: ghostCreatedURL)) // never actually created on disk
        let ghostCreateUndo = await service.undo()
        TestReporter.report("UndoRedo", "NEG: undo() on a create action for a non-existent path returns nil", result: ghostCreateUndo == nil)

        try? FileManager.default.removeItem(at: tempDir)
    }
}
