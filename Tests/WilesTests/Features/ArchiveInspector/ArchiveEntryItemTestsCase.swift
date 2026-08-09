import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `ArchiveEntryItemTests.run()` (see
/// `ArchiveEntryItemTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to avoid
/// churning that shared wrapper file; same precedent already used by `SortOptionTestsCase.swift`.
@MainActor
final class ArchiveEntryItemTestsCase: XCTestCase {
    func testArchiveEntryItem() {
        ArchiveEntryItemTests.run()
    }
}
