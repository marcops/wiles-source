@testable import Wiles
import Foundation

/// Continuation of `FileSystemTests` — split out purely to stay under SwiftLint's 500-line
/// file-length limit (see `AppStateOperationsExtraTests`/`AppStateOperationsFailureTests` for the
/// same precedent). Still the same dedicated suite for `FileSystemService+Actions.swift`'s
/// `moveItem`; called from `FileSystemTests.run()`.
@MainActor
enum FileSystemMoveRegressionTests {
    // NEG (data-loss regression): moveItem's "remove existing destination before moving" branch
    // used to be unconditional — if the caller passes a folder as both the item to move AND (via
    // its current parent) the destination, destURL resolves to the exact same path as the source.
    // The old code then did `removeItem(at: destURL)` — permanently deleting the item — before
    // attempting `moveItem(at: url, to: destURL)`, which failed because `url` no longer existed,
    // surfacing a confusing "couldn't be moved... doesn't exist" error while the item was gone
    // forever (not even recoverable from Trash). This must be a safe no-op instead: the item must
    // still exist afterward, with its original contents intact.
    static func run(tempDir: URL) {
        let alreadyThereDir = tempDir.appendingPathComponent("AlreadyThere")
        try? FileManager.default.createDirectory(at: alreadyThereDir, withIntermediateDirectories: true)
        let sameFolderItem = alreadyThereDir.appendingPathComponent("dont_delete_me.txt")
        let originalContent = "precious user data \(UUID().uuidString)"
        try? originalContent.write(to: sameFolderItem, atomically: true, encoding: .utf8)

        _ = try? FileSystemService.moveItem(at: sameFolderItem, toFolder: alreadyThereDir)

        let stillExists = FileManager.default.fileExists(atPath: sameFolderItem.path)
        let contentIntact = (try? String(contentsOf: sameFolderItem)) == originalContent
        TestReporter.report(
            "FileSystem",
            "NEG: moveItem to the folder the item is already in never deletes it (regression: used to permanently destroy the item)",
            result: stillExists && contentIntact
        )
    }
}
