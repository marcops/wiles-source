@testable import Wiles
import SwiftUI

@MainActor
public struct TagColorTests {
    public static func run() {
        testKnownTagNamesMapToExpectedColors()
        testMatchingIsCaseInsensitive()
        testUnknownTagFallsBackToSecondary()
    }

    private static func testKnownTagNamesMapToExpectedColors() {
        report("View/TagColor", "POS: colorForTag(\"red\") returns .red", result: colorForTag("red") == .red)
        report("View/TagColor", "POS: colorForTag(\"orange\") returns .orange", result: colorForTag("orange") == .orange)
        report("View/TagColor", "POS: colorForTag(\"yellow\") returns .yellow", result: colorForTag("yellow") == .yellow)
        report("View/TagColor", "POS: colorForTag(\"green\") returns .green", result: colorForTag("green") == .green)
        report("View/TagColor", "POS: colorForTag(\"blue\") returns .blue", result: colorForTag("blue") == .blue)
        report("View/TagColor", "POS: colorForTag(\"purple\") returns .purple", result: colorForTag("purple") == .purple)
        report("View/TagColor", "POS: colorForTag(\"gray\") returns .gray", result: colorForTag("gray") == .gray)
        report("View/TagColor", "POS: colorForTag(\"grey\") (alternate spelling) also returns .gray", result: colorForTag("grey") == .gray)
    }

    private static func testMatchingIsCaseInsensitive() {
        report("View/TagColor", "POS: colorForTag(\"RED\") matches case-insensitively", result: colorForTag("RED") == .red)
        report("View/TagColor", "POS: colorForTag(\"Blue\") matches case-insensitively", result: colorForTag("Blue") == .blue)
    }

    private static func testUnknownTagFallsBackToSecondary() {
        report("View/TagColor", "NEG: colorForTag(\"chartreuse\") (unrecognized name) falls back to .secondary", result: colorForTag("chartreuse") == .secondary)
        report("View/TagColor", "NEG: colorForTag(\"\") (empty string) falls back to .secondary", result: colorForTag("") == .secondary)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
