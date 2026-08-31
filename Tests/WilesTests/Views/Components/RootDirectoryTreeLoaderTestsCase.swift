import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `RootDirectoryTreeLoaderTests.run()` (finding LL-020), same
/// precedent as `SortOptionTestsCase.swift`.
@MainActor
final class RootDirectoryTreeLoaderTestsCase: XCTestCase {
    func testRootDirectoryTreeLoader() async {
        await RootDirectoryTreeLoaderTests.run()
    }
}
