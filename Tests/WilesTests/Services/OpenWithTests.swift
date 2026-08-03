import Foundation

@MainActor
public struct OpenWithTests {
    public static func run() {
        let sampleFile = FileManager.default.temporaryDirectory.appendingPathComponent("sample_test.txt")
        try? "test data".write(to: sampleFile, atomically: true, encoding: .utf8)

        // POS: Discover applications for .txt file
        let apps = OpenWithService.availableApplications(for: sampleFile)
        TestReporter.report("OpenWith", "POS: availableApplications for .txt file", result: !apps.isEmpty)

        // POS: Applications list contains non-empty display names and URLs
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report("OpenWith", "POS: Applications contain valid metadata", result: validApps)
    }
}
