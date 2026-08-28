import AppKit
import Foundation
@testable import Wiles

/// Split out of `FileSystemTests.swift` (rule: files should stay under 500 lines) — covers move/zip,
/// copy/trash, and pasteboard round-trip extras for `FileSystemService`.
@MainActor
extension FileSystemTests {
    /// Covers moveItem's success path and its "remove existing destination before moving" branch,
    /// and compressToZIP/extractZIP, none of which are exercised elsewhere.
    static func runMoveAndZipCoverageExtras() async {
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
            let moved = try await FileSystemService.moveItem(at: moveSource, toFolder: moveTargetFolder)
            movePassed = FileManager.default.fileExists(atPath: moved.path) && !FileManager.default.fileExists(atPath: moveSource.path)
        } catch {
            print("moveItem error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: moveItem moves file into target folder and removes it from the source location", result: movePassed)

        // Destination-collision behavior (C1) — never a silent overwrite — is covered exhaustively by:
        await FileSystemMoveRegressionTests.run(tempDir: tempDir)
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
            let copied = try await FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
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
            _ = try await FileSystemService.copyItem(at: copySource, toFolder: fakeFolder)
        } catch {
            negCopyPassed = true
        }
        TestReporter.report("FileSystem", "NEG: copyItem to non-existent folder throws error", result: negCopyPassed)

        // POS: copyItem onto an existing name auto-renames instead of throwing (matches Finder's
        // "duplicate on paste" behavior instead of surfacing a "couldn't be copied" error).
        var collisionRenamePassed = false
        var secondCollisionRenamePassed = false
        do {
            let firstCopy = try await FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
            collisionRenamePassed = firstCopy.lastPathComponent == "copy_source 2.txt"
                && FileManager.default.fileExists(atPath: copySource.path)

            let secondCopy = try await FileSystemService.copyItem(at: copySource, toFolder: copyTargetFolder)
            secondCollisionRenamePassed = secondCopy.lastPathComponent == "copy_source 3.txt"
        } catch {
            print("copyItem collision error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: copyItem onto an existing name auto-renames to name 2.ext (Finder convention)", result: collisionRenamePassed)
        TestReporter.report("FileSystem", "POS: copyItem onto name 2.ext auto-renames to name 3.ext on the next collision", result: secondCollisionRenamePassed)

        await runCreateUniqueDirectoryCoverageExtra(tempDir: tempDir)
        await runTrashCoverageExtra(tempDir: tempDir)
    }

