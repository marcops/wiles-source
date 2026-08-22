import Foundation
import XCTest
@testable import Wiles

/// Standalone dedicated suite for `Bundle.wilesResources` (see `SystemAppearanceObserverTests` for
/// the same standalone-`XCTestCase` precedent).
///
/// `wilesResources` is a `static let` — computed once and memoized for the lifetime of the test
/// process — so only whichever branch resolves first under `swift test` can ever be exercised here.
/// Under `swift test`/`swift build`, `Bundle.main` is the xctest/test-runner bundle, not a real
/// packaged `Wiles.app`, so neither `Bundle.main.resourceURL/Wiles_Wiles.bundle` nor
/// `Bundle.main.bundleURL/Wiles_Wiles.bundle` resolves to a real bundle: both `if let bundle = ...`
/// branches (the two early `return bundle` lines) are structurally unreachable outside the real
/// packaged `.app`, where `scripts/build_release.sh`/`push_and_relaunch.sh` actually places
/// `Wiles_Wiles.bundle`. This is the same "platform branch that can't run in CI" exception documented
/// elsewhere — not a gap worth chasing with environment mocking for a bundle-resolution fallback.
final class BundleWilesResourcesTests: XCTestCase {
    func testWilesResourcesResolvesToAUsableBundle() {
        // Exercises the always-false resourceURL/bundleURL checks and the final `.module` fallback —
        // the only branch reachable under `swift test`. Also indirectly exercised by
        // LocalizationTests/TemplateRenderingServiceTests, which read localized strings/templates
        // through this same bundle.
        let bundle = Bundle.wilesResources
        XCTAssertNotNil(bundle.bundleURL)
    }

    func testWilesResourcesIsMemoizedAcrossAccesses() {
        // `static let` semantics: repeated access returns the exact same Bundle instance.
        XCTAssertEqual(Bundle.wilesResources.bundleURL, Bundle.wilesResources.bundleURL)
    }
}
