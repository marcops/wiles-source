import XCTest
@testable import Wiles

/// Standalone `XCTestCase` wiring for `PreferencesPersistenceRoundTripTests.run()`
/// (see `PreferencesPersistenceRoundTripTests.swift`), mirroring
/// `AutoOrganizationRuleStoreTestsCase.swift`.
@MainActor
final class PreferencesPersistenceRoundTripCase: XCTestCase {
    func testPreferencesStorePersistenceRoundTrip() {
        PreferencesPersistenceRoundTripTests.run()
    }
}
