import Darwin
import Foundation
@testable import Wiles

/// Password-protection coverage for `LocalHttpServerService` (`isAuthorized` / HTTP Basic Auth).
/// Split out of `LocalHttpServerServiceTests.swift` to keep that file under the length cap; reuses
/// its raw-socket helpers (`rawConnect`/`rawSend`/`rawRecvAll`/`waitUntil`/`report`/`requestSession`).
@MainActor
extension HttpSharingFeatureTests {
    static func runPasswordChecks() async {
        await testNoPasswordAllowsRequestWithoutAuthHeader()
        await testPasswordProtectedRequestWithoutAuthHeaderReturns401()
        await testPasswordProtectedRequestWithWrongPasswordReturns401()
        await testPasswordProtectedRequestWithCorrectPasswordSucceeds()
        await testEmptyPasswordStringIsTreatedAsNoPassword()
    }

    private static func testNoPasswordAllowsRequestWithoutAuthHeader() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            passed = httpResp.statusCode == 200
        }
        report("Feature/HttpSharing", "POS: GET / with no password configured succeeds without an Authorization header", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testPasswordProtectedRequestWithoutAuthHeaderReturns401() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }

        var passed = false
        var hasChallengeHeader = false
        if let sock = rawConnect(port: 8080) {
            rawSend(sock, "GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            let text = String(data: response, encoding: .utf8) ?? ""
            passed = text.hasPrefix("HTTP/1.1 401")
            hasChallengeHeader = text.lowercased().contains("www-authenticate: basic")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: GET / with a password configured and no Authorization header returns 401 Unauthorized", result: passed)
        report("Feature/HttpSharing", "POS: 401 response includes a WWW-Authenticate: Basic challenge header", result: hasChallengeHeader)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testPasswordProtectedRequestWithWrongPasswordReturns401() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            let wrongAuth = "Basic " + Data("someone:wrongpass".utf8).base64EncodedString()
            rawSend(sock, "GET / HTTP/1.1\r\nHost: localhost\r\nAuthorization: \(wrongAuth)\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            let text = String(data: response, encoding: .utf8) ?? ""
            passed = text.hasPrefix("HTTP/1.1 401")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: GET / with an incorrect Basic Auth password returns 401 Unauthorized", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testPasswordProtectedRequestWithCorrectPasswordSucceeds() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            // Username is ignored by design (isAuthorized only checks the password half) — use an
            // arbitrary one to prove that.
            let correctAuth = "Basic " + Data("anyone:secret123".utf8).base64EncodedString()
            rawSend(sock, "GET / HTTP/1.1\r\nHost: localhost\r\nAuthorization: \(correctAuth)\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            let text = String(data: response, encoding: .utf8) ?? ""
            passed = text.hasPrefix("HTTP/1.1 200")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "POS: GET / with the correct Basic Auth password succeeds regardless of username", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testEmptyPasswordStringIsTreatedAsNoPassword() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "")
        await waitUntil { server.isRunning }

        var passed = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            passed = httpResp.statusCode == 200
        }
        report(
            "Feature/HttpSharing",
            "POS: start(sharing:password:) with an empty string password does not require Authorization (treated as no password)",
            result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }
}
