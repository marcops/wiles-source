import Foundation
@testable import Wiles

/// `ActiveModal` is the single-source-of-truth enum for "which feature sheet is this window
/// showing". Its only logic is `id` (Identifiable, drives `.sheet(item:)`): distinct cases must
/// have distinct ids, and the same case with the same payload must have a stable id so SwiftUI
/// doesn't tear the sheet down and rebuild it on an unrelated state change.
@MainActor
public struct ActiveModalTests {
    public static func run() {
        testDistinctCasesHaveDistinctIDs()
        testSameCaseSamePayloadHasStableID()
        testPayloadCasesDifferByPayload()
    }

    private static func testDistinctCasesHaveDistinctIDs() {
        let item = FileItem.load(url: URL(fileURLWithPath: "/tmp/wiles-active-modal-test-item"))
        let cases = ActiveModal.allSampleCases(item: item)
        let ids = Set(cases.map(\.id))
        report("Models/ActiveModal", "POS: every distinct ActiveModal case has a distinct id", result: ids.count == cases.count)
    }

    private static func testSameCaseSamePayloadHasStableID() {
        let url = URL(fileURLWithPath: "/tmp/wiles-active-modal-share")
        report(
            "Models/ActiveModal",
            "POS: .httpShare with the same URL is equal to itself (stable sheet identity)",
            result: ActiveModal.httpShare(url) == ActiveModal.httpShare(url)
                && ActiveModal.httpShare(url).id == ActiveModal.httpShare(url).id)
        report(
            "Models/ActiveModal",
            "POS: a no-payload case (.help) is equal to itself",
            result: ActiveModal.help == ActiveModal.help)
    }

    private static func testPayloadCasesDifferByPayload() {
        let urlA = URL(fileURLWithPath: "/tmp/wiles-active-modal-a")
        let urlB = URL(fileURLWithPath: "/tmp/wiles-active-modal-b")
        report(
            "Models/ActiveModal",
            "NEG: .inspectArchive with different URLs are not equal",
            result: ActiveModal.inspectArchive(urlA) != ActiveModal.inspectArchive(urlB))
        report(
            "Models/ActiveModal",
            "NEG: .passwordCompress with different URL lists are not equal",
            result: ActiveModal.passwordCompress([urlA]) != ActiveModal.passwordCompress([urlA, urlB]))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}

extension ActiveModal {
    /// One value per case, for exhaustive coverage in `ActiveModalTests` and `WindowUIStateTests`.
    /// Keep in sync with the enum — a missing case here is a silently-uncovered sheet.
    static func allSampleCases(item: FileItem) -> [ActiveModal] {
        let url = item.url
        return [
            .properties(item), .imageConverter(item), .symlink(item),
            .httpShare(url), .inspectArchive(url), .passwordCompress([url]),
            .batchRename, .connectToServer, .autoOrganization, .duplicateCleaner,
            .saveSmartFolder, .help, .feedback, .about, .settings
        ]
    }
}
