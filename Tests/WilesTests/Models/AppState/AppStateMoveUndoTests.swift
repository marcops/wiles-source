import Foundation
@testable import Wiles

/// Finding HM-146: the drag-onto-folder / breadcrumb-drop move path
/// (`moveItemsResolvingCollisions`) used to pass the no-op `onMoved`, so a drag move recorded no
/// undo at all, and a Replace sent the displaced file to the Trash with no `.trash` undo either.
/// It now records the same `.move` (+ `.trash`) entries the cut/paste loop records, via the shared
/// `resolvedMoveUndoActions` helper — grouped into ONE undo entry per drag (HH-089).
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

        // One grouped undo entry covers the whole Replace drag (.trash of the displaced file + the
        // .move) — a single ⌘Z reverts both and leaves nothing further to undo (HH-089).
        let hadUndo = appState.undoRedoService.canUndo()
        _ = try? await appState.undoRedoService.undo()
        let noUndoAfterOne = !appState.undoRedoService.canUndo()
        let incomingBackAtSource = FileManager.default.fileExists(atPath: source.path)
        // The displaced "PRECIOUS-" file comes back into `dest/` — under `dup.txt` when free, or a
        // `dup 2.txt`-style free name if the Trash renamed it on the way in (MM-091 behaviour).
        let displacedRestored = (((try? FileManager.default.contentsOfDirectory(atPath: dest.path)) ?? [])
            .contains { ((try? String(contentsOf: dest.appendingPathComponent($0))) ?? "").hasPrefix("PRECIOUS-") })
        report("AppState+Move", "POS: Replace drag is undoable in one ⌘Z (nothing further to undo after)", result: hadUndo && noUndoAfterOne)
        report("AppState+Move", "POS: ⌘Z on a Replace drag returns the incoming file to the drag source", result: incomingBackAtSource)
        report("AppState+Move", "POS: ⌘Z on a Replace drag restores the file the Replace displaced", result: displacedRestored)

        try? FileManager.default.removeItem(at: root)
    }

    private static func testHelperRecordsMoveOnlyWhenNothingDisplaced() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
        let appState = AppState()
        let src = tmp.appendingPathComponent("a-\(UUID().uuidString).txt")
        let dst = tmp.appendingPathComponent("b-\(UUID().uuidString).txt")

        let noDisplaced = appState.resolvedMoveUndoActions(source: src, dest: dst, displacedTrashedURL: nil)
        appState.undoRedoService.recordActions(noDisplaced)
        report(
            "AppState+Move", "POS: resolvedMoveUndoActions with no displaced file is one .move action",
            result: noDisplaced.count == 1 && appState.undoRedoService.canUndo())

        let displaced = tmp.appendingPathComponent("c-\(UUID().uuidString).txt")
        let fresh = AppState()
        let withDisplaced = fresh.resolvedMoveUndoActions(source: src, dest: dst, displacedTrashedURL: displaced)
        fresh.undoRedoService.recordActions(withDisplaced)
        report(
            "AppState+Move", "POS: resolvedMoveUndoActions with a displaced file is [.trash, .move]",
            result: withDisplaced.count == 2 && fresh.undoRedoService.canUndo())
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
