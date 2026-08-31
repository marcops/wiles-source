import Foundation
@testable import Wiles

/// Continuation of `FileSystemTests` — split out purely to stay under SwiftLint's 500-line
/// file-length limit (see `AppStateOperationsExtraTests`/`AppStateOperationsFailureTests` for the
/// same precedent). Still the same dedicated suite for `FileSystemService+Actions.swift`'s
/// `moveItem`; called from `FileSystemTests.run()`.
@MainActor
enum FileSystemMoveRegressionTests {
    /// NEG (data-loss regression): moveItem's "remove existing destination before moving" branch
    /// used to be unconditional — if the caller passes a folder as both the item to move AND (via
    /// its current parent) the destination, destURL resolves to the exact same path as the source.
    /// The old code then did `removeItem(at: destURL)` — permanently deleting the item — before
    /// attempting `moveItem(at: url, to: destURL)`, which failed because `url` no longer existed,
    /// surfacing a confusing "couldn't be moved... doesn't exist" error while the item was gone
    /// forever (not even recoverable from Trash). This must be a safe no-op instead: the item must
    /// still exist afterward, with its original contents intact.
    static func run(tempDir: URL) async {
        let alreadyThereDir = tempDir.appendingPathComponent("AlreadyThere")
        try? FileManager.default.createDirectory(at: alreadyThereDir, withIntermediateDirectories: true)
        let sameFolderItem = alreadyThereDir.appendingPathComponent("dont_delete_me.txt")
        let originalContent = "precious user data \(UUID().uuidString)"
        try? originalContent.write(to: sameFolderItem, atomically: true, encoding: .utf8)

        _ = try? await FileSystemService.moveItem(at: sameFolderItem, toFolder: alreadyThereDir)

        let stillExists = FileManager.default.fileExists(atPath: sameFolderItem.path)
        let contentIntact = (try? String(contentsOf: sameFolderItem)) == originalContent
        TestReporter.report(
            "FileSystem",
            "NEG: moveItem to the folder the item is already in never deletes it (regression: used to permanently destroy the item)",
            result: stillExists && contentIntact)

        await runCollisionRegression(tempDir: tempDir)
        await runReplacingReportsDisplacedTrashURL(tempDir: tempDir)
    }

    /// `moveItemReplacing` reports where the displaced file landed in the Trash so the paste path
    /// can register a `.trash` undo step for it (ML-101: a Replace used to be un-undoable).
    private static func runReplacingReportsDisplacedTrashURL(tempDir: URL) async {
        let dest = tempDir.appendingPathComponent("replacing-dest-\(UUID().uuidString)", isDirectory: true)
        let src = tempDir.appendingPathComponent("replacing-src-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        let incoming = src.appendingPathComponent("note.txt")
        let existing = dest.appendingPathComponent("note.txt")
        try? "incoming".write(to: incoming, atomically: true, encoding: .utf8)
        try? "existing".write(to: existing, atomically: true, encoding: .utf8)

        let outcome = try? await FileSystemService.moveItemReplacing(at: incoming, toFolder: dest)

        let movedIn = (try? String(contentsOf: existing)) == "incoming"
        let displacedRecoverable = outcome?.displacedTrashedURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        TestReporter.report(
            "FileSystem",
            "POS: moveItemReplacing puts the source in place and returns the still-recoverable Trash URL of the file it displaced",
            result: movedIn && displacedRecoverable)
        if let trashed = outcome?.displacedTrashedURL {
            try? FileManager.default.removeItem(at: trashed)
        }
    }

    /// C1 (data-loss regression): moving onto a name that already exists used to call
    /// `FileManager.replaceItem` — an atomic, silent overwrite. The displaced file's content was
    /// gone forever. `moveItem` now takes an explicit `onCollision` policy and never overwrites:
    /// `.failIfExists` throws and touches nothing, `.keepBoth` picks a free name. (The recoverable
    /// replace-move lives in `moveItemReplacing`, covered separately.)
    private static func runCollisionRegression(tempDir: URL) async {
        let dir = tempDir.appendingPathComponent("Collision-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let sourceDir = dir.appendingPathComponent("src")
        try? FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        func freshPair(_ label: String) -> (source: URL, existing: String) {
            let source = sourceDir.appendingPathComponent("\(label).txt")
            let existing = dir.appendingPathComponent("\(label).txt")
            try? "SOURCE \(label)".write(to: source, atomically: true, encoding: .utf8)
            try? "PRECIOUS existing \(label) \(UUID().uuidString)".write(to: existing, atomically: true, encoding: .utf8)
            return (source, (try? String(contentsOf: existing)) ?? "")
        }

        // .failIfExists (default) and .replace (no production caller — folded into fail) both throw
        // `destinationExists` and touch neither the source nor the occupant.
        for policy in [MoveCollisionPolicy.failIfExists, .replace] {
            let name = policy == .failIfExists ? "fail" : "replace"
            let (src, original) = freshPair(name)
            var threw = false
            do {
                _ = try await FileSystemService.moveItem(at: src, toFolder: dir, onCollision: policy)
            } catch WilesError.destinationExists {
                threw = true
            } catch {
                threw = false
            }
            let destIntact = (try? String(contentsOf: dir.appendingPathComponent("\(name).txt"))) == original
            let sourceIntact = FileManager.default.fileExists(atPath: src.path)
            TestReporter.report(
                "FileSystem",
                "NEG: moveItem onCollision .\(name == "fail" ? "failIfExists" : "replace") throws destinationExists and destroys nothing",
                result: threw && destIntact && sourceIntact)
        }

        // .keepBoth: source lands under a free name, existing file untouched.
        let (keepSource, keepOriginal) = freshPair("keep")
        let keptURL = try? await FileSystemService.moveItem(at: keepSource, toFolder: dir, onCollision: .keepBoth)
        let keepDestIntact = (try? String(contentsOf: dir.appendingPathComponent("keep.txt"))) == keepOriginal
        let keptRenamed: Bool = if let keptURL {
            keptURL.lastPathComponent != "keep.txt" && FileManager.default.fileExists(atPath: keptURL.path)
        } else {
            false
        }
        TestReporter.report(
            "FileSystem",
            "POS: moveItem onCollision .keepBoth renames the moved item and leaves the existing file intact",
            result: keepDestIntact && keptRenamed)
    }
}
