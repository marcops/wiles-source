import SwiftUI
@testable import Wiles

@MainActor
public struct TappableRowTests {
    public static func run() {
        testEnabledRowInvokesActionOnTap()
        testDisabledRowSwallowsTap()
        testIsDisabledDefaultsToFalse()
    }

    private static func testEnabledRowInvokesActionOnTap() {
        final class Box: @unchecked Sendable { var taps = 0 }
        let box = Box()
        let row = TappableRow(accessibilityLabel: "Back", action: { box.taps += 1 }, content: { Image(systemName: "chevron.left") })
        row.handleTap()
        row.handleTap()
        report("View/TappableRow", "POS: an enabled TappableRow forwards each tap to its action", result: box.taps == 2)
    }

    private static func testDisabledRowSwallowsTap() {
        final class Box: @unchecked Sendable { var taps = 0 }
        let box = Box()
        let row = TappableRow(accessibilityLabel: "Back", isDisabled: true, action: { box.taps += 1 }, content: { Image(systemName: "chevron.left") })
        row.handleTap()
        report("View/TappableRow", "NEG: a disabled TappableRow ignores taps (mirrors .disabled on a real control)", result: box.taps == 0)
    }

    private static func testIsDisabledDefaultsToFalse() {
        let row = TappableRow(accessibilityLabel: "X", action: { }, content: { EmptyView() })
        report("View/TappableRow", "POS: isDisabled defaults to false", result: !row.isDisabled)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
