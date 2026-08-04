@testable import Wiles
import Foundation

@MainActor
public struct NavigationStoreTests {
    public static func run() {
        let store = NavigationStore()
        let initialURL = store.currentURL

        let nextURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nav_test_\(UUID().uuidString)")
        store.navigateTo(nextURL)
        report("Store/NavigationStore", "POS: navigateTo updates currentURL", result: store.currentURL.path == nextURL.path)
        report("Store/NavigationStore", "POS: historyBack is non-empty after navigating", result: !store.historyBack.isEmpty)

        store.goBack()
        report("Store/NavigationStore", "POS: goBack restores initialURL", result: store.currentURL.path == initialURL.path)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
