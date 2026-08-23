import SwiftUI
@testable import Wiles

@MainActor
public struct MainContentViewTests {
    public static func run() {
        let view = MainContentView(sharedPreferences: PreferencesStore(), sharedTransient: TransientStore())
        _ = view.body
        report("View/MainContentView", "POS: MainContentView initializes with shared stores", result: true)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
