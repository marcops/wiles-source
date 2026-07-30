import Foundation
import AppKit

@MainActor
public final class AutomatedTestSuite {
    public static func runAllTests() async {
        print("\n=======================================================")
        print("🧪 RUNNING WILES COMPREHENSIVE AUTOMATED TEST SUITE")
        print("=======================================================")
        
        var passed = 0
        var failed = 0
        
        func report(_ category: String, _ name: String, result: Bool, detail: String = "") {
            if result {
                passed += 1
                print("✅ [PASS] [\(category)] \(name)")
            } else {
                failed += 1
                print("❌ [FAIL] [\(category)] \(name) \(detail)")
            }
        }
        
        // ========================================================
        // 1. APPSTATE & NAVIGATION SUITE
        // ========================================================
        do {
            let appState = AppState()
            let initial = appState.currentURL
            let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
            
            // Positive: Navigation
            appState.navigateTo(desktop)
            report("Navigation", "POS: navigateTo(Desktop)", result: appState.currentURL.standardizedFileURL == desktop.standardizedFileURL)
            
            // Positive: History Back & Forward
            appState.goBack()
            report("Navigation", "POS: goBack() restores previous URL", result: appState.currentURL.standardizedFileURL == initial.standardizedFileURL)
            
            appState.goForward()
            report("Navigation", "POS: goForward() restores forward URL", result: appState.currentURL.standardizedFileURL == desktop.standardizedFileURL)
            
            // Negative: Stack Boundary Checks
            appState.goForward() // Empty forward stack
            report("Navigation", "NEG: goForward() on empty stack does not crash", result: true)
            
            appState.goBack()
            appState.goBack() // Empty back stack
            report("Navigation", "NEG: goBack() on empty stack does not crash", result: true)
            
            // Positive: Favorites Management
            appState.addFavorite(desktop)
            report("Favorites", "POS: addFavorite()", result: appState.isFavorite(desktop))
            
            appState.removeFavorite(desktop)
            report("Favorites", "POS: removeFavorite()", result: !appState.isFavorite(desktop))
        }
        
        // ========================================================
        // 2. LOCALIZATION SERVICE SUITE
        // ========================================================
        do {
            let enStr = L10n.string(.aboutWiles, lang: .english)
            let ptStr = L10n.string(.aboutWiles, lang: .portuguese)
            let esStr = L10n.string(.aboutWiles, lang: .spanish)
            let frStr = L10n.string(.aboutWiles, lang: .french)
            let deStr = L10n.string(.aboutWiles, lang: .german)
            
            let posLoc = !enStr.isEmpty && !ptStr.isEmpty && !esStr.isEmpty && !frStr.isEmpty && !deStr.isEmpty
            report("Localization", "POS: Multi-language string resolution (EN/PT/ES/FR/DE)", result: posLoc)
            
            let sysStr = L10n.string(.aboutWiles, lang: .system)
            report("Localization", "POS/NEG: System language fallback resolution", result: !sysStr.isEmpty)
        }
        
        // ========================================================
        // 3. FILE SYSTEM ACTIONS SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            // Positive: Folder Creation
            let createdDir = try? FileSystemService.createDirectory(at: tempDir, name: "TestFolder")
            report("FileSystem", "POS: createDirectory", result: createdDir != nil && FileManager.default.fileExists(atPath: createdDir!.path))
            
            // Positive: File Creation
            let testFile = tempDir.appendingPathComponent("sample.txt")
            try? "Sample Data".write(to: testFile, atomically: true, encoding: .utf8)
            report("FileSystem", "POS: File creation", result: FileManager.default.fileExists(atPath: testFile.path))
            
            // Positive: Rename
            let renamedFile = try? FileSystemService.renameItem(at: testFile, newName: "renamed_sample.txt")
            report("FileSystem", "POS: renameItem", result: renamedFile != nil && FileManager.default.fileExists(atPath: renamedFile!.path))
            
            // Negative: Rename Non-Existent File
            var negRenamePassed = false
            do {
                let fakeURL = tempDir.appendingPathComponent("fake_file.txt")
                _ = try FileSystemService.renameItem(at: fakeURL, newName: "should_fail.txt")
            } catch {
                negRenamePassed = true
            }
            report("FileSystem", "NEG: renameItem on non-existent path throws error", result: negRenamePassed)
            
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
            report("FileSystem", "NEG: moveItem to non-existent folder throws error", result: negMovePassed)
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 4. ZIP ARCHIVE SERVICE SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let file1 = tempDir.appendingPathComponent("doc1.txt")
            try? "Content 1".write(to: file1, atomically: true, encoding: .utf8)
            
            // Positive: Compression
            var compressPassed = false
            do {
                try FileSystemService.compressToZIP(urls: [file1], in: tempDir)
                let zipURL = tempDir.appendingPathComponent("doc1.zip")
                compressPassed = FileManager.default.fileExists(atPath: zipURL.path)
            } catch {
                print("ZIP Compress error: \(error)")
            }
            report("ZipArchive", "POS: compressToZIP creates valid .zip archive", result: compressPassed)
            
            // Positive: Extraction
            var extractPassed = false
            if compressPassed {
                let zipURL = tempDir.appendingPathComponent("doc1.zip")
                let extractTarget = tempDir.appendingPathComponent("Extracted")
                try? FileManager.default.createDirectory(at: extractTarget, withIntermediateDirectories: true)
                do {
                    try FileSystemService.extractZIP(archiveURL: zipURL, to: extractTarget)
                    extractPassed = FileManager.default.fileExists(atPath: extractTarget.appendingPathComponent("doc1.txt").path)
                } catch {
                    print("ZIP Extract error: \(error)")
                }
            }
            report("ZipArchive", "POS: extractZIP expands archive successfully", result: extractPassed)
            
            // Negative: Extract Invalid File
            var negExtractPassed = false
            let invalidArchive = tempDir.appendingPathComponent("not_a_zip.zip")
            try? "Corrupt Data".write(to: invalidArchive, atomically: true, encoding: .utf8)
            do {
                try FileSystemService.extractZIP(archiveURL: invalidArchive, to: tempDir)
            } catch {
                negExtractPassed = true
            }
            report("ZipArchive", "NEG: extractZIP on invalid archive throws error", result: negExtractPassed)
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 5. BATCH RENAME SERVICE SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let item1 = tempDir.appendingPathComponent("file_alpha.txt")
            let item2 = tempDir.appendingPathComponent("file_beta.txt")
            try? "Alpha".write(to: item1, atomically: true, encoding: .utf8)
            try? "Beta".write(to: item2, atomically: true, encoding: .utf8)
            
            let icon = NSWorkspace.shared.icon(forFile: item1.path)
            let fileItem1 = FileItem(url: item1, icon: icon)
            let fileItem2 = FileItem(url: item2, icon: icon)
            
            // Positive: Find & Replace Batch Rename
            let batchResult = try? BatchRenameService.performBatchRename(
                items: [fileItem1, fileItem2],
                mode: .replace(find: "file_", replaceWith: "doc_")
            )
            let batchPos = batchResult != nil && batchResult!.count == 2 && FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("doc_alpha.txt").path)
            report("BatchRename", "POS: performBatchRename (.replace)", result: batchPos)
            
