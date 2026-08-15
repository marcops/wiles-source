import Foundation
@testable import Wiles

@MainActor
public struct RenameTabModeTests {
    public static func run() {
        testAllCasesAndRawValues()
        testIdMirrorsRawValue()
        testRawValueRoundTrip()
    }

    private static func testAllCasesAndRawValues() {
        let allCases = RenameTabMode.allCases
        report("Feature/RenameTabMode", "POS: RenameTabMode.allCases has exactly 3 cases", result: allCases.count == 3)

        let expectedRawValues: Set = ["Find & Replace", "Prefix & Suffix", "Sequence"]
        let actualRawValues = Set(allCases.map(\.rawValue))
        report("Feature/RenameTabMode", "POS: allCases raw values match the 3 expected tab labels exactly", result: actualRawValues == expectedRawValues)
    }

    private static func testIdMirrorsRawValue() {
        report(
            "Feature/RenameTabMode",
            "POS: Identifiable.id equals rawValue for every case (used by SwiftUI ForEach/Picker)",
            result: RenameTabMode.allCases.allSatisfy { $0.id == $0.rawValue })
    }

    private static func testRawValueRoundTrip() {
        report("Feature/RenameTabMode", "POS: findReplace round-trips via rawValue", result: RenameTabMode(rawValue: "Find & Replace") == .findReplace)
        report("Feature/RenameTabMode", "POS: prefixSuffix round-trips via rawValue", result: RenameTabMode(rawValue: "Prefix & Suffix") == .prefixSuffix)
        report("Feature/RenameTabMode", "POS: sequence round-trips via rawValue", result: RenameTabMode(rawValue: "Sequence") == .sequence)
        report("Feature/RenameTabMode", "NEG: garbage rawValue returns nil", result: RenameTabMode(rawValue: "Not A Real Tab") == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
