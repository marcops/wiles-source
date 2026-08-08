import XCTest
@testable import Wiles
import AppKit

/// Records calls instead of touching the real OS — see `WorkspaceOpening`. This is what makes
/// `NetworkServerService.connectToServer`'s real success path finally safe to exercise: no real
/// network mount is attempted, nothing can present a blocking system alert.
@MainActor
private final class FakeWorkspaceOpener: WorkspaceOpening {
    private(set) var openedSingleURLs: [URL] = []

    func open(
        _ urls: [URL],
        withApplicationAt applicationURL: URL,
        configuration: NSWorkspace.OpenConfiguration,
        completionHandler: (@Sendable (NSRunningApplication?, Error?) -> Void)?
    ) {}

    func open(_ url: URL) -> Bool {
        openedSingleURLs.append(url)
        return true
    }
}

/// Standalone dedicated suite for `NetworkServerService` (see `SpotlightSearchTests` for the same
/// standalone-`XCTestCase` precedent — needs no wiring into `WilesAutomatedXCTestCase.swift`).
@MainActor
final class NetworkServerServiceTests: XCTestCase {
    func testConnectToServerWithEmptyAddressIsNoOp() {
        XCTAssertNoThrow(try NetworkServerService.connectToServer(urlAddress: "   "))
    }

    func testConnectToServerWithInvalidURLThrows() {
        // A backslash is not a valid character in this position for `URL(string:)` to accept,
        // reaching the `throw` branch instead of the guard-empty return or the real `.open(url)` call.
        XCTAssertThrowsError(try NetworkServerService.connectToServer(urlAddress: "smb://\\\\bad url with spaces"))
    }

    // POS: a syntactically valid address reaches the real NSWorkspace.shared.open(url) call site —
    // now safe to exercise for real via the injected WorkspaceOpening seam instead of attempting a
    // real network mount.
    func testConnectToServerWithValidAddressCallsThroughToTheInjectedOpener() throws {
        let fake = FakeWorkspaceOpener()
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        try NetworkServerService.connectToServer(urlAddress: "myserver.local")

        XCTAssertEqual(fake.openedSingleURLs, [URL(string: "smb://myserver.local")])
    }

    // POS: an address that already includes a scheme is passed through unchanged rather than
    // getting an "smb://" prefix prepended a second time.
    func testConnectToServerWithExistingSchemePassesAddressThroughUnchanged() throws {
        let fake = FakeWorkspaceOpener()
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        try NetworkServerService.connectToServer(urlAddress: "ftp://myserver.local")

        XCTAssertEqual(fake.openedSingleURLs, [URL(string: "ftp://myserver.local")])
    }
}
