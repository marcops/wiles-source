@testable import Wiles
import Foundation

@MainActor
public struct PreferencesStoreTests {
    public static func run() {
        let store = PreferencesStore()
        report("Store/PreferencesStore", "POS: iconSize is within valid bounds", result: store.iconSize >= IconSizeToken.minSize && store.iconSize <= IconSizeToken.maxSize)

        let initialHidden = store.showHiddenFiles
        defer { store.showHiddenFiles = initialHidden }

        store.showHiddenFiles.toggle()
        report("Store/PreferencesStore", "POS: showHiddenFiles toggles correctly", result: store.showHiddenFiles != initialHidden)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
