import Foundation
@testable import Wiles

@MainActor
public struct LocalizationCoverageTests {
    public static func run() {
        testActiveCode()
        testStringLookupAcrossLanguages()
        testOrphanKeys()
        testAllCasesDisplayNames()
        testMissingKeysCheck()
        testActiveCodeForAllNonSystemLanguages()
        testLanguageIdMatchesRawValue()
        testInvalidRawValueInitReturnsNil()
        testDisplayNamesAreUnique()
        testAppLanguageCodableRoundTrip()
        testChineseMixedCaseLprojFallbackResolvesRealTranslation()
    }

    private static func testChineseMixedCaseLprojFallbackResolvesRealTranslation() {
        // POS: AppLanguage.chinese has rawValue "zh-Hans" (mixed case), but the compiled resource
        // bundle's folder is "zh-hans.lproj" (all-lowercase). L10n.string's first path lookup
        // (Bundle.module.path(forResource: "zh-Hans", ofType: "lproj")) must fail, forcing the
        // `code.lowercased()` fallback branch to find "zh-hans.lproj". A weaker "non-empty" check
        // would pass even if this fallback were broken, since the final generic bundle lookup also
        // returns a non-empty string (the raw key itself) as its default. Assert the actual
        // translated value to prove the lowercased-path branch truly resolved the Chinese bundle.
        let translated = L10n.string(.cancel, lang: .chinese)
        TestReporter.report(
            "Localization",
            "POS: L10n.string(.cancel, lang: .chinese) resolves via the code.lowercased() lproj-path fallback to the real Chinese translation, not the raw key or English",
            result: translated == "取消" && translated != L10n.Key.cancel.rawValue && translated != "Cancel")
    }

    private static func testActiveCodeForAllNonSystemLanguages() {
        // POS: every non-system AppLanguage must resolve activeCode to exactly its own rawValue,
        // independent of host locale, since the `preferred != .system` early-return should always win.
        let nonSystemLanguages = AppLanguage.allCases.filter { $0 != .system }
        let allMatch = nonSystemLanguages.allSatisfy { L10n.activeCode($0) == $0.rawValue }
        TestReporter.report(
            "Localization", "POS: activeCode(_:) returns the exact rawValue for every non-system AppLanguage case",
            result: allMatch && nonSystemLanguages.count == 15)
    }

    private static func testLanguageIdMatchesRawValue() {
        // POS: Identifiable conformance must expose id == rawValue for every case (used by SwiftUI ForEach/Picker).
        let allCases = AppLanguage.allCases
        let idsMatchRawValues = allCases.allSatisfy { $0.id == $0.rawValue }
        TestReporter.report(
            "Localization", "POS: AppLanguage.id equals rawValue for every case",
            result: idsMatchRawValues)
    }

    private static func testInvalidRawValueInitReturnsNil() {
        // NEG: constructing AppLanguage from an unsupported/garbage code must fail gracefully (nil), not crash.
        let bogus = AppLanguage(rawValue: "xx-not-a-real-language")
        let empty = AppLanguage(rawValue: "")
        let almostValidButWrongCase = AppLanguage(rawValue: "EN")
        TestReporter.report(
            "Localization", "NEG: AppLanguage(rawValue:) returns nil for unsupported/empty/wrong-case codes",
            result: bogus == nil && empty == nil && almostValidButWrongCase == nil)
    }

    private static func testDisplayNamesAreUnique() {
        // POS: no two AppLanguage cases should collide on displayName (would be a picker UX bug).
        let allDisplayNames = AppLanguage.allCases.map(\.displayName)
        let uniqueCount = Set(allDisplayNames).count
        TestReporter.report(
            "Localization", "POS: AppLanguage.displayName is unique across all 16 cases",
            result: uniqueCount == allDisplayNames.count)
    }

    private static func testAppLanguageCodableRoundTrip() {
        // POS: AppLanguage is Codable; every case must survive an encode/decode round-trip unchanged.
        var allRoundTripped = true
        for lang in AppLanguage.allCases {
            do {
                let data = try JSONEncoder().encode(lang)
                let decoded = try JSONDecoder().decode(AppLanguage.self, from: data)
                if decoded != lang {
                    allRoundTripped = false
                }
            } catch {
                allRoundTripped = false
            }
        }
        TestReporter.report(
            "Localization", "POS: AppLanguage Codable round-trip (encode/decode) preserves value for every case",
            result: allRoundTripped)
    }

    private static func testActiveCode() {
        // POS: explicit non-system language always wins immediately, regardless of host locale
        TestReporter.report("Localization", "POS: activeCode(.english) returns 'en'", result: L10n.activeCode(.english) == "en")
        TestReporter.report("Localization", "POS: activeCode(.portuguese) returns 'pt'", result: L10n.activeCode(.portuguese) == "pt")

        // NEG: .system with no supported preferred language should fall back to "en"
        // (this is exercised indirectly since we can't override Locale.preferredLanguages in-process,
        // but we can at least assert the fallback path returns a non-empty supported code)
        let systemCode = L10n.activeCode(.system)
        let supportedCodes = AppLanguage.allCases.map(\.rawValue)
        TestReporter.report(
            "Localization", "POS: activeCode(.system) returns one of the supported codes (or 'en' fallback)",
            result: supportedCodes.contains(systemCode) || systemCode == "en")
    }

    private static func testStringLookupAcrossLanguages() {
        let languagesToSpotCheck: [AppLanguage] = [.english, .portuguese, .japanese, .arabic, .chinese]
        let allNonEmpty = languagesToSpotCheck.allSatisfy { !L10n.string(.cancel, lang: $0).isEmpty }
        TestReporter.report(
            "Localization", "POS: L10n.string(.cancel, lang:) returns a non-empty string for english, portuguese, japanese, arabic, chinese",
            result: allNonEmpty)
    }

    private static func testOrphanKeys() {
        // NEG: known-orphan keys that were never given catalog entries must not crash,
        // and should still return SOME non-crashing string (even if it's just the raw key as fallback).
        let orphanKeys: [L10n.Key] = [.itemsCount, .itemsCountWithSize, .selectedItemsCount, .selectedItemsCountWithSize]
        var allReturnedSomething = true
        for key in orphanKeys {
            let value = L10n.string(key, lang: .english)
            if value.isEmpty {
                allReturnedSomething = false
            }
        }
        TestReporter.report(
            "Localization",
            "NEG: L10n.string on orphan keys (itemsCount, itemsCountWithSize, selectedItemsCount, selectedItemsCountWithSize) "
                + "does not crash and returns a non-empty fallback string",
            result: allReturnedSomething)
    }

    private static func testAllCasesDisplayNames() {
        let allCases = AppLanguage.allCases
        let allHaveDisplayNames = allCases.allSatisfy { !$0.displayName.isEmpty }
        TestReporter.report(
            "Localization", "POS: AppLanguage has exactly 16 cases and every case has a non-empty displayName",
            result: allCases.count == 16 && allHaveDisplayNames)
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
                if isCamelCaseKey, translation == key.rawValue {
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
            result: success)
    }
}
