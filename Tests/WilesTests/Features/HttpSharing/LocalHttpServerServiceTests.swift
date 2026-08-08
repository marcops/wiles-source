@testable import Wiles
import Foundation
import Darwin

@MainActor
public struct HttpSharingFeatureTests {
    public static func run() async {
        let server = LocalHttpServerService.shared
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

        server.stop()
    }

    // MARK: - Directory-removed-after-start (serveDirectoryListing catch branch)

    /// Covers the `catch` branch in `serveDirectoryListing()`: `contentsOfDirectory(at:)` throws
    /// when the shared folder no longer exists on disk at request time (e.g. removed/unmounted
    /// after `start(sharing:)` was called but before a request arrives).
    private static func testDirectoryRemovedAfterStartReturns500() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService.shared
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

        let server = LocalHttpServerService.shared
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

        let server = LocalHttpServerService.shared
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

        let server = LocalHttpServerService.shared
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

    private static let requestSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        return URLSession(configuration: config)
    }()

    private static func waitUntil(timeoutSeconds: Double = 1.0, _ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private static func rawConnect(port: UInt16) -> Int32? {
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

    private static func rawSend(_ sock: Int32, _ text: String) {
        rawSendBytes(sock, Array(text.utf8))
    }

    private static func rawSendBytes(_ sock: Int32, _ bytes: [UInt8]) {
        bytes.withUnsafeBufferPointer { buf in
            _ = Darwin.send(sock, buf.baseAddress, buf.count, 0)
        }
    }

    private static func rawRecvAll(_ sock: Int32, timeoutMs: Int) -> Data {
        var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: Int32((timeoutMs % 1000) * 1000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buf = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = buf.withUnsafeMutableBufferPointer { ptr in
                Darwin.recv(sock, ptr.baseAddress, ptr.count, 0)
            }
            if bytesRead <= 0 { break }
            data.append(contentsOf: buf[0..<bytesRead])
        }
        return data
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
