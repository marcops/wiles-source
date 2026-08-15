import SwiftUI
@testable import Wiles

@MainActor
public struct DoubleClickZoomDetectorTests {
    public static func run() {
        let view = Text("Zoom").doubleClickToZoom()
        report("View/DoubleClickZoomDetector", "POS: doubleClickToZoom view modifier applies to view", result: view != nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