            // Negative: Empty Find String (No Change)
            let docAlphaURL = tempDir.appendingPathComponent("doc_alpha.txt")
            let currentItem1 = FileItem(url: docAlphaURL, icon: NSWorkspace.shared.icon(forFile: docAlphaURL.path))
            let negBatchResult = try? BatchRenameService.performBatchRename(
                items: [currentItem1],
                mode: .replace(find: "", replaceWith: "prefix_")
            )
            report("BatchRename", "NEG: performBatchRename with empty pattern returns unchanged URLs", result: negBatchResult?.first?.lastPathComponent == "doc_alpha.txt")
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 6. FILE SHREDDER SERVICE SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let secretFile = tempDir.appendingPathComponent("secret.txt")
            try? "Super Secret Bytes".write(to: secretFile, atomically: true, encoding: .utf8)
            
            // Positive: Secure Shred
            try? await FileShredderService.shredFiles(urls: [secretFile])
            let shredPos = !FileManager.default.fileExists(atPath: secretFile.path)
            report("FileShredder", "POS: shredFiles overwrites and deletes file", result: shredPos)
            
            // Negative: Shred Non-Existent Path (Graceful handling)
            var negShredPassed = false
            do {
                let fakePath = tempDir.appendingPathComponent("non_existent_secret.txt")
                try await FileShredderService.shredFiles(urls: [fakePath])
                negShredPassed = true
            } catch {
                negShredPassed = false
            }
            report("FileShredder", "NEG: shredFiles on non-existent path handles gracefully without crash", result: negShredPassed)
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 7. SYMLINK SERVICE SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let targetFile = tempDir.appendingPathComponent("origin.txt")
            try? "Original Content".write(to: targetFile, atomically: true, encoding: .utf8)
            
