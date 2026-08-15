import Foundation
@testable import Wiles

@MainActor
public struct BatchRenameModeTests {
    public static func run() {
        testReplaceModeStoresValues()
        testAddPrefixSuffixModeStoresValues()
        testSequenceNumberModeStoresValues()
        testRegexModeStoresValues()
        testEachModeMatchesOnlyItsOwnCase()
    }

    private static func testReplaceModeStoresValues() {
        let mode = BatchRenameMode.replace(find: "img_", replaceWith: "photo_")
        if case let .replace(find, replaceWith) = mode {
            report("Feature/BatchRenameMode", "POS: .replace preserves find and replaceWith exactly", result: find == "img_" && replaceWith == "photo_")
        } else {
            report("Feature/BatchRenameMode", "POS: .replace preserves find and replaceWith exactly", result: false)
        }
    }

    private static func testAddPrefixSuffixModeStoresValues() {
        let mode = BatchRenameMode.addPrefixSuffix(prefix: "PRE_", suffix: "_POST")
        if case let .addPrefixSuffix(prefix, suffix) = mode {
            report("Feature/BatchRenameMode", "POS: .addPrefixSuffix preserves prefix and suffix exactly", result: prefix == "PRE_" && suffix == "_POST")
        } else {
            report("Feature/BatchRenameMode", "POS: .addPrefixSuffix preserves prefix and suffix exactly", result: false)
        }

        let emptyMode = BatchRenameMode.addPrefixSuffix(prefix: "", suffix: "")
        if case let .addPrefixSuffix(prefix, suffix) = emptyMode {
            report(
                "Feature/BatchRenameMode",
                "NEG: .addPrefixSuffix accepts empty prefix/suffix without altering them",
                result: prefix.isEmpty && suffix.isEmpty)
        } else {
            report("Feature/BatchRenameMode", "NEG: .addPrefixSuffix accepts empty prefix/suffix without altering them", result: false)
        }
    }

    private static func testSequenceNumberModeStoresValues() {
        let mode = BatchRenameMode.sequenceNumber(prefix: "IMG_", startNumber: 7, paddingDigits: 3)
        if case let .sequenceNumber(prefix, startNumber, paddingDigits) = mode {
            report(
                "Feature/BatchRenameMode",
                "POS: .sequenceNumber preserves prefix, startNumber, and paddingDigits exactly",
                result: prefix == "IMG_" && startNumber == 7 && paddingDigits == 3)
        } else {
            report("Feature/BatchRenameMode", "POS: .sequenceNumber preserves prefix, startNumber, and paddingDigits exactly", result: false)
        }
    }

    private static func testRegexModeStoresValues() {
        let mode = BatchRenameMode.regex(pattern: "file_(.*)", template: "document_$1")
        if case let .regex(pattern, template) = mode {
            report("Feature/BatchRenameMode", "POS: .regex preserves pattern and template exactly", result: pattern == "file_(.*)" && template == "document_$1")
        } else {
            report("Feature/BatchRenameMode", "POS: .regex preserves pattern and template exactly", result: false)
        }
    }

    /// NEG coverage: makes sure the four cases are genuinely distinct - a copy/paste bug that made
    /// two cases pattern-match each other would silently corrupt `BatchRenameService`'s dispatch.
    private static func testEachModeMatchesOnlyItsOwnCase() {
        let modes: [BatchRenameMode] = [
            .replace(find: "a", replaceWith: "b"),
            .addPrefixSuffix(prefix: "a", suffix: "b"),
            .sequenceNumber(prefix: "a", startNumber: 1, paddingDigits: 1),
            .regex(pattern: "a", template: "b")
        ]

        func labelIndex(for mode: BatchRenameMode) -> Int {
            switch mode {
            case .replace: 0
            case .addPrefixSuffix: 1
            case .sequenceNumber: 2
            case .regex: 3
            }
        }

        let labels = modes.map(labelIndex(for:))
        report(
            "Feature/BatchRenameMode",
            "POS: each of the 4 cases resolves to a distinct branch in an exhaustive switch",
            result: labels == [0, 1, 2, 3])
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
