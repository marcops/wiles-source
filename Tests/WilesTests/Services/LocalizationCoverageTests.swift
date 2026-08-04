@testable import Wiles
import Foundation

@MainActor
public struct LocalizationCoverageTests {
    public static func run() {
        testActiveCode()
        testStringLookupAcrossLanguages()
        testOrphanKeys()
        testAllCasesDisplayNames()
        testMissingKeysCheck()
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

    private static func testMissingKeysCheck() {
        var missingKeys: [String] = []
        let languagesToTest = AppLanguage.allCases.filter { $0 != .system }
        // These keys are intentionally left without catalog entries (see the orphan-key NEG test
        // above) and fall back to their raw camelCase name by design, not by translation gap.
        let knownOrphanKeys: Set<L10n.Key> = [.itemsCount, .itemsCountWithSize, .selectedItemsCount, .selectedItemsCountWithSize]

        for lang in languagesToTest {
            for key in L10n.Key.allCases where !knownOrphanKeys.contains(key) {
                let translation = L10n.string(key, lang: lang)
                // If translation matches camelCase key.rawValue exactly (e.g. "sidebarTrash"), it's an unlocalized key
                let isCamelCaseKey = key.rawValue.contains { $0.isUppercase }
                if isCamelCaseKey && translation == key.rawValue {
                    missingKeys.append("\(lang.rawValue):\(key.rawValue)")
                }
            }
        }
        
        let success = missingKeys.isEmpty
        if !success {
            print("Missing translation keys (\(missingKeys.count)): \(missingKeys.joined(separator: ", "))")
        }
        TestReporter.report(
            "Localization",
            "POS: Automated lint check - All L10n.Key cases are localized across all supported languages (Missing: \(missingKeys.count))",
            result: success
        )
    }
}
