@testable import Wiles
import Foundation

@MainActor
public struct CopyPathTests {
    public static func run() {
        let baseDir = URL(fileURLWithPath: "/Users/test/Documents")
        let targetFile = URL(fileURLWithPath: "/Users/test/Documents/My Folder/file (1).txt")

        // POS: Absolute Path Format
        let absolute = CopyPathService.format(url: targetFile, variant: .absolute, relativeTo: baseDir)
        TestReporter.report("CopyPath", "POS: Absolute path formatting", result: absolute == "/Users/test/Documents/My Folder/file (1).txt")

        // POS: Relative Path Format
        let relative = CopyPathService.format(url: targetFile, variant: .relative, relativeTo: baseDir)
        TestReporter.report("CopyPath", "POS: Relative path formatting", result: relative == "My Folder/file (1).txt")

        // POS: File URL Format
        let fileURL = CopyPathService.format(url: targetFile, variant: .fileURL, relativeTo: baseDir)
        TestReporter.report("CopyPath", "POS: File URL formatting", result: fileURL == "file:///Users/test/Documents/My%20Folder/file%20(1).txt" || fileURL.contains("file:///"))

        // POS: Terminal Escaped Path Format
        let escaped = CopyPathService.format(url: targetFile, variant: .terminalEscaped, relativeTo: baseDir)
        let containsBackslashes = escaped.contains("My\\ Folder") && escaped.contains("file\\ \\(1\\).txt")
        TestReporter.report("CopyPath", "POS: Terminal escaped formatting", result: containsBackslashes)
    }
}
