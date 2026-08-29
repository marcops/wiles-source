import XCTest
@testable import Wiles

/// Standalone dedicated suite for `ByteFormat` — a lock-guarded shared `ByteCountFormatter`
/// (countStyle .file) wrapper. Follows the standalone-XCTestCase precedent (see `AppConstantsTests`)
/// since this source file has no prior coverage and needs no wiring elsewhere.
final class ByteFormatTests: XCTestCase {
    // POS: zero bytes still formats to a non-empty human-readable string.
    func testZeroBytesProducesNonEmptyString() {
        XCTAssertFalse(ByteFormat.fileSize(0).isEmpty)
    }

    // POS: output equals a locally built ByteCountFormatter's for the same value, keeping the
    // assertion locale-independent.
    func testMatchesReferenceByteCountFormatter() {
        let reference = ByteCountFormatter()
        reference.countStyle = .file
        XCTAssertEqual(ByteFormat.fileSize(1_500_000), reference.string(fromByteCount: 1_500_000))
    }

    // POS: the shared formatter isn't corrupted between calls — same input yields the same output.
    func testRepeatedCallsReturnStableResult() {
        XCTAssertEqual(ByteFormat.fileSize(1_500_000), ByteFormat.fileSize(1_500_000))
    }
}
