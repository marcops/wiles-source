@testable import Wiles
import SwiftUI

@MainActor
public struct ClickOutsideDetectorTests {
    public static func run() {
        let detector = ClickOutsideDetector(onOutsideClick: {})
        report("View/ClickOutsideDetector", "POS: ClickOutsideDetector initializes with onOutsideClick closure", result: detector.onOutsideClick != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
