import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `FileKindCatalogTests.run()` (see `FileKindCatalogTests.swift`),
/// mirroring `ImageFileTypeTestsCase.swift`.
@MainActor
final class FileKindCatalogTestsCase: XCTestCase {
    func testFileKindCatalog() {
        FileKindCatalogTests.run()
    }
}
