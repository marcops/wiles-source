@testable import Wiles
import SwiftUI

@MainActor
public struct SingleInputSheetViewTests {
    public static func run() {
        var submittedText = ""
        let view = SingleInputSheetView(
            title: "New Folder",
            iconName: "folder.badge.plus",
            initialValue: "Untitled Folder",
            actionButtonTitle: "Create",
            cancelTitle: "Cancel",
            onCancel: {},
            onSubmit: { submittedText = $0 }
        )
        report("View/SingleInputSheetView", "POS: SingleInputSheetView initializes with title", result: view.title == "New Folder")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
