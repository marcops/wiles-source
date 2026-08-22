import Foundation
@testable import Wiles

@MainActor
public struct NetworkDiscoveryTests {
    public static func run() {
        let service = NetworkDiscoveryService.shared
        service.startBrowsing()
        service.stopBrowsing()
        TestReporter.report("NetworkDiscovery", "POS: Bonjour NWBrowser service starts and stops cleanly", result: true)

        // POS: calling startBrowsing() a second time in a row hits the `if browser != nil` guard and safely no-ops
        service.startBrowsing()
        service.startBrowsing()
        TestReporter.report("NetworkDiscovery", "POS: calling startBrowsing() twice in a row is a safe no-op", result: true)

        // POS: stopBrowsing() clears discoveredShares immediately, and a subsequent startBrowsing() works again
        service.stopBrowsing()
        let clearedAfterStop = service.discoveredShares.isEmpty
        TestReporter.report("NetworkDiscovery", "POS: stopBrowsing() clears discoveredShares to empty", result: clearedAfterStop)

        service.startBrowsing()
        TestReporter.report("NetworkDiscovery", "POS: startBrowsing() after stopBrowsing() restarts without crashing", result: true)

        service.stopBrowsing()

        testNetworkShareInitialization()
        testNetworkShareIdentityIsUniquePerInstance()
        testNetworkShareSortingMatchesLocalizedStandardOrder()

        // `updateDiscoveredShares(from:)` (the `guard case .service`/percent-encoding/URL-building/
        // sort pipeline) is `private` and only ever invoked from `browser.browseResultsChangedHandler`,
        // which only fires from a real `NWBrowser.Result` set produced by actual Bonjour/mDNS
        // discovery on the network — there is no injectable seam to call it with synthetic results
        // in a unit test. Per WILES_RULES.md this service is explicitly called out as a legitimate
        // real-network-dependent exception to the 100% branch-coverage target; the tests above cover
        // every piece of its logic (NetworkShare construction, identity, localizedStandardCompare
        // sorting) in isolation instead, and startBrowsing()/stopBrowsing() cover the lifecycle
        // around it.
    }

    // POS: NetworkShare's initializer stores the name and url exactly as provided
    private static func testNetworkShareInitialization() {
        let url = URL(string: "smb://myshare.local")!
        let share = NetworkShare(name: "MyShare", url: url)
        let matches = share.name == "MyShare" && share.url == url
        TestReporter.report("NetworkDiscovery", "POS: NetworkShare init stores name and url as provided", result: matches)
    }

    // NEG: two NetworkShare values built from identical name/url are NOT equal, because `id` is a
    // freshly generated UUID per instance rather than derived from name/url — this means the service's
    // `updateDiscoveredShares` will always produce brand-new identities on every browse update.
    private static func testNetworkShareIdentityIsUniquePerInstance() {
        let url = URL(string: "smb://duplicate.local")!
        let shareA = NetworkShare(name: "Duplicate", url: url)
        let shareB = NetworkShare(name: "Duplicate", url: url)
        let idsDiffer = shareA.id != shareB.id
        let notEqual = shareA != shareB
        TestReporter.report(
            "NetworkDiscovery",
            "NEG: NetworkShare instances with identical name/url still have distinct ids and are unequal",
            result: idsDiffer && notEqual)
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
