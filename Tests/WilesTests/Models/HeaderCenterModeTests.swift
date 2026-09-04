import Foundation
@testable import Wiles

/// `HeaderCenterMode.resolve` — the pure decision for what the header's center region shows
/// (breadcrumb / editable search field / non-editable tag or smart-folder name pill).
@MainActor
public struct HeaderCenterModeTests {
    public static func run() {
        testBreadcrumbWhenNotSearching()
        testEditableSearchWhenEditing()
        testSmartFolderPillWinsOverTag()
        testTagPillForLoneTagToken()
        testEditableSearchForTagPlusFreeText()
        testEditableSearchForEmptyQuery()
    }

    private static func testBreadcrumbWhenNotSearching() {
        let mode = HeaderCenterMode.resolve(
            isSearching: false, isEditingSearch: false, activeSmartFolderName: "Docs", searchQuery: "tag:Red")
        report("POS: not searching → breadcrumb regardless of other state", result: mode == .breadcrumb)
    }

    private static func testEditableSearchWhenEditing() {
        let mode = HeaderCenterMode.resolve(
            isSearching: true, isEditingSearch: true, activeSmartFolderName: "Docs", searchQuery: "tag:Red")
        report("POS: isEditingSearch → editable field even with a nameable context", result: mode == .editableSearch)
    }

    private static func testSmartFolderPillWinsOverTag() {
        let mode = HeaderCenterMode.resolve(
            isSearching: true, isEditingSearch: false, activeSmartFolderName: "My PDFs", searchQuery: "tag:Red")
        report("POS: active smart folder → smart-folder pill (over a tag token)", result: mode == .smartFolderPill(name: "My PDFs"))
    }

    private static func testTagPillForLoneTagToken() {
        let mode = HeaderCenterMode.resolve(
            isSearching: true, isEditingSearch: false, activeSmartFolderName: nil, searchQuery: "tag:Red")
        report("POS: lone tag: token, no smart folder → tag pill", result: mode == .tagPill(tag: "Red"))
    }

    private static func testEditableSearchForTagPlusFreeText() {
        let mode = HeaderCenterMode.resolve(
            isSearching: true, isEditingSearch: false, activeSmartFolderName: nil, searchQuery: "pdf tag:Red")
        report("POS: tag: token mixed with free text → editable field", result: mode == .editableSearch)
    }

    private static func testEditableSearchForEmptyQuery() {
        let mode = HeaderCenterMode.resolve(
            isSearching: true, isEditingSearch: false, activeSmartFolderName: nil, searchQuery: "")
        report("POS: searching with an empty query → editable field", result: mode == .editableSearch)
    }

    private static func report(_ name: String, result: Bool) {
        TestReporter.report("Model/HeaderCenterMode", name, result: result)
    }
}
