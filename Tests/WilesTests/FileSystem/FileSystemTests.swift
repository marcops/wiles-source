@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FileSystemTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Positive: Folder Creation
        let createdDir = try? FileSystemService.createDirectory(at: tempDir, name: "TestFolder")
        TestReporter.report("FileSystem", "POS: createDirectory", result: createdDir.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)

        // Positive: File Creation
        let testFile = tempDir.appendingPathComponent("sample.txt")
        try? "Sample Data".write(to: testFile, atomically: true, encoding: .utf8)
        TestReporter.report("FileSystem", "POS: File creation", result: FileManager.default.fileExists(atPath: testFile.path))

        // Positive: Rename
        let renamedFile = try? FileSystemService.renameItem(at: testFile, newName: "renamed_sample.txt")
        TestReporter.report("FileSystem", "POS: renameItem", result: renamedFile.map { FileManager.default.fileExists(atPath: $0.path) } ?? false)

        // Negative: Rename Non-Existent File
        var negRenamePassed = false
        do {
            let fakeURL = tempDir.appendingPathComponent("fake_file.txt")
            _ = try FileSystemService.renameItem(at: fakeURL, newName: "should_fail.txt")
        } catch {
            negRenamePassed = true
        }
        TestReporter.report("FileSystem", "NEG: renameItem on non-existent path throws error", result: negRenamePassed)

        // Negative: Move to Non-Existent Target Folder
        var negMovePassed = false
        do {
            if let renamed = renamedFile {
                let fakeFolder = tempDir.appendingPathComponent("NonExistentFolder")
                _ = try FileSystemService.moveItem(at: renamed, toFolder: fakeFolder)
            }
        } catch {
            negMovePassed = true
        }
        TestReporter.report("FileSystem", "NEG: moveItem to non-existent folder throws error", result: negMovePassed)

        try? FileManager.default.removeItem(at: tempDir)

        runActionsCoverageExtras()
    }

    private static func runActionsCoverageExtras() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // POS: copyItem copies file and leaves source intact
        let copySource = tempDir.appendingPathComponent("copy_source.txt")
        try? "copy me".write(to: copySource, atomically: true, encoding: .utf8)
        let copyTargetFolder = tempDir.appendingPathComponent("CopyTarget")
        try? FileManager.default.createDirectory(at: copyTargetFolder, withIntermediateDirectories: true)
        var copyPassed = false
        do {
            let copied = try FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
            let sourceStillExists = FileManager.default.fileExists(atPath: copySource.path)
            let destExists = FileManager.default.fileExists(atPath: copied.path)
            copyPassed = sourceStillExists && destExists
        } catch {
            print("copyItem error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: copyItem copies file to target folder while preserving the source", result: copyPassed)

        // NEG: copyItem to a non-existent folder throws
        var negCopyPassed = false
        do {
            let fakeFolder = tempDir.appendingPathComponent("NoSuchFolder")
            _ = try FileSystemService.copyItem(at: copySource, toFolder: fakeFolder)
        } catch {
            negCopyPassed = true
        }
        TestReporter.report("FileSystem", "NEG: copyItem to non-existent folder throws error", result: negCopyPassed)

        // POS: moveToTrash removes the item from its original location
        let trashCandidate = tempDir.appendingPathComponent("trash_me.txt")
        try? "disposable".write(to: trashCandidate, atomically: true, encoding: .utf8)
        var trashPassed = false
        do {
            _ = try FileSystemService.moveToTrash(url: trashCandidate)
            trashPassed = !FileManager.default.fileExists(atPath: trashCandidate.path)
        } catch {
            print("moveToTrash error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: moveToTrash removes item from its original location", result: trashPassed)

        // NEG: moveToTrash on a non-existent file throws
        var negTrashPassed = false
        do {
            let fakeFile = tempDir.appendingPathComponent("never_existed.txt")
            _ = try FileSystemService.moveToTrash(url: fakeFile)
        } catch {
            negTrashPassed = true
        }
        TestReporter.report("FileSystem", "NEG: moveToTrash on non-existent file throws error", result: negTrashPassed)

        // POS: writeToPasteboard / readFromPasteboard round-trip file URLs
        let pbFileA = tempDir.appendingPathComponent("pb_a.txt")
        let pbFileB = tempDir.appendingPathComponent("pb_b.txt")
        try? "a".write(to: pbFileA, atomically: true, encoding: .utf8)
        try? "b".write(to: pbFileB, atomically: true, encoding: .utf8)
        FileSystemService.writeToPasteboard(urls: [pbFileA, pbFileB])
        let readBack = FileSystemService.readFromPasteboard()
        let writtenPaths = Set([pbFileA.path, pbFileB.path])
        let readPaths = Set((readBack ?? []).map { $0.path })
        TestReporter.report("FileSystem", "POS: writeToPasteboard/readFromPasteboard round-trips the same file URLs", result: readPaths == writtenPaths)

        // POS: copyFileContentToClipboard writes the file's text content as a pasteboard string
        let clipboardFile = tempDir.appendingPathComponent("clipboard_source.txt")
        let clipboardContent = "clipboard content \(UUID().uuidString)"
        try? clipboardContent.write(to: clipboardFile, atomically: true, encoding: .utf8)
        FileSystemService.copyFileContentToClipboard(url: clipboardFile)
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        TestReporter.report("FileSystem", "POS: copyFileContentToClipboard writes the file's text content to the pasteboard", result: pasteboardString == clipboardContent)

        // NEG: copyFileContentToClipboard on a non-existent file does not overwrite pasteboard with stale/empty content
        let priorMarker = "prior marker \(UUID().uuidString)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(priorMarker, forType: .string)
        let missingFile = tempDir.appendingPathComponent("does_not_exist_clip.txt")
        FileSystemService.copyFileContentToClipboard(url: missingFile)
        let unchangedString = NSPasteboard.general.string(forType: .string)
        TestReporter.report("FileSystem", "NEG: copyFileContentToClipboard on missing file leaves pasteboard untouched", result: unchangedString == priorMarker)
    }
}
