@testable import Wiles
import Foundation

@MainActor
public struct ModalStoreTests {
    public static func run() {
        let store = ModalStore()
        report("Store/ModalStore", "POS: showHelpSheet starts false", result: !store.showHelpSheet)
        report("Store/ModalStore", "POS: showAboutSheet starts false", result: !store.showAboutSheet)

        store.showError("Test Error")
        report("Store/ModalStore", "POS: showError sets errorMessage and showErrorAlert", result: store.showErrorAlert && store.errorMessage == "Test Error")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
