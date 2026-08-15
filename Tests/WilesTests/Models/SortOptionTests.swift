import Foundation
@testable import Wiles

@MainActor
public struct SortOptionTests {
    public static func run() {
        testIdEqualsRawValue()
        testRawValueRoundTrip()
        testL10nKeyMapping()
    }

    private static func testIdEqualsRawValue() {
        for option in SortOption.allCases {
            report("Model/SortOption", "POS: id equals rawValue for \(option)", result: option.id == option.rawValue)
        }
    }

    private static func testRawValueRoundTrip() {
        report("Model/SortOption", "POS: CaseIterable has exactly the 8 known cases", result: SortOption.allCases.count == 8)
        for option in SortOption.allCases {
            report("Model/SortOption", "POS: rawValue round-trips for \(option)", result: SortOption(rawValue: option.rawValue) == option)
        }
        report("Model/SortOption", "NEG: garbage rawValue returns nil", result: SortOption(rawValue: "Not A Real Sort Option") == nil)
    }

    /// Exercises every branch of `l10nKey`'s switch, matching the exact mapping in
    /// `Sources/Wiles/Models/SortOption.swift` (each case must map to its documented `L10n.Key`,
    /// not just "any" key, since a wrong-but-non-nil mapping would silently mislabel a Settings/menu
    /// picker without ever failing at compile time).
    private static func testL10nKeyMapping() {
        report("Model/SortOption", "POS: .name maps to L10n.Key.name", result: SortOption.name.l10nKey == .name)
        report("Model/SortOption", "POS: .dateModified maps to L10n.Key.dateModified", result: SortOption.dateModified.l10nKey == .dateModified)
        report("Model/SortOption", "POS: .dateCreated maps to L10n.Key.created", result: SortOption.dateCreated.l10nKey == .created)
        report("Model/SortOption", "POS: .dateAccessed maps to L10n.Key.lastOpened", result: SortOption.dateAccessed.l10nKey == .lastOpened)
        report("Model/SortOption", "POS: .size maps to L10n.Key.size", result: SortOption.size.l10nKey == .size)
        report("Model/SortOption", "POS: .kind maps to L10n.Key.kind", result: SortOption.kind.l10nKey == .kind)
        report("Model/SortOption", "POS: .owner maps to L10n.Key.owner", result: SortOption.owner.l10nKey == .owner)
        report("Model/SortOption", "POS: .group maps to L10n.Key.group", result: SortOption.group.l10nKey == .group)

        // NEG: every case's l10nKey must be distinct - a copy/paste bug in the switch (e.g. two
        // cases returning the same key) would otherwise pass all the POS checks above individually.
        let allKeys = SortOption.allCases.map(\.l10nKey)
        report(
            "Model/SortOption",
            "NEG: every case maps to a distinct L10n.Key (no accidental duplicate mapping)",
            result: Set(allKeys).count == SortOption.allCases.count)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