    static func runCreateUniqueDirectoryCoverageExtra(tempDir: URL) async {
        // POS: createUniqueDirectory creates baseName as-is when nothing conflicts (loop never executes)
        var freeNamePassed = false
        do {
            let created = try await FileSystemService.createUniqueDirectory(at: tempDir, baseName: "New Folder")
            freeNamePassed = created.lastPathComponent == "New Folder" && FileManager.default.fileExists(atPath: created.path)
        } catch {
            print("createUniqueDirectory free-name error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: createUniqueDirectory uses baseName as-is when it doesn't already exist", result: freeNamePassed)

        // POS: createUniqueDirectory appends " 2" then " 3" as prior candidates collide (loop body executes twice)
        var secondCollisionPassed = false
        var thirdCollisionPassed = false
        do {
            let second = try await FileSystemService.createUniqueDirectory(at: tempDir, baseName: "New Folder")
            secondCollisionPassed = second.lastPathComponent == "New Folder 2" && FileManager.default.fileExists(atPath: second.path)
            let third = try await FileSystemService.createUniqueDirectory(at: tempDir, baseName: "New Folder")
            thirdCollisionPassed = third.lastPathComponent == "New Folder 3" && FileManager.default.fileExists(atPath: third.path)
        } catch {
            print("createUniqueDirectory collision error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: createUniqueDirectory appends \" 2\" when baseName already exists", result: secondCollisionPassed)
        TestReporter.report("FileSystem", "POS: createUniqueDirectory appends \" 3\" when baseName and \" 2\" both already exist", result: thirdCollisionPassed)

        // NEG: createUniqueDirectory throws when the parent folder itself doesn't exist
        var negPassed = false
        do {
            let missingParent = tempDir.appendingPathComponent("NoSuchParent_\(UUID().uuidString)")
            _ = try await FileSystemService.createUniqueDirectory(at: missingParent, baseName: "New Folder")
        } catch {
            negPassed = true
        }
        TestReporter.report("FileSystem", "NEG: createUniqueDirectory throws when the parent folder doesn't exist", result: negPassed)
    }

    static func runTrashCoverageExtra(tempDir: URL) async {
        // POS: moveToTrash removes the item from its original location
        let trashCandidate = tempDir.appendingPathComponent("trash_me.txt")
        try? "disposable".write(to: trashCandidate, atomically: true, encoding: .utf8)
        var trashPassed = false
        do {
            _ = try await FileSystemService.moveToTrash(url: trashCandidate)
            trashPassed = !FileManager.default.fileExists(atPath: trashCandidate.path)
        } catch {
            print("moveToTrash error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: moveToTrash removes item from its original location", result: trashPassed)
        // NEG: moveToTrash on a non-existent file throws
        var negTrashPassed = false
        do {
            let fakeFile = tempDir.appendingPathComponent("never_existed.txt")
            _ = try await FileSystemService.moveToTrash(url: fakeFile)
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
        try? await PasteboardService.copyFileContentToClipboard(url: clipboardFile)
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        TestReporter.report(
            "FileSystem",
            "POS: copyFileContentToClipboard writes the file's text content to the pasteboard",
            result: pasteboardString == clipboardContent)
        // NEG: copyFileContentToClipboard on a non-existent file throws and does not overwrite the pasteboard
        let priorMarker = "prior marker \(UUID().uuidString)"
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(priorMarker, forType: .string)
        let missingFile = tempDir.appendingPathComponent("does_not_exist_clip.txt")
        var threw = false
        do {
            try await PasteboardService.copyFileContentToClipboard(url: missingFile)
        } catch {
            threw = true
        }
        let unchangedString = NSPasteboard.general.string(forType: .string)
        TestReporter.report("FileSystem", "NEG: copyFileContentToClipboard on missing file throws", result: threw)
        TestReporter.report("FileSystem", "NEG: copyFileContentToClipboard on missing file leaves pasteboard untouched", result: unchangedString == priorMarker)

        runCreateFileFromPasteboardContentCoverageExtras(tempDir: tempDir)
    }

    /// Note: `PasteboardService.pngData(for:)`'s `guard ... else { return nil }` failure branch
    /// (an `NSImage` whose `tiffRepresentation` or `NSBitmapImageRep(data:)` fails) isn't covered
    /// here — constructing an `NSImage` that reports `.tiff` availability on the pasteboard yet
    /// fails TIFF/bitmap conversion isn't reachable through the public API without a fragile,
    /// disproportionate mock. Every image handed to `NSImage(size:)` + `lockFocus`/`unlockFocus`
    /// round-trips cleanly through `tiffRepresentation`.
    static func runCreateFileFromPasteboardContentCoverageExtras(tempDir: URL) {
        let pb = NSPasteboard.general
        let destFolder = tempDir.appendingPathComponent("PasteContent_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)

        // POS: createFileFromPasteboardContent writes a copied image as "Pasted Image.png"
        pb.clearContents()
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.set()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        pb.writeObjects([image])
        var imagePassed = false
        do {
            let created = try PasteboardService.createFileFromPasteboardContent(in: destFolder)
            imagePassed = created?.lastPathComponent == "Pasted Image.png" && FileManager.default.fileExists(atPath: created?.path ?? "")
        } catch {
            print("createFileFromPasteboardContent image error: \(error)")
        }
        TestReporter.report("FileSystem", "POS: createFileFromPasteboardContent writes a copied image as Pasted Image.png", result: imagePassed)

        // POS: createFileFromPasteboardContent falls back to text when no image is on the pasteboard
        pb.clearContents()
        let pastedText = "pasted text \(UUID().uuidString)"
        pb.setString(pastedText, forType: .string)
        var textPassed = false
        do {
            let created = try PasteboardService.createFileFromPasteboardContent(in: destFolder)
            let content = created.flatMap { try? String(contentsOf: $0) }
            textPassed = created?.lastPathComponent == "Pasted Text.txt" && content == pastedText
        } catch {
            print("createFileFromPasteboardContent text error: \(error)")
        }
        TestReporter.report(
            "FileSystem",
            "POS: createFileFromPasteboardContent falls back to writing Pasted Text.txt when there's no image",
            result: textPassed)

        runCreateFileFromPasteboardContentNilCases(pb: pb, destFolder: destFolder)
    }

    static func runCreateFileFromPasteboardContentNilCases(pb: NSPasteboard, destFolder: URL) {
        // NEG: createFileFromPasteboardContent returns nil when there's nothing pasteable
        pb.clearContents()
        var nilPassed = false
        do {
            let created = try PasteboardService.createFileFromPasteboardContent(in: destFolder)
            nilPassed = created == nil
        } catch {
            print("createFileFromPasteboardContent empty error: \(error)")
        }
        TestReporter.report(
            "FileSystem",
            "NEG: createFileFromPasteboardContent returns nil when the pasteboard has neither an image nor text",
            result: nilPassed)

        // NEG: createFileFromPasteboardContent also returns nil for an empty (but present) string
        pb.clearContents()
        pb.setString("", forType: .string)
        var emptyStringPassed = false
        do {
            let created = try PasteboardService.createFileFromPasteboardContent(in: destFolder)
            emptyStringPassed = created == nil
        } catch {
            print("createFileFromPasteboardContent empty string error: \(error)")
        }
        TestReporter.report("FileSystem", "NEG: createFileFromPasteboardContent returns nil for an empty string on the pasteboard", result: emptyStringPassed)

        pb.clearContents()
    }
}
