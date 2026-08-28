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
    }

    /// C1 (data-loss regression): moving onto a name that already exists used to call
    /// `FileManager.replaceItem` — an atomic, silent overwrite. The displaced file's content was
    /// gone forever. `moveItem` now takes an explicit `onCollision` policy and never overwrites:
    /// `.failIfExists` throws and touches nothing, `.keepBoth` picks a free name, `.replace` sends
    /// the existing file to Trash first (recoverable).
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

        // .failIfExists (default): throws, nothing touched.
        let (failSource, failOriginal) = freshPair("fail")
        var threw = false
        do {
            _ = try await FileSystemService.moveItem(at: failSource, toFolder: dir)
        } catch WilesError.destinationExists {
            threw = true
        } catch {
            threw = false
        }
        let failDestIntact = (try? String(contentsOf: dir.appendingPathComponent("fail.txt"))) == failOriginal
        let failSourceIntact = FileManager.default.fileExists(atPath: failSource.path)
        TestReporter.report(
            "FileSystem",
            "NEG: moveItem onto an existing name throws destinationExists and destroys nothing (regression: used to silently overwrite)",
            result: threw && failDestIntact && failSourceIntact)

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

        // .replace: destination ends up with the source's content, source is gone.
        let (replaceSource, _) = freshPair("replace")
        _ = try? await FileSystemService.moveItem(at: replaceSource, toFolder: dir, onCollision: .replace)
        let replacedContent = (try? String(contentsOf: dir.appendingPathComponent("replace.txt"))) ?? ""
        let sourceConsumed = !FileManager.default.fileExists(atPath: replaceSource.path)
        TestReporter.report(
            "FileSystem",
            "POS: moveItem onCollision .replace puts the source in place and consumes it",
            result: replacedContent == "SOURCE replace" && sourceConsumed)
    }
}
