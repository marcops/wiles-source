import Foundation
@testable import Wiles

@MainActor
public struct ClipboardStateTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let fileURL = tempDir.appendingPathComponent("test.txt")
        let cutState = ClipboardState(urls: [fileURL], action: .cut)
        let copyState = ClipboardState(urls: [fileURL], action: .copy)

        report("Model/ClipboardState", "POS: isCut returns true for cut action item", result: cutState.isCut(url: fileURL))
        report("Model/ClipboardState", "NEG: isCut returns false for copy action item", result: !copyState.isCut(url: fileURL))

        // isCut normalizes both sides, so a non-standardized query URL for a member still matches,
        // and a non-member is rejected (the O(1) set lookup must agree with the old linear scan).
        let messyMember = tempDir.appendingPathComponent("./test.txt")
        let nonMember = tempDir.appendingPathComponent("other.txt")
        report("Model/ClipboardState", "POS: isCut matches a member even when the query URL isn't standardized", result: cutState.isCut(url: messyMember))
        report("Model/ClipboardState", "NEG: isCut returns false for a URL not on the clipboard", result: !cutState.isCut(url: nonMember))

        let multi = ClipboardState(urls: [fileURL, nonMember], action: .cut)
        report("Model/ClipboardState", "POS: isCut finds each URL in a multi-item cut set", result: multi.isCut(url: fileURL) && multi.isCut(url: nonMember))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
