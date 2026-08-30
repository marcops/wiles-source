import XCTest
@testable import Wiles

final class L10nActiveCodeTests: XCTestCase {
    func testExplicitLanguageReturnsItsCode() {
        XCTAssertEqual(L10n.activeCode(.portuguese), "pt")
        XCTAssertEqual(L10n.activeCode(.chinese), "zh-Hans")
    }

    func testRegionVariantResolvesToBaseCode() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["en-GB"]), "en")
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["pt-BR"]), "pt")
    }

    func testSimplifiedChineseRegionResolvesToZhHans() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["zh-Hans-CN"]), "zh-Hans")
    }

    func testBareChineseFallsBackToZhHansNotEnglish() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["zh"]), "zh-Hans")
    }

    func testTraditionalChineseFallsBackToZhHansNotEnglish() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["zh-Hant-TW"]), "zh-Hans")
    }

    func testSystemStringIsNeverAMatchCandidate() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["system"]), "en")
    }

    func testUnsupportedLanguageFallsBackToEnglish() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["xh", "zu"]), "en")
    }

    func testFirstSupportedPreferenceWins() {
        XCTAssertEqual(L10n.activeCode(.system, systemPreferredLanguages: ["xh", "fr-CA", "de"]), "fr")
    }
}
