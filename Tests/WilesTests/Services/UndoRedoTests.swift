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

        try? FileManager.default.removeItem(at: tempDir)
    }
}
