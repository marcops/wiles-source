import XCTest
@testable import Wiles

/// A preference store's `init` seeds each property from `UserDefaults` — it must not turn around
/// and write the just-read value straight back. Red→green: before the `isRestoringDefaults` guard,
/// `SearchPreferences()` fired one `UserDefaults.set` per loaded property.
@MainActor
final class PreferenceStoreLoadDoesNotPersistTests: XCTestCase {
    private final class WriteSpy: NSObject {
        var count = 0
        override func observeValue(
            forKeyPath _: String?, of _: Any?, change _: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
            count += 1
        }
    }

    func testSearchPreferencesInitDoesNotRewriteLoadedValues() {
        let defaults = UserDefaults.standard
        let keys = [
            DefaultsKey.searchScope.rawValue,
            DefaultsKey.searchCaseSensitive.rawValue,
            DefaultsKey.searchEverywhere.rawValue
        ]
        let originals = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, originals) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        defaults.set(SearchScope.content.rawValue, forKey: DefaultsKey.searchScope.rawValue)
        defaults.set(true, forKey: DefaultsKey.searchCaseSensitive.rawValue)
        defaults.set(true, forKey: DefaultsKey.searchEverywhere.rawValue)

        let spy = WriteSpy()
        for key in keys { defaults.addObserver(spy, forKeyPath: key, options: [], context: nil) }
        defer { for key in keys { defaults.removeObserver(spy, forKeyPath: key) } }

        let store = SearchPreferences()

        XCTAssertEqual(spy.count, 0, "init wrote a loaded value back to UserDefaults")
        XCTAssertFalse(store.isRestoringDefaults, "the restore flag must be cleared after init")
        XCTAssertEqual(store.searchScope, .content)
        XCTAssertTrue(store.searchEverywhere)
    }

    func testRuntimeChangeStillPersistsAfterInit() {
        let defaults = UserDefaults.standard
        let key = DefaultsKey.searchEverywhere.rawValue
        let original = defaults.object(forKey: key)
        defer {
            if let original { defaults.set(original, forKey: key) } else { defaults.removeObject(forKey: key) }
        }

        let store = SearchPreferences()
        store.searchEverywhere.toggle()
        let expected = store.searchEverywhere
        XCTAssertEqual(defaults.bool(forKey: key), expected)
    }
}