            // Positive: Absolute Symlink
            let linkURL = try? SymlinkService.createSymlink(
                targetURL: targetFile,
                destinationFolder: tempDir,
                symlinkName: "origin_link.txt",
                mode: .absolute
            )
            let symlinkPos = linkURL != nil && FileManager.default.fileExists(atPath: linkURL!.path)
            report("SymlinkService", "POS: createSymlink (.absolute)", result: symlinkPos)
            
            // Negative: Empty Symlink Name Falls Back to Default
            let defaultLink = try? SymlinkService.createSymlink(
                targetURL: targetFile,
                destinationFolder: tempDir,
                symlinkName: "   ",
                mode: .absolute
            )
            report("SymlinkService", "NEG: Empty symlink name auto-generates default link name", result: defaultLink?.lastPathComponent.contains("link") == true)
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 8. UNDO / REDO SERVICE SUITE
        // ========================================================
        do {
            let service = UndoRedoService.shared
            
            // Negative: Undo on empty stack
            let emptyUndo = await service.undo()
            report("UndoRedo", "NEG: undo() on empty stack returns nil", result: emptyUndo == nil)
            
            let emptyRedo = await service.redo()
            report("UndoRedo", "NEG: redo() on empty stack returns nil", result: emptyRedo == nil)
            
            // Positive: Record & Undo Action
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let fileA = tempDir.appendingPathComponent("fileA.txt")
            let fileB = tempDir.appendingPathComponent("fileB.txt")
            try? "Data".write(to: fileA, atomically: true, encoding: .utf8)
            
            let renamed = try? FileSystemService.renameItem(at: fileA, newName: "fileB.txt")
            if let newURL = renamed {
                service.recordAction(.rename(oldURL: fileA, newURL: newURL))
                report("UndoRedo", "POS: canUndo() is true after recording action", result: service.canUndo())
                
                let undoResult = await service.undo()
                let undoPos = undoResult != nil && FileManager.default.fileExists(atPath: fileA.path) && !FileManager.default.fileExists(atPath: fileB.path)
                report("UndoRedo", "POS: undo() reverses rename operation", result: undoPos)
            }
            
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 9. INSTANT LOCAL HTTP SHARE SERVICE SUITE
        // ========================================================
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let sampleFile = tempDir.appendingPathComponent("public_share.txt")
            try? "Public Data".write(to: sampleFile, atomically: true, encoding: .utf8)
            
            let server = LocalHttpServerService.shared
            server.start(sharing: tempDir)
            try? await Task.sleep(nanoseconds: 500_000_000) // Wait for listener
            
            // Positive: HTTP 200 OK Directory Index
            var posHttpPassed = false
            if let rootURL = URL(string: "http://localhost:8080") {
                if let (data, resp) = try? await URLSession.shared.data(from: rootURL),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                    let html = String(data: data, encoding: .utf8) ?? ""
                    posHttpPassed = html.contains("public_share.txt")
                }
            }
            report("LocalHttpServer", "POS: GET / returns 200 OK & directory HTML", result: posHttpPassed)
            
