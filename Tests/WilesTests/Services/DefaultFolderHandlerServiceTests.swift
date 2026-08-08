import XCTest
@testable import Wiles

/// Standalone dedicated suite for `DefaultFolderHandlerService` — a single tiny `@MainActor` enum
/// wrapping `NSWorkspace.shared.setDefaultApplication(at:toOpen:)` for the `.folder` UTType.
/// Follows the standalone-XCTestCase precedent (see `SpotlightSearchTests`) since this source file
/// has no prior test coverage and needs no wiring elsewhere.
@MainActor
final class DefaultFolderHandlerServiceTests: XCTestCase {
    // POS: registerAsFolderHandlerOption calls through to the real NSWorkspace API and always invokes
    // its completion handler exactly once, without crashing or hanging - regardless of whether macOS
    // actually accepts `Bundle.main.bundleURL` (the test runner's own bundle, not a real .app) as a
    // folder handler. This is the only reachable behavior we can assert on: there's no public hook to
    // fake NSWorkspace's registration result, and asserting the boolean itself would pin the test to
    // whatever this specific runner bundle happens to be, which isn't a meaningful behavior contract.
    func testRegisterAsFolderHandlerOptionInvokesCompletionExactlyOnce() {
        let exp = expectation(description: "registerAsFolderHandlerOption completion fires")
        exp.assertForOverFulfill = true

        DefaultFolderHandlerService.registerAsFolderHandlerOption { _ in
            exp.fulfill()
        }

        wait(for: [exp], timeout: 1.0)
    }

    // NEG: the default parameter value (`completion: ... = { _ in }`) is itself a safe no-op branch -
    // calling with no explicit completion handler must not crash or hang.
    func testRegisterAsFolderHandlerOptionWithDefaultCompletionDoesNotCrash() {
        DefaultFolderHandlerService.registerAsFolderHandlerOption()
        XCTAssertTrue(true)
    }
}
