import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `ZIPCentralDirectoryReaderTests.run()` (see
/// `ZIPCentralDirectoryReaderTests.swift`). Not registered in `WilesAutomatedXCTestCase.swift` to
/// avoid churning that shared wrapper file; same precedent already used by
/// `SortOptionTestsCase.swift`.
@MainActor
final class ZIPCentralDirectoryReaderTestsCase: XCTestCase {
    func testZIPCentralDirectoryReader() {
        ZIPCentralDirectoryReaderTests.run()
    }
}
