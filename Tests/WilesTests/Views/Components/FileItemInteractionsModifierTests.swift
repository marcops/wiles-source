import Foundation
@testable import Wiles

/// Covers `FileItemInteractionsModifier.shouldEnterRename` — the guard that stops the delayed
/// "click, pause → rename" from opening a rename field on an item that was navigated away from
/// during the pause, which left `isTextFieldEditingActive` stuck (LB-030).
@MainActor
public struct FileItemInteractionsModifierTests {
    public static func run() {
        let item = URL(fileURLWithPath: "/tmp/fiim-a.txt")
        let other = URL(fileURLWithPath: "/tmp/fiim-b.txt")

        func shouldEnter(currentGeneration: Int, selectedURLs: Set<URL>, itemStillListed: Bool) -> Bool {
            FileItemInteractionsModifier.shouldEnterRename(
                scheduledGeneration: 3, currentGeneration: currentGeneration,
                selectedURLs: selectedURLs, itemURL: item, itemStillListed: itemStillListed)
        }

        report(
            "POS: enters rename when nothing changed during the delay",
            shouldEnter(currentGeneration: 3, selectedURLs: [item], itemStillListed: true))

        report(
            "NEG: a newer scheduled rename / double-click bumped the generation → no rename",
            !shouldEnter(currentGeneration: 4, selectedURLs: [item], itemStillListed: true))

        report(
            "NEG: keyboard navigation moved the selection to another item → no rename (LB-030)",
            !shouldEnter(currentGeneration: 3, selectedURLs: [other], itemStillListed: true))

        report(
            "NEG: the item is no longer the SOLE selection → no rename",
            !shouldEnter(currentGeneration: 3, selectedURLs: [item, other], itemStillListed: true))

        report(
            "NEG: navigated away — selection is now empty → no rename",
            !shouldEnter(currentGeneration: 3, selectedURLs: [], itemStillListed: true))

        report(
            "NEG: the item is no longer in the current listing → no rename",
            !shouldEnter(currentGeneration: 3, selectedURLs: [item], itemStillListed: false))
    }

    private static func report(_ name: String, _ result: Bool) {
        TestReporter.report("View/FileItemInteractionsModifier", name, result: result)
    }
}
