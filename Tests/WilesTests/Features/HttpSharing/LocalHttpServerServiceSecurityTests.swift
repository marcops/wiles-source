import Darwin
import Foundation
@testable import Wiles

/// Regression coverage for `LocalHttpServerService`'s security/robustness fixes — C2 (stored XSS in
/// the directory listing) and M11 (fragmented / oversized request head). Split out of
/// `LocalHttpServerServiceTests.swift` to keep that file under the length cap; reuses its raw-socket
/// helpers (`rawConnect`/`rawSend`/`rawRecvAll`/`waitUntil`/`report`/`requestSession`).
@MainActor
extension HttpSharingFeatureTests {
    static func runSecurityAndRobustnessChecks() async {
        await testDirectoryListingEscapesEntryNamesAndSetsCSP()
        await testFragmentedRequestHeadIsAccumulatedBeforeParsing()
        await testOversizedRequestHeadReturns431()
        await testNestedSubfolderIsListedNotStreamed()
    }

    // MARK: - Nested subfolder listing (M12 regression)

    /// Clicking a subfolder in the share used to route to `serveFile` → `streamFile` on a directory
    /// → 500 "Error reading file". Now a directory target recurses into `serveDirectoryListing`, so
    /// GETting the subfolder path returns 200 with its contents (entry names still HTML-escaped).
    private static func testNestedSubfolderIsListedNotStreamed() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let subDir = tempDir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        // No "/" in the name (that would split into path components); still exercises < > & escaping.
        let nestedName = "<b>nested & child.txt"
        try? "y".write(to: subDir.appendingPathComponent(nestedName), atomically: true, encoding: .utf8)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var status200 = false
        var listsNestedFileEscaped = false
        if let (data, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/sub/")!),
           let httpResp = resp as? HTTPURLResponse {
            let body = String(data: data, encoding: .utf8) ?? ""
            status200 = httpResp.statusCode == 200
            listsNestedFileEscaped = body.contains("&lt;b&gt;nested &amp; child.txt")
        }
        report("Feature/HttpSharing", "POS: GET on a nested subfolder path returns a 200 directory listing", result: status200)
        report(
            "Feature/HttpSharing",
            "POS: nested subfolder listing shows its files with HTML-escaped names",
            result: listsNestedFileEscaped)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Stored XSS in the directory listing (C2 regression)

    /// A file whose name is HTML markup must appear escaped in the served listing, never as live
    /// markup, and the listing response must carry a restrictive Content-Security-Policy. Before the
    /// fix, `serveDirectoryListing` interpolated `url.lastPathComponent` into the page verbatim.
    private static func testDirectoryListingEscapesEntryNamesAndSetsCSP() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let maliciousName = "<img src=x onerror=alert(1)>.txt"
        try? "x".write(to: tempDir.appendingPathComponent(maliciousName), atomically: true, encoding: .utf8)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var bodyEscaped = false
        var noRawMarkup = false
        var hasCSP = false
        if let (data, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!),
           let httpResp = resp as? HTTPURLResponse {
            let body = String(data: data, encoding: .utf8) ?? ""
            bodyEscaped = body.contains("&lt;img src=x onerror=alert(1)&gt;.txt")
            noRawMarkup = !body.contains("<img src=x onerror=alert(1)>")
            let cspHeader = httpResp.value(forHTTPHeaderField: "Content-Security-Policy") ?? ""
            hasCSP = cspHeader.contains("default-src 'none'")
        }
        report("Feature/HttpSharing", "POS: directory listing HTML-escapes an entry name that is markup", result: bodyEscaped)
        report("Feature/HttpSharing", "NEG: directory listing never emits an entry name as raw markup", result: noRawMarkup)
        report("Feature/HttpSharing", "POS: directory listing response sets a restrictive Content-Security-Policy header", result: hasCSP)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Fragmented / oversized request head (M11 regression)

    /// The request line and headers can arrive in separate TCP segments. Before the fix,
    /// `receiveRequest` parsed whatever landed in the first `receive`, so a split request produced a
    /// spurious 401/404. Now bytes accumulate until `\r\n\r\n`.
    private static func testFragmentedRequestHeadIsAccumulatedBeforeParsing() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            rawSend(sock, "GET / HTTP/1.1\r\n")
            try? await Task.sleep(nanoseconds: 120_000_000)
            rawSend(sock, "Host: localhost\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1500)
            passed = (String(data: response, encoding: .utf8) ?? "").hasPrefix("HTTP/1.1 200")
            Darwin.close(sock)
        }
        report(
            "Feature/HttpSharing",
            "POS: a request head split across two TCP segments is accumulated and parsed as one request",
            result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// A client that keeps sending header bytes without ever terminating the head must get 431
    /// rather than growing server memory unbounded.
    private static func testOversizedRequestHeadReturns431() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: 8080) {
            rawSend(sock, "GET / HTTP/1.1\r\n")
            let filler = "X-Pad: " + String(repeating: "a", count: 4000) + "\r\n"
            for _ in 0 ..< 12 {
                rawSend(sock, filler)
            }
            let response = rawRecvAll(sock, timeoutMs: 1500)
            passed = (String(data: response, encoding: .utf8) ?? "").hasPrefix("HTTP/1.1 431")
            Darwin.close(sock)
        }
        report(
            "Feature/HttpSharing",
            "NEG: a request head exceeding the size cap returns 431 Request Header Fields Too Large",
            result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }
}
