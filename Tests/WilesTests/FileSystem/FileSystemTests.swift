@testable import Wiles
import Foundation

@MainActor
public struct FileSystemTests {
    public static func run() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Positive: Folder Creation
        let createdDir = try? FileSystemService.createDirectory(at: tempDir, name: "TestFolder")
        TestReporter.report("FileSystem", "POS: createDirectory", result: createdDir != nil && FileManager.default.fileExists(atPath: createdDir!.path))
        
        // Positive: File Creation
        let testFile = tempDir.appendingPathComponent("sample.txt")
        try? "Sample Data".write(to: testFile, atomically: true, encoding: .utf8)
        TestReporter.report("FileSystem", "POS: File creation", result: FileManager.default.fileExists(atPath: testFile.path))
        
        // Positive: Rename
        let renamedFile = try? FileSystemService.renameItem(at: testFile, newName: "renamed_sample.txt")
        TestReporter.report("FileSystem", "POS: renameItem", result: renamedFile != nil && FileManager.default.fileExists(atPath: renamedFile!.path))
        
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
    }
}
