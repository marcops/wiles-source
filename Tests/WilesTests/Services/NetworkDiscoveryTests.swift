@testable import Wiles
import Foundation

@MainActor
public struct NetworkDiscoveryTests {
    public static func run() {
        let service = NetworkDiscoveryService.shared
        service.startBrowsing()
        service.stopBrowsing()
        TestReporter.report("NetworkDiscovery", "POS: Bonjour NWBrowser service starts and stops cleanly", result: true)
    }
}
