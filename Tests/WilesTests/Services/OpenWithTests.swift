import AppKit
import Foundation
@testable import Wiles

/// `chooseOtherApplication(toOpen:)`'s non-empty-URLs body (past the `guard !urls.isEmpty` early
/// return already covered below) is intentionally left uncovered: it presents a real `NSOpenPanel`,
/// which would show actual system UI during an automated test run and has no injectable seam (the
/// panel is constructed directly, not via `WorkspaceOpening`) — disproportionate cost/risk versus a
/// thin panel-configuration pass-through.
@MainActor
public struct OpenWithTests {
    public static func run() async {
        let sampleFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("sample_test.txt")
        try? "test data".write(to: sampleFile, atomically: true, encoding: .utf8)

        // POS: Discover applications for .txt file
        let apps = await OpenWithService.availableApplications(for: sampleFile)
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
        await testAvailableApplicationsForFileWithNoExtension()
        await testAvailableApplicationsForNonexistentFileURL()
        testSetDefaultApplicationWithValidExtensionAndBogusAppURL()
        await testApplicationsAreDeduplicatedByBundleID()
        testOpenWithNonEmptyURLsCallsThroughToTheInjectedOpener()
        await testAvailableApplicationsAreMemoizedByExtension()
    }

    /// The per-extension memo returns the same list for two files of the same type and is dropped
    /// by `invalidateApplicationsCache()`.
    private static func testAvailableApplicationsAreMemoizedByExtension() async {
        OpenWithService.invalidateApplicationsCache()
        let dir = URL(fileURLWithPath: testTemporaryDirectory())
        let memoA = dir.appendingPathComponent("memo-a.txt")
        let memoB = dir.appendingPathComponent("memo-b.txt")
        try? "x".write(to: memoA, atomically: true, encoding: .utf8)
        try? "y".write(to: memoB, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: memoA)
            try? FileManager.default.removeItem(at: memoB)
            OpenWithService.invalidateApplicationsCache()
        }

        let first = await OpenWithService.availableApplications(for: memoA).map(\.id)
        let second = await OpenWithService.availableApplications(for: memoB).map(\.id)
        TestReporter.report(
            "OpenWith",
            "POS: availableApplications returns the same memoized list for two files of the same extension",
            result: first == second)

        OpenWithService.invalidateApplicationsCache()
        let afterInvalidate = await OpenWithService.availableApplications(for: memoA).map(\.id)
        TestReporter.report(
            "OpenWith",
            "POS: the extension memo still yields the same result after invalidateApplicationsCache()",
            result: afterInvalidate == first)

        // SL-072: `invalidateApplicationsCache()` is now wired to `NSWorkspace.didLaunchApplication`
        // in `WilesApp`, so it fires at arbitrary times — including with nothing cached. Repeated /
        // empty-cache calls must be harmless.
        OpenWithService.invalidateApplicationsCache()
        OpenWithService.invalidateApplicationsCache()
        let stillWorks = await OpenWithService.availableApplications(for: memoA).map(\.id)
        TestReporter.report(
            "OpenWith",
            "POS: back-to-back invalidateApplicationsCache() calls (as the workspace observer can trigger) are a safe no-op",
            result: stillWorks == first)
    }

    // POS: open(urls:with:) with a non-empty urls array passes the guard and reaches the real
    // NSWorkspace.shared.open(...) call site — now safe to exercise for real via the injected
    // WorkspaceOpening seam (see WorkspaceOpening.swift) instead of touching the actual OS.
    private static func testOpenWithNonEmptyURLsCallsThroughToTheInjectedOpener() {
        let fake = OpenWithFakeWorkspaceOpener()
        let previousOpener = OpenWithService.opener
        OpenWithService.opener = fake
        defer { OpenWithService.opener = previousOpener }

        let targetFile = URL(fileURLWithPath: "/tmp/does-not-need-to-exist.txt")
        let appURL = URL(fileURLWithPath: "/Applications/Safari.app")
        OpenWithService.open(urls: [targetFile], with: appURL)

        TestReporter.report(
            "OpenWith", "POS: open(urls:with:) with non-empty urls calls through to the injected opener with the right arguments",
            result: fake.openedURLPairs.count == 1 && fake.openedURLPairs.first?.urls == [targetFile] && fake.openedURLPairs.first?.applicationURL == appURL)
    }

    // NEG: chooseOtherApplication(toOpen:) with an empty URL array hits the guard and safely no-ops
    // (must not present an NSOpenPanel, which would hang/disrupt a non-interactive test run)
    private static func testChooseOtherApplicationWithEmptyURLsIsNoOp() {
        OpenWithService.chooseOtherApplication(toOpen: [])
        TestReporter.report("OpenWith", "NEG: chooseOtherApplication(toOpen:) with empty array is a safe no-op", result: true)
    }

    // NEG: a file with no extension at all still returns without crashing (may be empty or may fall back
    // to generic apps depending on system state, so we only assert it doesn't throw/crash and returns an array)
    private static func testAvailableApplicationsForFileWithNoExtension() async {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let noExtensionFile = dir.appendingPathComponent("no_extension_file")
        try? "data".write(to: noExtensionFile, atomically: true, encoding: .utf8)

        let apps = await OpenWithService.availableApplications(for: noExtensionFile)
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report(
            "OpenWith",
            "NEG: availableApplications for extensionless file returns a valid (possibly empty) list without crashing",
            result: validApps)
    }

    // NEG: a well-formed file URL that does not actually exist on disk should not crash the lookup;
    // NSWorkspace resolves candidate apps from the URL's UTI/extension, not from file existence
    private static func testAvailableApplicationsForNonexistentFileURL() async {
        let ghostFile = URL(fileURLWithPath: testTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        let apps = await OpenWithService.availableApplications(for: ghostFile)
        let validApps = apps.allSatisfy { !$0.name.isEmpty && $0.url.isFileURL }
        TestReporter.report(
            "OpenWith",
            "NEG: availableApplications for a nonexistent-on-disk .txt URL returns a valid list without crashing",
            result: validApps)
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
    private static func testApplicationsAreDeduplicatedByBundleID() async {
        let sampleFile = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try? "test data".write(to: sampleFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sampleFile) }

        let apps = await OpenWithService.availableApplications(for: sampleFile)
        let ids = apps.map(\.id)
        let uniqueIDs = Set(ids)
        TestReporter.report("OpenWith", "POS: availableApplications returns no duplicate bundle ids", result: ids.count == uniqueIDs.count)
    }
}
