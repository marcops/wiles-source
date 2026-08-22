import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `FileTaggingServiceTests.run()` (see
/// `FileTaggingServiceTests.swift`), following the standalone-file precedent in
/// `ListColumnSettingsTestsCase.swift` — not registered in `WilesAutomatedXCTestCase.swift`.
@MainActor
final class FileTaggingServiceTestsCase: XCTestCase {
    func testFileTaggingService() {
        FileTaggingServiceTests.run()
    }
}
