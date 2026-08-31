import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `CancellableWorkTests.run()` (see `CancellableWorkTests.swift`),
/// same precedent as `SortOptionTestsCase.swift`.
final class CancellableWorkTestsCase: XCTestCase {
    func testCancellableWork() async {
        await CancellableWorkTests.run()
    }
}
