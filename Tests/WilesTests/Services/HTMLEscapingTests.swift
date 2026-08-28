import Foundation
@testable import Wiles

@MainActor
public enum HTMLEscapingTests {
    public static func run() {
        report(
            "Service/HTMLEscaping",
            "POS: escapes the five HTML-significant characters",
            result:
            HTMLEscaping.escape("&<>\"'") == "&amp;&lt;&gt;&quot;&#39;")

        report(
            "Service/HTMLEscaping",
            "POS: neutralizes a script-injection file name",
            result:
            HTMLEscaping.escape("<img src=x onerror=alert(1)>.txt")
                == "&lt;img src=x onerror=alert(1)&gt;.txt")

        report(
            "Service/HTMLEscaping",
            "NEG: leaves a plain name untouched",
            result:
            HTMLEscaping.escape("Vacation Photos 2024") == "Vacation Photos 2024")

        report(
            "Service/HTMLEscaping",
            "POS: escapes ampersand before other entities (no double-escape)",
            result:
            HTMLEscaping.escape("a & b < c") == "a &amp; b &lt; c")

        report(
            "Service/HTMLEscaping",
            "NEG: empty string stays empty",
            result:
            HTMLEscaping.escape("") == "")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
