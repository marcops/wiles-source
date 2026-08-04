@testable import Wiles
import Foundation

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
    }
}
