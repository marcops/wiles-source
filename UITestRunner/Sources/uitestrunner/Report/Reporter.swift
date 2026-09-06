import Foundation

/// Collects one line per feature step and prints a final pass/fail summary. `continueOnFailure`
/// mirrors the old XCUITest `continueAfterFailure = true`: a failing step is recorded and the
/// walkthrough moves on, so one run surfaces every broken feature at once.
final class Reporter {
    struct Entry {
        let feature: String
        let detail: String
        let passed: Bool
    }

    private(set) var entries: [Entry] = []
    private var currentFeature = "—"

    var hasFailures: Bool { entries.contains { !$0.passed } }

    func beginFeature(_ name: String) {
        currentFeature = name
        print("\n▶ \(name)")
    }

    func pass(_ detail: String) {
        entries.append(Entry(feature: currentFeature, detail: detail, passed: true))
        print("  ✓ \(detail)")
    }

    func fail(_ detail: String) {
        entries.append(Entry(feature: currentFeature, detail: detail, passed: false))
        print("  ✗ \(detail)")
    }

    /// Records pass/fail from a boolean and returns it, for `guard check(...) else { return }`.
    @discardableResult
    func check(_ condition: Bool, _ detail: String) -> Bool {
        if condition { pass(detail) } else { fail(detail) }
        return condition
    }

    func printSummary() {
        let failed = entries.filter { !$0.passed }
        print("\n" + String(repeating: "─", count: 60))
        print("\(entries.count) checks · \(entries.count - failed.count) passed · \(failed.count) failed")
        if !failed.isEmpty {
            print("\nFailures:")
            for entry in failed {
                print("  ✗ [\(entry.feature)] \(entry.detail)")
            }
        }
        print(String(repeating: "─", count: 60))
    }
}
