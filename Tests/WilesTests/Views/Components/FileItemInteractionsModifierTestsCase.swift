import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `FileItemInteractionsModifierTests.run()` (finding LB-030),
/// same precedent as `SortOptionTestsCase.swift`.
@MainActor
final class FileItemInteractionsModifierTestsCase: XCTestCase {
    func testFileItemInteractionsModifier() {
        FileItemInteractionsModifierTests.run()
    }
}