            // Positive: File Content Download
            var posFileFetchPassed = false
            if let fileURL = URL(string: "http://localhost:8080/public_share.txt") {
                if let (data, resp) = try? await URLSession.shared.data(from: fileURL),
                   let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                    let text = String(data: data, encoding: .utf8) ?? ""
                    posFileFetchPassed = text == "Public Data"
                }
            }
            report("LocalHttpServer", "POS: GET /public_share.txt returns 200 OK & file payload", result: posFileFetchPassed)
            
            // Negative: Path Traversal Attack (/../)
            var negTraversalBlocked = false
            if let traversalURL = URL(string: "http://localhost:8080/../etc/passwd") {
                if let (_, resp) = try? await URLSession.shared.data(from: traversalURL),
                   let httpResp = resp as? HTTPURLResponse {
                    negTraversalBlocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
                }
            }
            report("LocalHttpServer", "NEG: Path traversal attempt (/../etc/passwd) blocked with 403 Forbidden", result: negTraversalBlocked)
            
            // Negative: Non-Existent File 404
            var neg404Passed = false
            if let missingURL = URL(string: "http://localhost:8080/does_not_exist.txt") {
                if let (_, resp) = try? await URLSession.shared.data(from: missingURL),
                   let httpResp = resp as? HTTPURLResponse {
                    neg404Passed = httpResp.statusCode == 404
                }
            }
            report("LocalHttpServer", "NEG: Requesting non-existent file returns 404 Not Found", result: neg404Passed)
            
            server.stop()
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // ========================================================
        // 10. FOLDER AUTO-ORGANIZATION SUITE
        // ========================================================
        do {
            let baseTemp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let inputDir = baseTemp.appendingPathComponent("Input")
            let targetDir = baseTemp.appendingPathComponent("Target")
            
            try? FileManager.default.createDirectory(at: inputDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            
            let matchingFile = inputDir.appendingPathComponent("invoice.pdf")
            let nonMatchingFile = inputDir.appendingPathComponent("notes.txt")
            try? "PDF".write(to: matchingFile, atomically: true, encoding: .utf8)
            try? "TXT".write(to: nonMatchingFile, atomically: true, encoding: .utf8)
            
            let rule = AutoOrganizationRule(
                sourceURL: inputDir,
                destinationURL: targetDir,
                conditionType: .extensionEquals,
                conditionValue: "pdf",
                isEnabled: true
            )
            
            let service = AutoOrganizationService.shared
            let oldRules = service.rules
            service.rules = [rule]
            
            // Positive: Active Rule Execution
            service.processFolder(inputDir)
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let movedPDF = targetDir.appendingPathComponent("invoice.pdf")
            let posOrgPassed = FileManager.default.fileExists(atPath: movedPDF.path)
            report("AutoOrganization", "POS: Rule routes matching .pdf file to destination", result: posOrgPassed)
            
            // Negative: Non-Matching File Remains Intact
            let nonMatchIntact = FileManager.default.fileExists(atPath: nonMatchingFile.path)
            report("AutoOrganization", "NEG: Non-matching .txt file remains untouched in source directory", result: nonMatchIntact)
            
            // Negative: Disabled Rule Execution
            let matchingFile2 = inputDir.appendingPathComponent("contract.pdf")
            try? "PDF 2".write(to: matchingFile2, atomically: true, encoding: .utf8)
            var disabledRule = rule
            disabledRule.isEnabled = false
            service.rules = [disabledRule]
            
            service.processFolder(inputDir)
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            let disabledIntact = FileManager.default.fileExists(atPath: matchingFile2.path)
            report("AutoOrganization", "NEG: Disabled rule ignores matching file", result: disabledIntact)
            
            service.rules = oldRules
            try? FileManager.default.removeItem(at: baseTemp)
        }
        
        print("=======================================================")
        print("🏁 COMPREHENSIVE SUITE COMPLETE: \(passed) Passed, \(failed) Failed")
        print("=======================================================\n")
        
        exit(failed == 0 ? 0 : 1)
    }
}
