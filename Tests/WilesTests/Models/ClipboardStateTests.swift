@testable import Wiles
import Foundation

@MainActor
public struct ClipboardStateTests {
    public static func run() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")
        let cutState = ClipboardState(urls: [fileURL], action: .cut)
        let copyState = ClipboardState(urls: [fileURL], action: .copy)

        report("Model/ClipboardState", "POS: isCut returns true for cut action item", result: cutState.isCut(url: fileURL))
        report("Model/ClipboardState", "NEG: isCut returns false for copy action item", result: !copyState.isCut(url: fileURL))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
