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
}
