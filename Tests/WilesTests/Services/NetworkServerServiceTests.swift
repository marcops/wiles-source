import AppKit
import XCTest
@testable import Wiles

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
        let fake = NetworkServerFakeWorkspaceOpener()
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        try NetworkServerService.connectToServer(urlAddress: "myserver.local")

        XCTAssertEqual(fake.openedSingleURLs, [URL(string: "smb://myserver.local")])
    }

    // POS: an address that already includes a scheme is passed through unchanged rather than
    // getting an "smb://" prefix prepended a second time.
    func testConnectToServerWithExistingSchemePassesAddressThroughUnchanged() throws {
        let fake = NetworkServerFakeWorkspaceOpener()
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        try NetworkServerService.connectToServer(urlAddress: "ftp://myserver.local")

        XCTAssertEqual(fake.openedSingleURLs, [URL(string: "ftp://myserver.local")])
    }

    // LU-020: a share name with spaces ("Time Machine Backups") is a legitimate target. It must
    // resolve to a URL (percent-encoded) and reach the opener, not fail as "invalid URL".
    func testConnectToServerAcceptsAShareNameContainingSpaces() throws {
        let fake = NetworkServerFakeWorkspaceOpener()
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        try NetworkServerService.connectToServer(urlAddress: "nas.local/Time Machine Backups")

        XCTAssertEqual(fake.openedSingleURLs.count, 1)
        let opened = fake.openedSingleURLs.first
        XCTAssertEqual(opened?.scheme, "smb")
        XCTAssertFalse(opened?.absoluteString.contains(" ") ?? true, "the space must be encoded, not passed raw")
        XCTAssertTrue(opened?.absoluteString.contains("Time%20Machine%20Backups") ?? false)
    }

    func testServerURLResolvesSpacesButRejectsGenuineGarbage() {
        let withSpaces = NetworkServerService.serverURL(fromFullAddress: "smb://nas/My Share")
        XCTAssertNotNil(withSpaces)
        XCTAssertFalse(withSpaces?.absoluteString.contains(" ") ?? true)

        // An already-encoded address round-trips unchanged.
        XCTAssertEqual(
            NetworkServerService.serverURL(fromFullAddress: "smb://nas/already%20encoded"),
            URL(string: "smb://nas/already%20encoded"))

        // Backslashes are still invalid even after the space fallback.
        XCTAssertNil(NetworkServerService.serverURL(fromFullAddress: "smb://\\\\still bad"))
    }

    // POS: when the injected opener reports failure (mirrors a real connection failure), the
    // NSError-construction branch is reached and thrown, instead of returning silently.
    func testConnectToServerThrowsServerConnectionFailedWhenOpenerReportsFailure() throws {
        let fake = NetworkServerFakeWorkspaceOpener()
        fake.shouldFailToOpen = true
        let previousOpener = NetworkServerService.opener
        NetworkServerService.opener = fake
        defer { NetworkServerService.opener = previousOpener }

        XCTAssertThrowsError(try NetworkServerService.connectToServer(urlAddress: "unreachable.local")) { error in
            // M5: now throws WilesError.localized so AppState.showError localizes it in the in-app
            // language; the message still carries the address via the {0} token.
            guard case let WilesError.localized(key, arguments) = error else {
                return XCTFail("expected WilesError.localized, got \(error)")
            }
            XCTAssertEqual(key, .serverConnectionFailed)
            XCTAssertEqual(arguments, ["smb://unreachable.local"])
            XCTAssertTrue(
                (error as? WilesError)?.localizedMessage(lang: .english).contains("smb://unreachable.local") ?? false)
        }
    }
}
