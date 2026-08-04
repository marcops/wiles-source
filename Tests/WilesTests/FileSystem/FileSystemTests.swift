@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct FileSystemTests {
    public static func run() async {
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
        await runSearchAndSortCoverageExtras()
        await runAdditionalCoverageExtras()
    }

    nonisolated private static func loadItems(at url: URL, query: String = "", sort: SortOption = .name, ascending: Bool = true, showHidden: Bool = false, showTags: Bool = false) async -> [FileItem] {
        await FileSystemService.loadDirectoryContents(
            at: url,
            options: DirectoryLoadOptions(showHidden: showHidden, showTags: showTags, searchQuery: query, sortOption: sort, sortAscending: ascending)
        )
    }

    private static func runSearchAndSortCoverageExtras() async {
        await tagFilterCoverage()
        await contentSearchCoverage()
        await dateFilterCoverage()
        await sizeFilterUnitAndOperatorCoverage()
        await kindFilterVariantsCoverage()
        await multiTokenAndCoverage()
        await sortOptionVariantsCoverage()
        await recentsVirtualDirectoryCoverage()
    }

    nonisolated private static func tagFilterCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let taggedFile = dir.appendingPathComponent("tagged_doc.txt")
        let plainFile = dir.appendingPathComponent("plain_doc.txt")
        try? "x".write(to: taggedFile, atomically: true, encoding: .utf8)
        try? "x".write(to: plainFile, atomically: true, encoding: .utf8)
        try? FileSystemService.setTags(for: taggedFile, tags: ["Work"])

        let matches = await loadItems(at: dir, query: "tag:Work", showTags: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"tag:\" filter matches files with the given Finder tag", result: matches.count == 1 && matches.first?.name == "tagged_doc.txt")

        let noMatches = await loadItems(at: dir, query: "tag:Personal", showTags: true)
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: \"tag:\" filter excludes files without the given tag", result: noMatches.isEmpty)
    }

    nonisolated private static func contentSearchCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let textFile = dir.appendingPathComponent("unrelated_name.txt")
        try? "the secret phrase is unicorn".write(to: textFile, atomically: true, encoding: .utf8)
        let binaryFile = dir.appendingPathComponent("unrelated_name.bin")
        try? "the secret phrase is unicorn".write(to: binaryFile, atomically: true, encoding: .utf8)

        let byContent = await loadItems(at: dir, query: "unicorn")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: token >=3 chars falls back to matching file content for text extensions", result: byContent.contains { $0.name == "unrelated_name.txt" })
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: content search does not match non-text extensions", result: !byContent.contains { $0.name == "unrelated_name.bin" })

        // Note: querying "un" against files literally named "unrelated_name.*" would match via the
        // plain filename-substring check before content search's 3-char guard is ever reached — use
        // a short token that appears only in the content, not the filename, to isolate the guard.
        let tooShort = await loadItems(at: dir, query: "ic")
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: content search is skipped for tokens shorter than 3 characters", result: tooShort.isEmpty)
    }

    nonisolated private static func dateFilterCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let oldFile = dir.appendingPathComponent("old_file.txt")
        try? "x".write(to: oldFile, atomically: true, encoding: .utf8)
        let tenDaysAgo = Date().addingTimeInterval(-10 * 86400)
        try? FileManager.default.setAttributes([.modificationDate: tenDaysAgo], ofItemAtPath: oldFile.path)

        let yesterdayFile = dir.appendingPathComponent("yesterday_file.txt")
        try? "x".write(to: yesterdayFile, atomically: true, encoding: .utf8)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        try? FileManager.default.setAttributes([.modificationDate: yesterday], ofItemAtPath: yesterdayFile.path)

        let olderThan5Days = await loadItems(at: dir, query: "date:>=5d")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"date:>=Nd\" matches files modified at least N days ago", result: olderThan5Days.contains { $0.name == "old_file.txt" })

        let newerThan5Days = await loadItems(at: dir, query: "date:<5d")
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: \"date:<Nd\" excludes files modified more than N days ago", result: !newerThan5Days.contains { $0.name == "old_file.txt" })

        let yesterdayMatch = await loadItems(at: dir, query: "date:yesterday")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"date:yesterday\" matches a file modified yesterday", result: yesterdayMatch.contains { $0.name == "yesterday_file.txt" } && !yesterdayMatch.contains { $0.name == "old_file.txt" })

        let hoursFilter = await loadItems(at: dir, query: "date:<=200h")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"date:<=Nh\" applies the hour unit and <= operator", result: !hoursFilter.contains { $0.name == "old_file.txt" })
    }

    nonisolated private static func sizeFilterUnitAndOperatorCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let exact500 = dir.appendingPathComponent("exact_500b.bin")
        try? Data(repeating: 0, count: 500).write(to: exact500)

        let equalMatch = await loadItems(at: dir, query: "size:=500b")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"size:=Nb\" applies the byte unit and equality operator", result: equalMatch.count == 1 && equalMatch.first?.name == "exact_500b.bin")

        let noDigits = await loadItems(at: dir, query: "size:>abc")
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: \"size:\" filter with no numeric digits matches nothing", result: noDigits.isEmpty)
    }

    nonisolated private static func kindFilterVariantsCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "x".write(to: dir.appendingPathComponent("report.pdf"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("archive.zip"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("custom.xyz"), atomically: true, encoding: .utf8)

        let docs = await loadItems(at: dir, query: "kind:document")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"kind:document\" matches known document extensions", result: docs.contains { $0.name == "report.pdf" } && docs.contains { $0.name == "notes.md" })

        let code = await loadItems(at: dir, query: "kind:code")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"kind:code\" matches known source-code extensions", result: code.count == 1 && code.first?.name == "main.swift")

        let archive = await loadItems(at: dir, query: "kind:archive")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"kind:archive\" matches known archive extensions", result: archive.count == 1 && archive.first?.name == "archive.zip")

        let pdfOnly = await loadItems(at: dir, query: "kind:pdf")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: \"kind:pdf\" matches only .pdf files", result: pdfOnly.count == 1 && pdfOnly.first?.name == "report.pdf")

        let defaultExt = await loadItems(at: dir, query: "kind:xyz")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: unrecognized \"kind:\" falls back to matching the raw extension", result: defaultExt.count == 1 && defaultExt.first?.name == "custom.xyz")

        let defaultNameContains = await loadItems(at: dir, query: "kind:custom")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: unrecognized \"kind:\" also falls back to matching the filename substring", result: defaultNameContains.contains { $0.name == "custom.xyz" })
    }

    nonisolated private static func multiTokenAndCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "x".write(to: dir.appendingPathComponent("vacation_photo.png"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("vacation_notes.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("work_photo.png"), atomically: true, encoding: .utf8)

        let both = await loadItems(at: dir, query: "vacation kind:image")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: multiple space-separated tokens are combined with AND semantics", result: both.count == 1 && both.first?.name == "vacation_photo.png")
    }

    nonisolated private static func sortOptionVariantsCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let older = dir.appendingPathComponent("older.txt")
        let newer = dir.appendingPathComponent("newer.txt")
        try? "x".write(to: older, atomically: true, encoding: .utf8)
        try? "x".write(to: newer, atomically: true, encoding: .utf8)
        let pastDate = Date().addingTimeInterval(-5000)
        try? FileManager.default.setAttributes([.modificationDate: pastDate, .creationDate: pastDate], ofItemAtPath: older.path)

        let byModified = await loadItems(at: dir, sort: .dateModified, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .dateModified ascending orders oldest-modified first", result: byModified.map { $0.name } == ["older.txt", "newer.txt"])

        let byCreated = await loadItems(at: dir, sort: .dateCreated, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .dateCreated ascending orders oldest-created first", result: byCreated.map { $0.name } == ["older.txt", "newer.txt"])

        let byModifiedDesc = await loadItems(at: dir, sort: .dateModified, ascending: false)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .dateModified descending reverses the ascending order", result: byModifiedDesc.map { $0.name } == ["newer.txt", "older.txt"])

        // These extensions/owners/groups differ so the .kind/.owner/.group comparator branches execute meaningfully or at least exercise the switch case without crashing.
        let kindA = dir.appendingPathComponent("file_a.aaa")
        let kindB = dir.appendingPathComponent("file_b.bbb")
        try? "x".write(to: kindA, atomically: true, encoding: .utf8)
        try? "x".write(to: kindB, atomically: true, encoding: .utf8)
        let byKind = await loadItems(at: dir, sort: .kind, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .kind ascending orders by file extension", result: (byKind.firstIndex { $0.name == "file_a.aaa" } ?? -1) < (byKind.firstIndex { $0.name == "file_b.bbb" } ?? -1))

        let byOwner = await loadItems(at: dir, sort: .owner, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .owner does not crash and returns all items", result: byOwner.count == 4)

        let byOwnerDesc = await loadItems(at: dir, sort: .owner, ascending: false)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .owner descending does not crash and returns all items", result: byOwnerDesc.count == 4)

        let byGroup = await loadItems(at: dir, sort: .group, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .group does not crash and returns all items", result: byGroup.count == 4)

        let byAccessed = await loadItems(at: dir, sort: .dateAccessed, ascending: true)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: sortOption .dateAccessed does not crash and returns all items", result: byAccessed.count == 4)
    }

    nonisolated private static func recentsVirtualDirectoryCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let realFile = dir.appendingPathComponent("recent_real_file.txt")
        try? "x".write(to: realFile, atomically: true, encoding: .utf8)
        let fakeFile = dir.appendingPathComponent("recent_fake_file.txt")

        let defaultsKey = "wiles_recentOpenedURLs"
        let priorValue = UserDefaults.standard.stringArray(forKey: defaultsKey)
        UserDefaults.standard.set([realFile.path, fakeFile.path], forKey: defaultsKey)
        defer {
            if let priorValue { UserDefaults.standard.set(priorValue, forKey: defaultsKey) } else { UserDefaults.standard.removeObject(forKey: defaultsKey) }
        }

        let recentsURL = URL(fileURLWithPath: "/virtual/recents")
        let items = await loadItems(at: recentsURL)
        await TestReporter.report("FileSystem/SearchAndSort", "POS: virtual recents directory includes only entries that still exist on disk", result: items.count == 1 && items.first?.name == "recent_real_file.txt")

        let filtered = await loadItems(at: recentsURL, query: "recent_real")
        await TestReporter.report("FileSystem/SearchAndSort", "POS: virtual recents directory applies search filtering like a real directory", result: filtered.count == 1 && filtered.first?.name == "recent_real_file.txt")

        let filteredOut = await loadItems(at: recentsURL, query: "no_such_match_token")
        await TestReporter.report("FileSystem/SearchAndSort", "NEG: virtual recents directory excludes entries that don't match the search query", result: filteredOut.isEmpty)
    }

    private static func runAdditionalCoverageExtras() async {
        await resourceFlagHiddenFileCoverage()
        await sizeFilterLessOrEqualAndGigabyteUnitCoverage()
        await nonAsteriskRegexTriggerCoverage()
        await nonExistentDirectoryCoverage()
        await setTagsNegativeCoverage()
    }

    // Covers isFileHidden's fallback branch: a file hidden via the .isHiddenKey resource flag
    // (e.g. `chflags hidden`) rather than via a leading-dot filename.
    nonisolated private static func resourceFlagHiddenFileCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        var flaggedHiddenFile = dir.appendingPathComponent("flagged_hidden.txt")
        try? "x".write(to: flaggedHiddenFile, atomically: true, encoding: .utf8)
        var resourceValues = URLResourceValues()
        resourceValues.isHidden = true
        try? flaggedHiddenFile.setResourceValues(resourceValues)

        let plainFile = dir.appendingPathComponent("plain_visible.txt")
        try? "x".write(to: plainFile, atomically: true, encoding: .utf8)

        let withoutHidden = await loadItems(at: dir, showHidden: false)
        await TestReporter.report("FileSystem", "NEG: a file hidden via the isHidden resource flag (no leading dot) is excluded when showHidden is false", result: !withoutHidden.contains { $0.name == "flagged_hidden.txt" } && withoutHidden.contains { $0.name == "plain_visible.txt" })

        let withHidden = await loadItems(at: dir, showHidden: true)
        await TestReporter.report("FileSystem", "POS: a file hidden via the isHidden resource flag is included when showHidden is true", result: withHidden.contains { $0.name == "flagged_hidden.txt" })
    }

    // Covers the "<=" operator branch and the gigabyte ("g") unit branch of matchesSizeFilter,
    // neither of which is exercised by the existing size-filter tests (which use "=", ">", "<", and "k"/"b" units).
    nonisolated private static func sizeFilterLessOrEqualAndGigabyteUnitCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file1k = dir.appendingPathComponent("exactly_1k.bin")
        try? Data(repeating: 0, count: 1024).write(to: file1k)
        let file2k = dir.appendingPathComponent("two_k.bin")
        try? Data(repeating: 0, count: 2048).write(to: file2k)

        let lessOrEqual = await loadItems(at: dir, query: "size:<=1k")
        await TestReporter.report("FileSystem", "POS: \"size:<=Nk\" includes a file exactly at the threshold and excludes larger ones", result: lessOrEqual.count == 1 && lessOrEqual.first?.name == "exactly_1k.bin")

        let underOneGig = await loadItems(at: dir, query: "size:<1g")
        await TestReporter.report("FileSystem", "POS: \"size:<Ng\" applies the gigabyte unit, matching small files under the threshold", result: underOneGig.count == 2)

        let overOneGig = await loadItems(at: dir, query: "size:>1g")
        await TestReporter.report("FileSystem", "NEG: \"size:>Ng\" excludes small files well under a gigabyte", result: overOneGig.isEmpty)
    }

    // Covers the regex-trigger branch of parseSearchRegex reached via "^" or "$" without a "*",
    // distinct from the wildcard-triggered path already tested elsewhere.
    nonisolated private static func nonAsteriskRegexTriggerCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try? "x".write(to: dir.appendingPathComponent("draft_final.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("other.txt"), atomically: true, encoding: .utf8)

        // "$" anchors to the end of string, so the query must match what the filename actually
        // ends with ("...final.txt" ends in "txt", not "final") — use a pattern anchored to the
        // real suffix instead of assuming "$" matches anywhere in the name.
        let results = await loadItems(at: dir, query: "final\\.txt$")
        await TestReporter.report("FileSystem", "POS: a query containing \"$\" (without \"*\") is treated as a regex pattern", result: results.count == 1 && results.first?.name == "draft_final.txt")
    }

    // Covers the early-return [] branch of loadRealDirectoryContents when contentsOfDirectory fails.
    nonisolated private static func nonExistentDirectoryCoverage() async {
        let missingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathComponent("does_not_exist")
        let results = await loadItems(at: missingDir)
        await TestReporter.report("FileSystem", "NEG: loadDirectoryContents on a non-existent directory returns an empty array instead of crashing", result: results.isEmpty)
    }

    // Covers the throwing path of setTags when given a URL that does not exist on disk.
    nonisolated private static func setTagsNegativeCoverage() async {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let missingFile = dir.appendingPathComponent("no_such_file.txt")
        var negSetTagsPassed = false
        do {
            try FileSystemService.setTags(for: missingFile, tags: ["Work"])
        } catch {
            negSetTagsPassed = true
        }
        await TestReporter.report("FileSystem", "NEG: setTags on a non-existent file throws an error", result: negSetTagsPassed)
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
