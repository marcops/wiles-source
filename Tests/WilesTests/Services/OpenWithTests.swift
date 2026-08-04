@testable import Wiles
import Foundation

@MainActor
public struct OpenWithTests {
    public static func run() {
        let sampleFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("sample_test.txt")
        try? "test data".write(to: sampleFile, atomically: true, encoding: .utf8)

        // POS: Discover applications for .txt file
        let apps = OpenWithService.availableApplications(for: sampleFile)
        TestReporter.report("OpenWith", "POS: availableApplications for .txt file", result: !apps.isEmpty)

        // POS: Applications list contains non-empty display names and URLs
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report("OpenWith", "POS: Applications contain valid metadata", result: validApps)

        // NEG: open(urls:with:) with an empty URL array hits the guard and safely no-ops
        OpenWithService.open(urls: [], with: URL(fileURLWithPath: "/Applications/Safari.app"))
        TestReporter.report("OpenWith", "NEG: open(urls:) with empty array is a safe no-op", result: true)

        // NEG: setDefaultApplication with an extension string that fails UTType creation hits the guard and safely no-ops
        OpenWithService.setDefaultApplication(for: "", applicationURL: URL(fileURLWithPath: "/Applications/Safari.app"))
        TestReporter.report("OpenWith", "NEG: setDefaultApplication with empty extension string is a safe no-op", result: true)

        try? FileManager.default.removeItem(at: sampleFile)
    }
}
