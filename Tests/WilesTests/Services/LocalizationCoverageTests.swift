@testable import Wiles
import Foundation

@MainActor
public struct LocalizationCoverageTests {
    public static func run() {
        testActiveCode()
        testStringLookupAcrossLanguages()
        testOrphanKeys()
        testAllCasesDisplayNames()
    }

    private static func testActiveCode() {
        // POS: explicit non-system language always wins immediately, regardless of host locale
        TestReporter.report("Localization", "POS: activeCode(.english) returns 'en'", result: L10n.activeCode(.english) == "en")
        TestReporter.report("Localization", "POS: activeCode(.portuguese) returns 'pt'", result: L10n.activeCode(.portuguese) == "pt")

        // NEG: .system with no supported preferred language should fall back to "en"
        // (this is exercised indirectly since we can't override Locale.preferredLanguages in-process,
        // but we can at least assert the fallback path returns a non-empty supported code)
        let systemCode = L10n.activeCode(.system)
        let supportedCodes = AppLanguage.allCases.map { $0.rawValue }
        TestReporter.report(
            "Localization", "POS: activeCode(.system) returns one of the supported codes (or 'en' fallback)",
            result: supportedCodes.contains(systemCode) || systemCode == "en"
        )
    }

    private static func testStringLookupAcrossLanguages() {
        let languagesToSpotCheck: [AppLanguage] = [.english, .portuguese, .japanese, .arabic, .chinese]
        let allNonEmpty = languagesToSpotCheck.allSatisfy { !L10n.string(.cancel, lang: $0).isEmpty }
        TestReporter.report(
            "Localization", "POS: L10n.string(.cancel, lang:) returns a non-empty string for english, portuguese, japanese, arabic, chinese",
            result: allNonEmpty
        )
    }

    private static func testOrphanKeys() {
        // NEG: known-orphan keys that were never given catalog entries must not crash,
        // and should still return SOME non-crashing string (even if it's just the raw key as fallback).
        let orphanKeys: [L10n.Key] = [.itemsCount, .itemsCountWithSize, .selectedItemsCount, .selectedItemsCountWithSize]
        var allReturnedSomething = true
        for key in orphanKeys {
            let value = L10n.string(key, lang: .english)
            if value.isEmpty { allReturnedSomething = false }
        }
        TestReporter.report(
            "Localization", "NEG: L10n.string on orphan keys (itemsCount, itemsCountWithSize, selectedItemsCount, selectedItemsCountWithSize) does not crash and returns a non-empty fallback string",
            result: allReturnedSomething
        )
    }

    private static func testAllCasesDisplayNames() {
        let allCases = AppLanguage.allCases
        let allHaveDisplayNames = allCases.allSatisfy { !$0.displayName.isEmpty }
        TestReporter.report(
            "Localization", "POS: AppLanguage has exactly 16 cases and every case has a non-empty displayName",
            result: allCases.count == 16 && allHaveDisplayNames
        )
    }
}
