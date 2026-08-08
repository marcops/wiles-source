@testable import Wiles
import Foundation

@MainActor
public struct OpenWithTests {
    public static func run() {
        let sampleFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("sample_test.txt")
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

        testChooseOtherApplicationWithEmptyURLsIsNoOp()
        testAvailableApplicationsForFileWithNoExtension()
        testAvailableApplicationsForNonexistentFileURL()
        testSetDefaultApplicationWithValidExtensionAndBogusAppURL()
        testApplicationsAreDeduplicatedByBundleID()
        testOpenWithNonEmptyURLsAndBogusApplicationDoesNotCrash()
    }

    // NEG: open(urls:with:) with a non-empty urls array passes the guard and reaches the real
    // NSWorkspace.shared.open(...) call (lines otherwise uncovered). The target file must exist on
    // disk - a nonexistent target makes NSWorkspace present a real, blocking "file not found" system
    // alert instead of failing silently via the (nil) completion handler, which would hang an
    // automated test run waiting for a human to dismiss it. The bogus (nonexistent) application URL
    // is still safe to leave as-is: that failure mode reports through the completion handler rather
    // than a UI alert.
    private static func testOpenWithNonEmptyURLsAndBogusApplicationDoesNotCrash() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let realFile = dir.appendingPathComponent("real.txt")
        try? "content".write(to: realFile, atomically: true, encoding: .utf8)
        let bogusAppURL = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("app")
        OpenWithService.open(urls: [realFile], with: bogusAppURL)
        TestReporter.report("OpenWith", "NEG: open(urls:with:) with non-empty urls and a bogus (nonexistent) app URL does not crash", result: true)
    }

    // NEG: chooseOtherApplication(toOpen:) with an empty URL array hits the guard and safely no-ops
    // (must not present an NSOpenPanel, which would hang/disrupt a non-interactive test run)
    private static func testChooseOtherApplicationWithEmptyURLsIsNoOp() {
        OpenWithService.chooseOtherApplication(toOpen: [])
        TestReporter.report("OpenWith", "NEG: chooseOtherApplication(toOpen:) with empty array is a safe no-op", result: true)
    }

    // NEG: a file with no extension at all still returns without crashing (may be empty or may fall back
    // to generic apps depending on system state, so we only assert it doesn't throw/crash and returns an array)
    private static func testAvailableApplicationsForFileWithNoExtension() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let noExtensionFile = dir.appendingPathComponent("no_extension_file")
        try? "data".write(to: noExtensionFile, atomically: true, encoding: .utf8)

        let apps = OpenWithService.availableApplications(for: noExtensionFile)
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report("OpenWith", "NEG: availableApplications for extensionless file returns a valid (possibly empty) list without crashing", result: validApps)
    }

    // NEG: a well-formed file URL that does not actually exist on disk should not crash the lookup;
    // NSWorkspace resolves candidate apps from the URL's UTI/extension, not from file existence
    private static func testAvailableApplicationsForNonexistentFileURL() {
        let ghostFile = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        let apps = OpenWithService.availableApplications(for: ghostFile)
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report("OpenWith", "NEG: availableApplications for a nonexistent-on-disk .txt URL returns a valid list without crashing", result: validApps)
    }

    // NEG: setDefaultApplication with a syntactically valid extension but an application URL that
    // doesn't point at a real app should not crash; NSWorkspace's completion handler simply reports failure
    private static func testSetDefaultApplicationWithValidExtensionAndBogusAppURL() {
        let bogusAppURL = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("app")
        OpenWithService.setDefaultApplication(for: "txt", applicationURL: bogusAppURL)
        TestReporter.report("OpenWith", "NEG: setDefaultApplication with valid extension but bogus (nonexistent) app URL does not crash", result: true)
    }

    // POS: availableApplications de-duplicates by bundle identifier — verify the returned list never
    // contains two entries with the same id, which would otherwise show duplicate rows in the Open With menu
    private static func testApplicationsAreDeduplicatedByBundleID() {
        let sampleFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try? "test data".write(to: sampleFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sampleFile) }

        let apps = OpenWithService.availableApplications(for: sampleFile)
        let ids = apps.map { $0.id }
        let uniqueIDs = Set(ids)
        TestReporter.report("OpenWith", "POS: availableApplications returns no duplicate bundle ids", result: ids.count == uniqueIDs.count)
    }
}
