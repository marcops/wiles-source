import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `SortOptionTests.run()` (see `SortOptionTests.swift`).
/// `SortOption.swift` has no entry in `WilesAutomatedXCTestCase.swift`'s `testModelSuites()` today;
/// per AGENTS.md rule 28 (don't silently skip coverage) and the same precedent already used by
/// `SpotlightSearchTests.swift`, this makes the new suite discoverable to `swift test` and code
/// coverage without editing that shared wrapper file.
@MainActor
final class SortOptionTestsCase: XCTestCase {
    func testSortOption() {
        SortOptionTests.run()
    }
}
