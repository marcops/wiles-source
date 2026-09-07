@testable import Wiles

/// Regression test for a real reported bug: in Grid View, clicking into a Finder-style inline
/// rename worked, but ~3s later the card's full-name reveal pill
/// (`AsyncDelayTokens.nameRevealDelay`) rendered on top of the still-open rename field, hiding it.
/// The fix suppresses the reveal for the item being renamed — `shouldRevealFullName` is the pure
/// decision extracted from the `.task` condition a unit test can't drive.
@MainActor
public struct FileGridCardItemViewTests {
    public static func run() {
        testRevealWhenSelectedAndNotRenaming()
        testNoRevealWhileRenaming()
        testNoRevealWhenNotSelected()
    }

    private static func testRevealWhenSelectedAndNotRenaming() {
        report(
            "View/FileGridCardItemView",
            "POS: a selected card that is not being renamed schedules the full-name reveal",
            result: FileGridCardItemView.shouldRevealFullName(isSelected: true, isRenaming: false))
    }

    private static func testNoRevealWhileRenaming() {
        report(
            "View/FileGridCardItemView",
            "NEG: a selected card being renamed does not schedule the reveal (would cover its rename field)",
            result: !FileGridCardItemView.shouldRevealFullName(isSelected: true, isRenaming: true))
    }

    private static func testNoRevealWhenNotSelected() {
        report(
            "View/FileGridCardItemView",
            "NEG: an unselected card never schedules the reveal",
            result: !FileGridCardItemView.shouldRevealFullName(isSelected: false, isRenaming: false))
        report(
            "View/FileGridCardItemView",
            "NEG: an unselected card being renamed never schedules the reveal",
            result: !FileGridCardItemView.shouldRevealFullName(isSelected: false, isRenaming: true))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
