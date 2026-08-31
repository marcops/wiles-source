import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `DebouncedDefaultsWriteTests.run()` (finding MM-171), same
/// precedent as `SortOptionTestsCase.swift`.
@MainActor
final class DebouncedDefaultsWriteTestsCase: XCTestCase {
    func testDebouncedDefaultsWrite() {
        DebouncedDefaultsWriteTests.run()
    }
}
