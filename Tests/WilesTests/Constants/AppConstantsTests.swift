import XCTest
@testable import Wiles

/// Standalone dedicated suite for `AppConstants` — a tiny enum of static constants plus one computed
/// property (`appName`). Follows the standalone-XCTestCase precedent (see `SpotlightSearchTests`)
/// since this source file has no prior test coverage and needs no wiring elsewhere.
final class AppConstantsTests: XCTestCase {
    // POS: the static string constants hold their expected literal values.
    func testStaticConstantsHoldExpectedValues() {
        XCTAssertEqual(AppConstants.githubURL, "https://github.com/marcops/wiles")
        XCTAssertEqual(AppConstants.githubDisplayString, "github.com/marcops/wiles")
        XCTAssertTrue(
            AppConstants.appVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression) != nil,
            "appVersion (\(AppConstants.appVersion)) must be a semantic X.Y.Z version string")
        XCTAssertEqual(AppConstants.mainWindowID, "main")
    }

    // POS: appName reads Bundle.main's CFBundleName, falling back to an empty string when absent
    // (the test runner's own bundle may or may not define CFBundleName - either way, this must not
    // crash and must return a String).
    func testAppNameReadsBundleMainCFBundleNameOrFallsBackToEmptyString() {
        let expected = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? String()
        XCTAssertEqual(AppConstants.appName, expected)
    }

    // POS: appBuild reads Bundle.main's CFBundleVersion, falling back to "0" when absent (mirrors
    // appName's coverage above — this computed property was previously untested).
    func testAppBuildReadsBundleMainCFBundleVersionOrFallsBackToZero() {
        let expected = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        XCTAssertEqual(AppConstants.appBuild, expected)
    }
}
