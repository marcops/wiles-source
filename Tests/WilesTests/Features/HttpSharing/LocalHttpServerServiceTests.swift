@testable import Wiles
import Foundation

@MainActor
public struct HttpSharingFeatureTests {
    public static func run() {
        let server = LocalHttpServerService.shared
        let initialState = server.isRunning
        defer {
            if initialState != server.isRunning {
                if initialState {
                    try? server.start(sharing: URL(fileURLWithPath: testTemporaryDirectory()))
                } else {
                    server.stop()
                }
            }
        }

        server.stop()
        report("Feature/HttpSharing", "POS: LocalHttpServerService stops cleanly", result: !server.isRunning)

        server.stop()
        report("Feature/HttpSharing", "NEG: Stopping stopped server is safe no-op", result: !server.isRunning)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
