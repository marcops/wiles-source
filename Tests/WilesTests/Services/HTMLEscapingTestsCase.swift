import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `HTMLEscapingTests.run()`. Standalone-file precedent:
/// `ListColumnSettingsTestsCase.swift`.
@MainActor
final class HTMLEscapingTestsCase: XCTestCase {
    func testHTMLEscaping() {
        HTMLEscapingTests.run()
    }
}
