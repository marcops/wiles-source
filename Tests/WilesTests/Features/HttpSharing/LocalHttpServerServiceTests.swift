import Darwin
import Foundation
@testable import Wiles

@MainActor
public struct HttpSharingFeatureTests {
    public static func run() async {
        let server = LocalHttpServerService()
        let initialState = server.isRunning
        defer {
            if initialState != server.isRunning {
                if initialState {
                    server.start(sharing: URL(fileURLWithPath: testTemporaryDirectory()))
                } else {
                    server.stop()
                }
            }
        }

        server.stop()
        report("Feature/HttpSharing", "POS: LocalHttpServerService stops cleanly", result: !server.isRunning)

        server.stop()
        report("Feature/HttpSharing", "NEG: Stopping stopped server is safe no-op", result: !server.isRunning)

        await testDirectoryRemovedAfterStartReturns500()
        await testMalformedPercentEncodingReturnsBadRequest()
        await testEmptyConnectionContentIsClosedSafely()
        await testNonUtf8ConnectionContentIsClosedSafely()
        // Password / Basic Auth checks live in LocalHttpServerServicePasswordTests.swift (split out
        // to keep this file under the length cap).
        await runPasswordChecks()
        await testAuthorizationHeaderWithoutBasicPrefixReturns401()
        await testSharedFolderClearedMidFlightReturns500()
        await testStopCancelsActiveConnections()
        // C2 (stored XSS) + M11 (fragmented/oversized request head) regressions — see
        // LocalHttpServerServiceSecurityTests.swift (split out to keep this file under the length cap).
        await runSecurityAndRobustnessChecks()
        testFirstAvailablePortSkipsAnOccupiedPort()
        await testServerURLReflectsTheScannedPort(server)
        await testRestartWithoutStopReusesTheSamePort()

        server.stop()
    }

    /// BB-358: `start()` now tears down any prior listener before standing up a new one — a second
    /// `start(sharing:)` without an intervening `stop()` used to orphan the first `NWListener` (still
    /// bound to its port, with no reference left to cancel it), forcing the new one onto the next port.
    private static func testRestartWithoutStopReusesTheSamePort() async {
        let dirA = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("httpA_\(UUID().uuidString)")
        let dirB = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent("httpB_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        try? "marker".write(to: dirB.appendingPathComponent("only-in-b.txt"), atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: dirA)
            try? FileManager.default.removeItem(at: dirB)
        }

        let server = LocalHttpServerService()
        server.stop()
        await waitUntil { !server.isRunning }

        server.start(sharing: dirA)
        await waitUntil { server.isRunning }
        let firstPort = server.port.rawValue

        // Restart for a different folder WITHOUT stopping first.
        server.start(sharing: dirB)
        await waitUntil(timeoutSeconds: 2.0) { server.isRunning }
        let secondPort = server.port.rawValue

        report(
            "Feature/HttpSharing",
            "POS (BB-358): a second start() without stop() reuses the same port (the prior listener was cancelled, not orphaned)",
            result: secondPort == firstPort)

        var servesDirB = false
        if let url = URL(string: "http://localhost:\(secondPort)/"),
           let (data, resp) = try? await requestSession.data(from: url),
           let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
            servesDirB = (String(data: data, encoding: .utf8) ?? "").contains("only-in-b.txt")
        }
        report(
            "Feature/HttpSharing",
            "POS (BB-358): after the restart the server on that port serves the new folder's listing",
            result: servesDirB)

