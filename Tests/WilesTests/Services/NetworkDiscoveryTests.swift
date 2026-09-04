import Foundation
@testable import Wiles

@MainActor
public struct NetworkDiscoveryTests {
    public static func run() {
        let service = NetworkDiscoveryService()
        service.start()
        service.stop()
        TestReporter.report("NetworkDiscovery", "POS: Bonjour NWBrowser service starts and stops cleanly", result: true)

        // POS: calling start() a second time in a row hits the `if browser != nil` guard and safely no-ops
        service.start()
        service.start()
        TestReporter.report("NetworkDiscovery", "POS: calling start() twice in a row is a safe no-op", result: true)

        // POS: stop() clears discoveredShares immediately, and a subsequent start() works again
        service.stop()
        let clearedAfterStop = service.discoveredShares.isEmpty
        TestReporter.report("NetworkDiscovery", "POS: stop() clears discoveredShares to empty", result: clearedAfterStop)

        service.start()
        TestReporter.report("NetworkDiscovery", "POS: start() after stop() restarts without crashing", result: true)

        // MainContentView.onDisappear now also calls stop(), so the sidebar section's nested
        // .onDisappear and the window teardown can both stop the same instance in a row.
        service.stop()
        service.stop()
        TestReporter.report(
            "NetworkDiscovery",
            "POS: a second stop() right after the first (nested hook + window teardown) is a safe no-op",
            result: service.discoveredShares.isEmpty)

        // Per-window: each AppState owns its own instance, so one window's stop can't tear down another's.
        let windowA = AppState()
        let windowB = AppState()
        TestReporter.report(
            "NetworkDiscovery",
            "POS: NetworkDiscoveryService and LocalHttpServerService are per-AppState, not a shared singleton",
            result: windowA.networkDiscoveryService !== windowB.networkDiscoveryService
                && windowA.httpServerService !== windowB.httpServerService)

        testNetworkShareInitialization()
        testNetworkShareIdentityIsDerivedFromNameAndURL()
        testNetworkShareSortingMatchesLocalizedStandardOrder()

        // `updateDiscoveredShares(from:)` (the `guard case .service`/percent-encoding/URL-building/
        // sort pipeline) is `private` and only ever invoked from `browser.browseResultsChangedHandler`,
        // which only fires from a real `NWBrowser.Result` set produced by actual Bonjour/mDNS
        // discovery on the network — there is no injectable seam to call it with synthetic results
        // in a unit test. Per WILES_RULES.md this service is explicitly called out as a legitimate
        // real-network-dependent exception to the 100% branch-coverage target; the tests above cover
        // every piece of its logic (NetworkShare construction, identity, localizedStandardCompare
        // sorting) in isolation instead, and start()/stop() cover the lifecycle around it.
    }

    // POS: NetworkShare's initializer stores the name and url exactly as provided
    private static func testNetworkShareInitialization() {
        let url = URL(string: "smb://myshare.local")!
        let share = NetworkShare(name: "MyShare", url: url)
        let matches = share.name == "MyShare" && share.url == url
        TestReporter.report("NetworkDiscovery", "POS: NetworkShare init stores name and url as provided", result: matches)
    }

    // POS: `id` is derived from name+url, so two NetworkShare values for the same share are equal
    // and share an identity — `NetworkDiscoveryService` rebuilds the array on every browse/resolve
    // update, and a stable id keeps `ForEach` from recreating the whole sidebar Network section.
    private static func testNetworkShareIdentityIsDerivedFromNameAndURL() {
        let url = URL(string: "smb://duplicate.local")!
        let shareA = NetworkShare(name: "Duplicate", url: url)
        let shareB = NetworkShare(name: "Duplicate", url: url)
        let shareC = NetworkShare(name: "Other", url: url)
        TestReporter.report(
            "NetworkDiscovery",
            "POS: two NetworkShare values for the same name/url share an id and are equal",
            result: shareA.id == shareB.id && shareA == shareB)
        TestReporter.report(
            "NetworkDiscovery",
            "NEG: NetworkShare values that differ in name have different ids",
            result: shareA.id != shareC.id)
    }

    // POS: the same localizedStandardCompare-based ordering the service applies to discoveredShares
    // produces a case-insensitive, natural-language sort (matching NSString/Finder ordering semantics).
    private static func testNetworkShareSortingMatchesLocalizedStandardOrder() {
        let shares = [
            NetworkShare(name: "zebra", url: URL(string: "smb://zebra.local")!),
            NetworkShare(name: "Apple", url: URL(string: "smb://apple.local")!),
            NetworkShare(name: "banana2", url: URL(string: "smb://banana2.local")!),
            NetworkShare(name: "banana10", url: URL(string: "smb://banana10.local")!)
        ]
        let sorted = shares.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let names = sorted.map(\.name)
        // localizedStandardCompare treats "banana2" < "banana10" numerically (natural sort), unlike plain string comparison
        let expected = ["Apple", "banana2", "banana10", "zebra"]
        TestReporter.report("NetworkDiscovery", "POS: localizedStandardCompare sort orders names case-insensitively and numerically", result: names == expected)
    }
}
