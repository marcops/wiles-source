import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `ImageFileTypeTests.run()` (see `ImageFileTypeTests.swift`),
/// mirroring `BoundedFolderNodeCacheTestsCase.swift`.
@MainActor
final class ImageFileTypeTestsCase: XCTestCase {
    func testImageFileType() {
        ImageFileTypeTests.run()
    }
}
