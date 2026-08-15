import Foundation
@testable import Wiles

@MainActor
public struct ModalStoreTests {
    public static func run() {
        let store = ModalStore()
        store.showError("Test Error")
        report("Store/ModalStore", "POS: showError sets errorMessage and showErrorAlert", result: store.showErrorAlert && store.errorMessage == "Test Error")
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
