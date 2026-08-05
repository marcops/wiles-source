@testable import Wiles
import Foundation
import AppKit

@MainActor
public struct CopyPathTests {
    public static func run() {
        let baseDir = URL(fileURLWithPath: "/Users/test/Documents")
        let targetFile = URL(fileURLWithPath: "/Users/test/Documents/My Folder/file (1).txt")

        testFormattingVariants(baseDir: baseDir, targetFile: targetFile)
        testRelativePathAndCopy(baseDir: baseDir, targetFile: targetFile)
    }

    private static func testFormattingVariants(baseDir: URL, targetFile: URL) {
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

        // POS: fileURL formatting percent-encodes spaces and parentheses
        let fileURLEncoded = CopyPathService.format(url: targetFile, variant: .fileURL, relativeTo: baseDir)
        TestReporter.report(
            "CopyPath",
            "POS: fileURL formatting percent-encodes spaces and parentheses",
            result: fileURLEncoded == "file:///Users/test/Documents/My%20Folder/file%20(1).txt"
        )

        // POS: terminalEscaped escapes a broad set of shell-special characters
        let shellSpecial = URL(fileURLWithPath: "/tmp/a&b;c|d$e*f?g<h>i#j!k`l'm\"n.txt")
        let shellEscaped = CopyPathService.escapeForTerminal(shellSpecial.standardizedFileURL.path)
        let allEscaped = ["&", ";", "|", "$", "*", "?", "<", ">", "#", "!", "`", "'", "\""].allSatisfy { shellEscaped.contains("\\" + $0) }
        TestReporter.report("CopyPath", "POS: terminalEscaped escapes shell-special characters", result: allEscaped)

        // POS: terminalEscaped escapes literal backslashes without double-escaping subsequent chars
        let backslashEscaped = CopyPathService.escapeForTerminal("a\\b c")
        TestReporter.report("CopyPath", "POS: terminalEscaped escapes literal backslashes", result: backslashEscaped == "a\\\\b\\ c")
    }

    private static func testRelativePathAndCopy(baseDir: URL, targetFile: URL) {
        // POS: relativePath with a nil base falls back to the absolute path
        let noBase = CopyPathService.relativePath(of: targetFile, relativeTo: nil)
        TestReporter.report("CopyPath", "POS: relativePath(relativeTo: nil) returns the absolute path", result: noBase == targetFile.standardizedFileURL.path)

        // POS: relativePath when target equals base returns "."
        let sameAsBase = CopyPathService.relativePath(of: baseDir, relativeTo: baseDir)
        TestReporter.report("CopyPath", "POS: relativePath(target == base) returns \".\"", result: sameAsBase == ".")

        // NEG: relativePath when target is not under base returns the full path unchanged
        let unrelated = URL(fileURLWithPath: "/Volumes/External/other.txt")
        let notUnderBase = CopyPathService.relativePath(of: unrelated, relativeTo: baseDir)
        TestReporter.report("CopyPath", "NEG: relativePath falls back to the full path when target is outside base", result: notUnderBase == unrelated.standardizedFileURL.path)

        // NEG: copy() with an empty URL array does not touch the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("sentinel", forType: .string)
        CopyPathService.copy(urls: [], variant: .absolute)
        TestReporter.report("CopyPath", "NEG: copy() with an empty selection leaves the pasteboard untouched", result: pasteboard.string(forType: .string) == "sentinel")

        // POS: copy() with real URLs writes the formatted path(s) to the pasteboard
        CopyPathService.copy(urls: [targetFile], variant: .absolute)
        TestReporter.report(
            "CopyPath",
            "POS: copy() writes the formatted path to the system pasteboard",
            result: pasteboard.string(forType: .string) == targetFile.standardizedFileURL.path
        )

        // POS: copy() with multiple URLs joins the formatted paths with newlines
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let secondFile = tempDir.appendingPathComponent("second file.txt")
        CopyPathService.copy(urls: [targetFile, secondFile], variant: .absolute)
        let expectedMulti = [targetFile.standardizedFileURL.path, secondFile.standardizedFileURL.path].joined(separator: "\n")
        TestReporter.report("CopyPath", "POS: copy() with multiple URLs joins paths with newlines", result: pasteboard.string(forType: .string) == expectedMulti)

        // POS: relativePath does not false-positive match on a base that is a string-prefix but not a path-prefix
        let similarBase = URL(fileURLWithPath: "/Users/test/Doc")
        let similarTarget = URL(fileURLWithPath: "/Users/test/Documents/file.txt")
        let similarResult = CopyPathService.relativePath(of: similarTarget, relativeTo: similarBase)
        TestReporter.report("CopyPath", "NEG: relativePath does not match a base that is only a string-prefix", result: similarResult == similarTarget.standardizedFileURL.path)

        // POS: relativePath handles a base URL with a trailing slash the same as without
        let baseWithSlash = URL(fileURLWithPath: "/Users/test/Documents/")
        let relativeWithSlashBase = CopyPathService.relativePath(of: targetFile, relativeTo: baseWithSlash)
        TestReporter.report("CopyPath", "POS: relativePath handles a trailing-slash base directory", result: relativeWithSlashBase == "My Folder/file (1).txt")
    }
}
