import AppKit
import XCTest
@testable import Wiles

/// Standalone dedicated suite for `RealWorkspaceOpener` (see `SystemAppearanceObserverTests`/
/// `NetworkServerServiceTests` for the same standalone-`XCTestCase` precedent).
///
/// Deliberately does NOT call either forwarding method with a real target: `NSWorkspace.shared.
/// open(_:)` on a nonexistent local file URL does not fail silently — it pops a real, visible
/// macOS "file couldn't be found" alert (confirmed; a previous version of this test assumed
/// otherwise and was wrong). `RealWorkspaceOpener` is intentionally a thin, seamless pass-through
/// to the real `NSWorkspace` API — that's its whole purpose in production, injected behind
/// `WorkspaceOpening` everywhere it's actually used — so there is no way to invoke either method
/// here without either triggering real system UI or genuinely launching an application. Covering
/// the two one-line forwarding bodies is exactly the "disproportionate cost" case WILES_RULES.md
/// carves out: the risk of a wrong forward is near zero, and the only way to exercise it is a
/// visible, disruptive side effect.
@MainActor
final class RealWorkspaceOpenerTests: XCTestCase {
    func testConformsToWorkspaceOpeningProtocol() {
        let opener: WorkspaceOpening = RealWorkspaceOpener()
        XCTAssertNotNil(opener)
    }
}
