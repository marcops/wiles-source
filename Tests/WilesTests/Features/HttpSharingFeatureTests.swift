@testable import Wiles
import Foundation

@MainActor
public struct HttpSharingFeatureTests {
    public static func run() {
        let server = LocalHttpServerService.shared
        report("Feature/HttpSharing", "POS: LocalHttpServerService initial state is not running", result: !server.isRunning)

        server.stop()
        report("Feature/HttpSharing", "NEG: Stopping stopped server is safe", result: !server.isRunning)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
