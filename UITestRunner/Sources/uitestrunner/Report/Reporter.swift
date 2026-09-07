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
    private var featureStart = Date()
    private var slowest: [(String, TimeInterval)] = []
    private let lock = NSLock()

    var hasFailures: Bool { entries.contains { !$0.passed } }
    var failCount: Int { entries.lazy.filter { !$0.passed }.count }

    func beginFeature(_ name: String) {
        let elapsed = Date().timeIntervalSince(featureStart)
        if currentFeature != "—" {
            slowest.append((currentFeature, elapsed))
            if elapsed >= 4 { print("  ⏱ \(currentFeature): \(String(format: "%.1f", elapsed))s") }
        }
        currentFeature = name
        featureStart = Date()
        print("\n▶ \(name)")
    }

    func pass(_ detail: String) {
        lock.lock(); entries.append(Entry(feature: currentFeature, detail: detail, passed: true)); lock.unlock()
        print("  ✓ \(detail)")
    }

    func fail(_ detail: String) {
        lock.lock(); entries.append(Entry(feature: currentFeature, detail: detail, passed: false)); lock.unlock()
        print("  ✗ \(detail)")
    }

    /// Records pass/fail from a boolean and returns it, for `guard check(...) else { return }`.
    @discardableResult
    func check(_ condition: Bool, _ detail: String) -> Bool {
        if condition { pass(detail) } else { fail(detail) }
        return condition
    }

    func printSummary() {
        slowest.append((currentFeature, Date().timeIntervalSince(featureStart)))
        let failed = entries.filter { !$0.passed }
        print("\n" + String(repeating: "─", count: 60))
        print("\(entries.count) checks · \(entries.count - failed.count) passed · \(failed.count) failed")
        if !failed.isEmpty {
            print("\nFailures:")
            for entry in failed {
                print("  ✗ [\(entry.feature)] \(entry.detail)")
            }
        }
        let top = slowest.sorted { $0.1 > $1.1 }.prefix(8)
        print("\nSlowest steps:")
        for (name, secs) in top { print("  \(String(format: "%5.1f", secs))s  \(name)") }
        print(String(repeating: "─", count: 60))
    }
}
