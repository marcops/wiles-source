import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `LaunchServicesGateTests.run()` (see
/// `LaunchServicesGateTests.swift`), same precedent as `CancellableWorkTestsCase.swift`.
final class LaunchServicesGateTestsCase: XCTestCase {
    func testLaunchServicesGate() async {
        await LaunchServicesGateTests.run()
    }
}
