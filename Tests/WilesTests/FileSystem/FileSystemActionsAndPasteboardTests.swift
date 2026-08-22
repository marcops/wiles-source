import AppKit
import Foundation
@testable import Wiles

/// Split out of `FileSystemTests.swift` (rule: files should stay under 500 lines) — covers move/zip,
/// copy/trash, and pasteboard round-trip extras for `FileSystemService`.
@MainActor
extension FileSystemTests {
    /// Covers moveItem's success path and its "remove existing destination before moving" branch,
    /// and compressToZIP/extractZIP, none of which are exercised elsewhere.
    static func runMoveAndZipCoverageExtras() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        // POS: moveItem moves a file into the target folder and removes it from the source location
        let moveTargetFolder = tempDir.appendingPathComponent("MoveTarget")
        try? FileManager.default.createDirectory(at: moveTargetFolder, withIntermediateDirectories: true)
        let moveSource = tempDir.appendingPathComponent("move_source.txt")
        try? "move me".write(to: moveSource, atomically: true, encoding: .utf8)
        var movePassed = false
        do {
            let moved = try FileSystemService.moveItem(at: moveSource, toFolder: moveTargetFolder)
            movePassed = FileManager.default.fileExists(atPath: moved.path) && !FileManager.default.fileExists(atPath: moveSource.path)
        } catch {
            print("moveItem error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: moveItem moves file into target folder and removes it from the source location", result: movePassed)
        // POS: moveItem overwrites a pre-existing item at the destination rather than throwing
        let overwriteSource = tempDir.appendingPathComponent("overwrite_source.txt")
        let newContent = "new content \(UUID().uuidString)"
        try? newContent.write(to: overwriteSource, atomically: true, encoding: .utf8)
        let existingDest = moveTargetFolder.appendingPathComponent("overwrite_source.txt")
        try? "stale content".write(to: existingDest, atomically: true, encoding: .utf8)
        var overwritePassed = false
        do {
            let moved = try FileSystemService.moveItem(at: overwriteSource, toFolder: moveTargetFolder)
            let readBack = try? String(contentsOf: moved)
            overwritePassed = readBack == newContent
        } catch {
            print("moveItem overwrite error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: moveItem overwrites a pre-existing item at the destination", result: overwritePassed)

        FileSystemMoveRegressionTests.run(tempDir: tempDir)
        runZipRoundTripCoverageExtra(tempDir: tempDir)
    }

    static func runZipRoundTripCoverageExtra(tempDir: URL) {
        // POS: compressToZIP/extractZIP round-trips a file's contents
        let zipSourceFolder = tempDir.appendingPathComponent("ZipSource")
        try? FileManager.default.createDirectory(at: zipSourceFolder, withIntermediateDirectories: true)
        let zipSourceFile = zipSourceFolder.appendingPathComponent("zipped.txt")
        let zipContent = "zip content \(UUID().uuidString)"
        try? zipContent.write(to: zipSourceFile, atomically: true, encoding: .utf8)
        let zipDestFolder = tempDir.appendingPathComponent("ZipDest")
        try? FileManager.default.createDirectory(at: zipDestFolder, withIntermediateDirectories: true)
        var zipRoundTripPassed = false
        do {
            try FileSystemService.compressToZIP(urls: [zipSourceFile], in: zipDestFolder)
            let archiveURL = zipDestFolder.appendingPathComponent("zipped.zip")
            let extractFolder = tempDir.appendingPathComponent("ZipExtract")
            try FileManager.default.createDirectory(at: extractFolder, withIntermediateDirectories: true)
            try FileSystemService.extractZIP(archiveURL: archiveURL, to: extractFolder)
            let extractedFile = extractFolder.appendingPathComponent("zipped.txt")
            let extractedContent = try? String(contentsOf: extractedFile)
            zipRoundTripPassed = extractedContent == zipContent
        } catch {
            print("compressToZIP/extractZIP error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: compressToZIP/extractZIP round-trips a file's contents", result: zipRoundTripPassed)
    }

    static func runActionsCoverageExtras() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
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

        // POS: copyItem onto an existing name auto-renames instead of throwing (matches Finder's
        // "duplicate on paste" behavior instead of surfacing a "couldn't be copied" error).
        var collisionRenamePassed = false
        var secondCollisionRenamePassed = false
        do {
            let firstCopy = try FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
            collisionRenamePassed = firstCopy.lastPathComponent == "copy_source_1.txt"
                && FileManager.default.fileExists(atPath: copySource.path)

            let secondCopy = try FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
            secondCollisionRenamePassed = secondCopy.lastPathComponent == "copy_source_2.txt"
        } catch {
            print("copyItem collision error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: copyItem onto an existing name auto-renames to name_1.ext", result: collisionRenamePassed)
        TestReporter.report("FileSystem", "POS: copyItem onto name_1.ext auto-renames to name_2.ext on the next collision", result: secondCollisionRenamePassed)

        await runTrashCoverageExtra(tempDir: tempDir)
    }

    static func runTrashCoverageExtra(tempDir: URL) async {
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
        await runPasteboardCoverageExtras(tempDir: tempDir)
    }

    static func runPasteboardCoverageExtras(tempDir: URL) async {
        // POS: writeToPasteboard / readFromPasteboard round-trip file URLs
        let pbFileA = tempDir.appendingPathComponent("pb_a.txt")
        let pbFileB = tempDir.appendingPathComponent("pb_b.txt")
        try? "a".write(to: pbFileA, atomically: true, encoding: .utf8)
        try? "b".write(to: pbFileB, atomically: true, encoding: .utf8)
        PasteboardService.writeToPasteboard(urls: [pbFileA, pbFileB])
        let readBack = PasteboardService.readFromPasteboard()
        let writtenPaths = Set([pbFileA.path, pbFileB.path])
        let readPaths = Set((readBack ?? []).map(\.path))
        TestReporter.report("FileSystem", "POS: writeToPasteboard/readFromPasteboard round-trips the same file URLs", result: readPaths == writtenPaths)
        // POS: copyFileContentToClipboard writes the file's text content as a pasteboard string
        let clipboardFile = tempDir.appendingPathComponent("clipboard_source.txt")
        let clipboardContent = "clipboard content \(UUID().uuidString)"
        try? clipboardContent.write(to: clipboardFile, atomically: true, encoding: .utf8)
        PasteboardService.copyFileContentToClipboard(url: clipboardFile)
        // copyFileContentToClipboard dispatches its file read via Task.detached internally (fixed
        // to keep it off the main actor for slow volumes), so the pasteboard write lands
        // asynchronously — poll instead of asserting immediately.
        var pasteboardString: String?
        for _ in 0 ..< 20 {
            pasteboardString = NSPasteboard.general.string(forType: .string)
            if pasteboardString == clipboardContent {
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        TestReporter.report(
            "FileSystem",
            "POS: copyFileContentToClipboard writes the file's text content to the pasteboard",
            result: pasteboardString == clipboardContent)
        // NEG: copyFileContentToClipboard on a non-existent file does not overwrite pasteboard with stale/empty content
        let priorMarker = "prior marker \(UUID().uuidString)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(priorMarker, forType: .string)
        let missingFile = tempDir.appendingPathComponent("does_not_exist_clip.txt")
        PasteboardService.copyFileContentToClipboard(url: missingFile)
        let unchangedString = NSPasteboard.general.string(forType: .string)
        TestReporter.report("FileSystem", "NEG: copyFileContentToClipboard on missing file leaves pasteboard untouched", result: unchangedString == priorMarker)
    }
}
