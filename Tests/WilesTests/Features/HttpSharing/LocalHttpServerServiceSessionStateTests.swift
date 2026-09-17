import Foundation
@testable import Wiles

/// `sharingFolderURL`/`isPasswordProtected` coverage — the state the footer's Wi-Fi indicator and a
/// reopened `HttpShareSheet` rely on to resume the right session. Split out of
/// `LocalHttpServerServiceTests.swift` to keep that file under the length cap; reuses its helpers.
@MainActor
extension HttpSharingFeatureTests {
    static func runSessionStateChecks() async {
        await testSharingFolderURLTracksStartAndStop()
        await testIsPasswordProtectedReflectsThePasswordArgument()
        await testEmptyPasswordIsNotPasswordProtected()
    }

    private static func testSharingFolderURLTracksStartAndStop() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        report("Feature/HttpSharing", "POS: sharingFolderURL is nil before any start()", result: server.sharingFolderURL == nil)

        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }
        report(
            "Feature/HttpSharing",
            "POS: sharingFolderURL matches the folder passed to start() once sharing is active",
            result: server.sharingFolderURL == tempDir)

        server.stop()
        await waitUntil { !server.isRunning }
        report("Feature/HttpSharing", "POS: sharingFolderURL is cleared back to nil after stop()", result: server.sharingFolderURL == nil)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testIsPasswordProtectedReflectsThePasswordArgument() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }
        report("Feature/HttpSharing", "POS: isPasswordProtected is true once start() is given a non-empty password", result: server.isPasswordProtected)

        server.stop()
        await waitUntil { !server.isRunning }
        report("Feature/HttpSharing", "POS: isPasswordProtected resets to false after stop()", result: !server.isPasswordProtected)

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testEmptyPasswordIsNotPasswordProtected() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "")
        await waitUntil { server.isRunning }
        report(
            "Feature/HttpSharing",
            "NEG: an empty password string is treated the same as no password by isPasswordProtected",
            result: !server.isPasswordProtected)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }
}
