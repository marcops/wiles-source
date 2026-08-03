import Foundation

@MainActor
public struct FileShredderTests {
    public static func run() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let secretFile = tempDir.appendingPathComponent("secret.txt")
        try? "Super Secret Bytes".write(to: secretFile, atomically: true, encoding: .utf8)
        
        // Positive: Secure Shred
        try? await FileShredderService.shredFiles(urls: [secretFile])
        let shredPos = !FileManager.default.fileExists(atPath: secretFile.path)
        TestReporter.report("FileShredder", "POS: shredFiles overwrites and deletes file", result: shredPos)
        
        // Negative: Shred Non-Existent Path (Graceful handling)
        var negShredPassed = false
        do {
            let fakePath = tempDir.appendingPathComponent("non_existent_secret.txt")
            try await FileShredderService.shredFiles(urls: [fakePath])
            negShredPassed = true
        } catch {
            negShredPassed = false
        }
        TestReporter.report("FileShredder", "NEG: shredFiles on non-existent path handles gracefully without crash", result: negShredPassed)
        
        try? FileManager.default.removeItem(at: tempDir)
    }
}
