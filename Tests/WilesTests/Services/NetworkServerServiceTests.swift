import XCTest
@testable import Wiles

/// Standalone dedicated suite for `NetworkServerService` (see `SpotlightSearchTests` for the same
/// standalone-`XCTestCase` precedent — needs no wiring into `WilesAutomatedXCTestCase.swift`).
/// Only the two guard branches are covered here: the real `NSWorkspace.shared.open(url)` success
/// path is not safely testable (see `UI_TEST_BACKLOG.md` — it would attempt a real network mount).
final class NetworkServerServiceTests: XCTestCase {
    func testConnectToServerWithEmptyAddressIsNoOp() {
        XCTAssertNoThrow(try NetworkServerService.connectToServer(urlAddress: "   "))
    }

    func testConnectToServerWithInvalidURLThrows() {
        // A backslash is not a valid character in this position for `URL(string:)` to accept,
        // reaching the `throw` branch instead of the guard-empty return or the real `.open(url)` call.
        XCTAssertThrowsError(try NetworkServerService.connectToServer(urlAddress: "smb://\\\\bad url with spaces"))
    }
}
