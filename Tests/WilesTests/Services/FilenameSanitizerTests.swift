import XCTest
@testable import Wiles

/// Standalone suite for `FilenameSanitizer` — the rename-input cleanup that keeps a stray `/` or
/// control character from reaching `FileManager` as a raw system error (L74).
final class FilenameSanitizerTests: XCTestCase {
    func testPlainNamePassesThrough() {
        XCTAssertEqual(FilenameSanitizer.sanitize("Report 2024.pdf"), "Report 2024.pdf")
    }

    func testSlashBecomesColonLikeFinder() {
        XCTAssertEqual(FilenameSanitizer.sanitize("a/b"), "a:b")
        XCTAssertEqual(FilenameSanitizer.sanitize("2024/03/notes"), "2024:03:notes")
    }

    func testControlCharactersAreStripped() {
        XCTAssertEqual(FilenameSanitizer.sanitize("na\u{0}me"), "name")
        XCTAssertEqual(FilenameSanitizer.sanitize("line\nbreak\ttab"), "linebreaktab")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(FilenameSanitizer.sanitize("  spaced  "), "spaced")
    }

    func testLeadingDotIsKeptForHiddenFiles() {
        XCTAssertEqual(FilenameSanitizer.sanitize(".gitignore"), ".gitignore")
    }

    func testEmptyOrDotOnlyNamesReturnNil() {
        XCTAssertNil(FilenameSanitizer.sanitize(""))
        XCTAssertNil(FilenameSanitizer.sanitize("   "))
        XCTAssertNil(FilenameSanitizer.sanitize("\n\t"))
        XCTAssertNil(FilenameSanitizer.sanitize("."))
        XCTAssertNil(FilenameSanitizer.sanitize(".."))
    }

    func testAllSlashesCollapseToColonsNotEmpty() {
        XCTAssertEqual(FilenameSanitizer.sanitize("/"), ":")
    }

    // MARK: - B8-7: over-long names are capped at 255, keeping the extension

    func testNameAtOrUnderLimitIsUnchanged() {
        let name = String(repeating: "a", count: 255)
        XCTAssertEqual(FilenameSanitizer.sanitize(name), name)
    }

    func testOverLongNameWithExtensionIsTruncatedKeepingExtension() throws {
        let result = try XCTUnwrap(FilenameSanitizer.sanitize(String(repeating: "a", count: 300) + ".txt"))
        XCTAssertEqual(result.count, 255)
        XCTAssertEqual((result as NSString).pathExtension, "txt")
        XCTAssertTrue(result.hasPrefix("aaa"))
    }

    /// LL-010: when the "extension" alone is ≥ 255 bytes (degenerate input), the result must still
    /// be `<stem>.<ext>` shaped and within the byte cap — not a name hard-cut through the middle of
    /// the extension.
    func testExtensionLongerThanTheByteCapIsItselfTruncatedKeepingTheDot() throws {
        let hugeExt = String(repeating: "z", count: 400)
        let result = try XCTUnwrap(FilenameSanitizer.sanitize("report." + hugeExt))
        XCTAssertLessThanOrEqual(result.utf8.count, 255)
        XCTAssertTrue(result.contains("."), "the dot separator must survive")
        let ext = (result as NSString).pathExtension
        XCTAssertFalse(ext.isEmpty, "the result still has an extension component")
        XCTAssertTrue(ext.allSatisfy { $0 == "z" }, "the extension is a clean prefix of the original, not garbled")
        XCTAssertFalse(result.hasSuffix("."), "no dangling trailing dot")
    }

    func testOverLongNameWithoutExtensionIsHardTruncated() {
        let result = FilenameSanitizer.sanitize(String(repeating: "b", count: 500))
        XCTAssertEqual(result, String(repeating: "b", count: 255))
    }

    func testTruncationHappensAfterControlStrippingAndTrimming() {
        // 260 real chars once the NULs are stripped → truncated to 255.
        let raw = "  " + String(repeating: "c\u{0}", count: 260) + "  "
        XCTAssertEqual(FilenameSanitizer.sanitize(raw)?.count, 255)
    }

    // MARK: - The 255 cap is UTF-8 bytes, not Characters

    func testMultiByteNameUnderCharCountButOverByteLimitIsTruncated() throws {
        // 200 emoji: 200 Characters (well under 255) but 800 UTF-8 bytes — a char-count cap let it through.
        let result = try XCTUnwrap(FilenameSanitizer.sanitize(String(repeating: "😀", count: 200)))
        XCTAssertLessThanOrEqual(result.utf8.count, 255)
        XCTAssertTrue(result.allSatisfy { $0 == "😀" }, "grapheme clusters must not be split")
    }

    func testMultiByteNameKeepsExtensionWithinByteLimit() throws {
        let result = try XCTUnwrap(FilenameSanitizer.sanitize(String(repeating: "café", count: 80) + ".txt"))
        XCTAssertLessThanOrEqual(result.utf8.count, 255)
        XCTAssertEqual((result as NSString).pathExtension, "txt")
    }

    func testMultiByteNameUnderByteLimitIsUnchanged() {
        let raw = String(repeating: "é", count: 120) // 240 UTF-8 bytes
        XCTAssertEqual(FilenameSanitizer.sanitize(raw), raw)
    }
}
