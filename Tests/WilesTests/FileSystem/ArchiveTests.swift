import Foundation

@MainActor
public struct ArchiveTests {
    public static func run() {
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
        TestReporter.report("ZipArchive", "POS: compressToZIP creates valid .zip archive", result: compressPassed)
        
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
        TestReporter.report("ZipArchive", "POS: extractZIP expands archive successfully", result: extractPassed)
        
        // Negative: Extract Invalid File
        var negExtractPassed = false
        let invalidArchive = tempDir.appendingPathComponent("not_a_zip.zip")
        try? "Corrupt Data".write(to: invalidArchive, atomically: true, encoding: .utf8)
        do {
            try FileSystemService.extractZIP(archiveURL: invalidArchive, to: tempDir)
        } catch {
            negExtractPassed = true
        }
        TestReporter.report("ZipArchive", "NEG: extractZIP on invalid archive throws error", result: negExtractPassed)
        
        try? FileManager.default.removeItem(at: tempDir)
    }
}