        server.stop()
        await waitUntil { !server.isRunning }
    }

    /// B11-4: `port` is `@MainActor`-only now (written in `start()`, read in `updateServerURL()`).
    /// After a successful start the published `serverURL` must carry that same port value.
    private static func testServerURLReflectsTheScannedPort(_ server: LocalHttpServerService) async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }
        let urlHasPort = server.serverURL?.contains(":\(server.port.rawValue)") ?? false
        report(
            "Feature/HttpSharing",
            "POS: after start(), serverURL carries the same port value the MainActor-only `port` holds",
            result: urlHasPort)
        server.stop()
        await waitUntil { !server.isRunning }
    }

    /// `firstAvailablePort` walks the range and returns the first port a socket can bind; a port
    /// held by another listener is skipped rather than handed back.
    private static func testFirstAvailablePortSkipsAnOccupiedPort() {
        // Grab a free port dynamically, then occupy it and confirm the scan steps over it.
        guard let free = LocalHttpServerService.firstAvailablePort(in: 8080 ... 8089) else {
            report("Feature/HttpSharing", "SKIP: no free port in 8080–8089 to run the port-scan test", result: true)
            return
        }
        let occupiedValue = free.rawValue
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            report("Feature/HttpSharing", "SKIP: could not open a socket to occupy a port", result: true)
            return
        }
        defer { close(sock) }
        var reuse: Int32 = 1
        _ = setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = occupiedValue.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(sock, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            report("Feature/HttpSharing", "SKIP: could not bind the chosen port to occupy it", result: true)
            return
        }

        let next = LocalHttpServerService.firstAvailablePort(in: occupiedValue ... 8089)
        report(
            "Feature/HttpSharing",
            "POS: firstAvailablePort skips a port that is already bound and returns a later free one",
            result: next.map { $0.rawValue != occupiedValue } ?? false)
    }

    // MARK: - Authorization header present but not "Basic " (isAuthorized guard branch)

    /// Covers the `guard value.hasPrefix("Basic ") else { return false }` branch in
    /// `isAuthorized()`: an Authorization header that's present but uses a different auth scheme
    /// (e.g. Bearer) must still be rejected as unauthorized rather than crash on the base64 decode.
    private static func testAuthorizationHeaderWithoutBasicPrefixReturns401() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            rawSend(sock, "GET / HTTP/1.1\r\nHost: localhost\r\nAuthorization: Bearer sometoken\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            let text = String(data: response, encoding: .utf8) ?? ""
            passed = text.hasPrefix("HTTP/1.1 401")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: an Authorization header using a non-Basic scheme (e.g. Bearer) returns 401 Unauthorized", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - sharedFolder cleared mid-flight (processRequest internalServerError guard branch)

    /// Covers the `guard let folder = sharedFolder else` branch in `processRequest()`. In real
    /// usage `sharedFolder` only becomes nil via `stop()`, which also tears down the listener - but
    /// the property is public and read fresh per-request, so this directly clears it while the
    /// server keeps listening to simulate the request landing in that narrow window.
    private static func testSharedFolderClearedMidFlightReturns500() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }
        server.sharedFolder = nil

        var passed = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            passed = httpResp.statusCode == 500
        }
        report("Feature/HttpSharing", "NEG: GET / while sharedFolder is nil (server still listening) returns 500 Internal Server Error", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - stop() cancels still-open connections (stop's connections loop)

    /// Covers the `for conn in connections { conn.cancel() }` loop in `stop()` actually iterating a
    /// non-empty list: a client that connects but hasn't sent/closed yet stays in `connections`
    /// until data arrives, so calling `stop()` right after connecting should find it still there.
    private static func testStopCancelsActiveConnections() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var danglingSocket: Int32?
        if let sock = rawConnect(port: 8080) {
            danglingSocket = sock
            // Give the accept handler time to run and append the connection before stop() below.
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        server.stop()
        await waitUntil { !server.isRunning }
        report("Feature/HttpSharing", "POS: stop() completes cleanly while a connected-but-idle client is still open", result: !server.isRunning)

        if let danglingSocket {
            Darwin.close(danglingSocket)
        }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Directory-removed-after-start (serveDirectoryListing catch branch)

    /// Covers the `catch` branch in `serveDirectoryListing()`: `contentsOfDirectory(at:)` throws
    /// when the shared folder no longer exists on disk at request time (e.g. removed/unmounted
    /// after `start(sharing:)` was called but before a request arrives).
    private static func testDirectoryRemovedAfterStartReturns500() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        // Remove the shared folder itself (not just its contents) while the server is running.
        try? FileManager.default.removeItem(at: tempDir)

        var passed = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            passed = httpResp.statusCode == 500
        }
        report("Feature/HttpSharing", "NEG: GET / for a shared folder removed from disk after start() returns 500 Internal Server Error", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
    }

    // MARK: - Malformed percent-encoding (serveFile badRequest branch)

    /// Covers the `guard let decodedPath = path.removingPercentEncoding` failure branch in
    /// `serveFile()`. A well-formed `URLSession` request can't produce a raw invalid percent
    /// sequence in the request line (URL construction itself rejects it), so this crafts the raw
    /// HTTP request bytes over a plain socket instead.
    private static func testMalformedPercentEncodingReturnsBadRequest() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            rawSend(sock, "GET /%zz HTTP/1.1\r\nHost: localhost\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            let text = String(data: response, encoding: .utf8) ?? ""
            passed = text.hasPrefix("HTTP/1.1 400")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: GET with an invalid percent-encoded path (/%zz) returns 400 Bad Request", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Raw connection edge cases (receiveRequest guard branches)

    /// Covers the first guard in `receiveRequest()`: a client that connects and disconnects
    /// without sending any bytes yields nil/empty `content`, which must close the connection
    /// safely instead of crashing or hanging the server.
    private static func testEmptyConnectionContentIsClosedSafely() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        if let sock = rawConnect(port: 8080) {
            // Disconnect immediately without writing anything.
            Darwin.close(sock)
        }

        // The server must still be healthy and answer a normal request afterward - proves the
        // empty-content guard didn't leave the server (or its `connections` bookkeeping) in a
        // broken state.
        var passed = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            passed = httpResp.statusCode == 200
        }
        report("Feature/HttpSharing", "POS: server stays healthy after a client connects and disconnects without sending any data", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// Covers the second guard in `receiveRequest()`: bytes that fail UTF-8 decoding must close
    /// the connection instead of crashing `processRequest`.
    private static func testNonUtf8ConnectionContentIsClosedSafely() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var connectionWasClosedByServer = false
        if let sock = rawConnect(port: 8080) {
            // 0xFF/0xFE are never valid standalone UTF-8 lead bytes - this is guaranteed invalid.
            rawSendBytes(sock, [0xFF, 0xFE, 0x00, 0x01])
            let response = rawRecvAll(sock, timeoutMs: 1000)
            // The server calls connection.cancel() without writing a response, so nothing comes
            // back other than an orderly close (empty read).
            connectionWasClosedByServer = response.isEmpty
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: non-UTF8 request bytes close the connection without a response or a crash", result: connectionWasClosedByServer)

        var stillHealthy = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            stillHealthy = httpResp.statusCode == 200
        }
        report("Feature/HttpSharing", "POS: server stays healthy after a client sends non-UTF8 bytes", result: stillHealthy)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Helpers

    static let requestSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        return URLSession(configuration: config)
    }()

    static func waitUntil(timeoutSeconds: Double = 1.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition(), Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    static func rawConnect(port: UInt16) -> Int32? {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return nil }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else {
            Darwin.close(sock)
            return nil
        }
        return sock
    }

    static func rawSend(_ sock: Int32, _ text: String) {
        rawSendBytes(sock, Array(text.utf8))
    }

    static func rawSendBytes(_ sock: Int32, _ bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { buf in
            _ = Darwin.send(sock, buf.baseAddress, buf.count, 0)
        }
    }

    static func rawRecvAll(_ sock: Int32, timeoutMs: Int) -> Data {
        var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = buf.withUnsafeMutableBufferPointer { ptr in
                Darwin.recv(sock, ptr.baseAddress, ptr.count, 0)
            }
            if bytesRead <= 0 {
                break
            }
            data.append(contentsOf: buf[0 ..< bytesRead])
        }
        return data
    }

    static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
