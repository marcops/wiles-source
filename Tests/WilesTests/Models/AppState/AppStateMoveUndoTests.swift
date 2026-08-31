import Foundation
@testable import Wiles

/// Finding HM-146: the drag-onto-folder / breadcrumb-drop move path
/// (`moveItemsResolvingCollisions`) used to pass the no-op `onMoved`, so a drag move recorded no
/// undo at all, and a Replace sent the displaced file to the Trash with no `.trash` undo either.
/// It now records the same `.move` (+ `.trash`) entries the cut/paste loop records, via the shared
/// `recordResolvedMoveUndo` helper.
@MainActor
public struct AppStateMoveUndoTests {
    public static func run() async {
        await testPlainDragMoveRecordsMoveUndo()
        await testReplaceDragMoveRecordsTrashAndMoveUndo()
        testHelperRecordsMoveOnlyWhenNothingDisplaced()
    }

    private static func makeFile(_ name: String, in dir: URL, _ body: String = "x") -> URL {
        let url = dir.appendingPathComponent(name)
        try? body.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Drives the move-collision prompt `windowUIState` raises while `operation` is suspended on it.
    private static func withResolvedCollisionPrompt<T: Sendable>(
        _ windowUIState: WindowUIState,
        answer: MoveCollisionChoice,
        _ operation: @escaping @Sendable () async -> T) async -> T? {
        let task = Task { await operation() }
        for _ in 0 ..< 50 {
            if windowUIState.moveCollisionPrompt != nil {
                break
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        windowUIState.moveCollisionPrompt?.resolve(answer)
        return await task.value
    }

    private static func testPlainDragMoveRecordsMoveUndo() async {
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let dest = root.appendingPathComponent("Dest")
        let srcParent = root.appendingPathComponent("Src")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: srcParent, withIntermediateDirectories: true)
        let source = makeFile("note.txt", in: srcParent, "payload")

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)

        let moved = await appState.moveItemsResolvingCollisions([source], toFolder: dest, windowUIState: windowUIState)

        report(
            "AppState+Move", "POS: a clean drag-onto-folder move now records a .move undo (was: no undo)",
            result: moved.count == 1 && appState.undoRedoService.canUndo())

        _ = try? await appState.undoRedoService.undo()
        let backAtSource = FileManager.default.fileExists(atPath: source.path)
        let goneFromDest = !FileManager.default.fileExists(atPath: dest.appendingPathComponent("note.txt").path)
        report(
            "AppState+Move", "POS: ⌘Z after a drag move returns the file to where it was dragged from",
            result: backAtSource && goneFromDest)

        try? FileManager.default.removeItem(at: root)
    }

    private static func testReplaceDragMoveRecordsTrashAndMoveUndo() async {
        let root = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let dest = root.appendingPathComponent("Dest")
        let srcParent = root.appendingPathComponent("Src")
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: srcParent, withIntermediateDirectories: true)
        let source = makeFile("dup.txt", in: srcParent, "incoming")
        let existing = makeFile("dup.txt", in: dest, "PRECIOUS-\(UUID().uuidString)")

        let appState = AppState()
        let windowUIState = WindowUIState(preferences: appState.preferences)

        let moved = await withResolvedCollisionPrompt(
            windowUIState, answer: MoveCollisionChoice(action: .replace, applyToAll: false)) {
                await appState.moveItemsResolvingCollisions([source], toFolder: dest, windowUIState: windowUIState)
            } ?? []

        let replaced = (try? String(contentsOf: existing)) == "incoming"
        report(
            "AppState+Move", "POS: Replace via drag moves the incoming file into place",
            result: moved.count == 1 && replaced)

        // Two undo entries were recorded: .trash (displaced file) then .move — undoing twice
        // consumes both, undoing once still leaves the .trash entry available.
        let hadUndo = appState.undoRedoService.canUndo()
        _ = try? await appState.undoRedoService.undo()
        let stillHasUndoAfterOne = appState.undoRedoService.canUndo()
        _ = try? await appState.undoRedoService.undo()
        let noUndoAfterTwo = !appState.undoRedoService.canUndo()
        report(
            "AppState+Move", "POS: a Replace drag records exactly two undo steps (.trash + .move), not zero",
            result: hadUndo && stillHasUndoAfterOne && noUndoAfterTwo)

        try? FileManager.default.removeItem(at: root)
    }

    private static func testHelperRecordsMoveOnlyWhenNothingDisplaced() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let appState = AppState()
        let src = tmp.appendingPathComponent("a-\(UUID().uuidString).txt")
        let dst = tmp.appendingPathComponent("b-\(UUID().uuidString).txt")

        appState.recordResolvedMoveUndo(source: src, dest: dst, displacedTrashedURL: nil)
        report(
            "AppState+Move", "POS: recordResolvedMoveUndo with no displaced file records an undo step",
            result: appState.undoRedoService.canUndo())

        let displaced = tmp.appendingPathComponent("c-\(UUID().uuidString).txt")
        let fresh = AppState()
        fresh.recordResolvedMoveUndo(source: src, dest: dst, displacedTrashedURL: displaced)
        report(
            "AppState+Move", "POS: recordResolvedMoveUndo with a displaced file also records undo (.trash + .move)",
            result: fresh.undoRedoService.canUndo())
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
