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
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
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

        try? FileManager.default.removeItem(at: tempDir)
    }
}
