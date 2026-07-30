import Foundation
import WilesCore

@MainActor
public struct SymlinkTests {
    public static func run() {
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
        TestReporter.report("SymlinkService", "POS: createSymlink (.absolute)", result: symlinkPos)
        
        // Negative: Empty Symlink Name Falls Back to Default
        let defaultLink = try? SymlinkService.createSymlink(
            targetURL: targetFile,
            destinationFolder: tempDir,
            symlinkName: "   ",
            mode: .absolute
        )
        TestReporter.report("SymlinkService", "NEG: Empty symlink name auto-generates default link name", result: defaultLink?.lastPathComponent.contains("link") == true)
        
        try? FileManager.default.removeItem(at: tempDir)
    }
}
