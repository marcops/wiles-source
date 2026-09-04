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
        testDirectoryListingHrefCannotBreakOutOfTheAttribute()
        await testFragmentedRequestHeadIsAccumulatedBeforeParsing()
        await testOversizedRequestHeadReturns431()
        await testSlowlorisPartialHeadIsCancelledAtTheRequestHeadDeadline()
        await testCompleteHeadWithinTheDeadlineIsServedNormally()
        await testNestedSubfolderIsListedNotStreamed()
        await testHiddenEntriesAreNeitherListedNorServed()
        testRequestPathRejectsNulByteAndEmptyComponents()
        testParseByteRange()
        await testPasswordProtectedRequestWithDifferentLengthPasswordReturns401()
        testHttpHeadIsCrlfFramed()
        await testRangeResponseHeaderIsWellFramed()
    }

    /// LL-055: both response paths now build the head via the one list-based `httpHead` — every
    /// header line ends `\r\n` and the block ends with exactly one blank `\r\n`.
    private static func testHttpHeadIsCrlfFramed() {
        let text = String(
            data: LocalHttpServerService.httpHead(statusCode: 200, headers: [
                ("Content-Length", "5"),
                ("Content-Type", "text/plain"),
                ("Connection", "close")
            ]),
            encoding: .utf8) ?? ""
        // status line + exactly 3 header lines + the terminating blank line, all CRLF, nothing after.
        let lines = text.components(separatedBy: "\r\n")
        let framed = text.hasPrefix("HTTP/1.1 200 ")
            && text.hasSuffix("\r\n\r\n")
            && !text.contains("\n\n") // no bare-LF blank line
            && lines.count == 6 // status, 3 headers, "", "" (trailing)
            && lines[1] == "Content-Length: 5"
            && lines[2] == "Content-Type: text/plain"
            && lines[3] == "Connection: close"
        report(
            "Feature/HttpSharing",
            "POS: httpHead emits status line + CRLF-terminated headers + a single blank line",
            result: framed)

        let empty = String(data: LocalHttpServerService.httpHead(statusCode: 404, headers: []), encoding: .utf8) ?? ""
        report(
            "Feature/HttpSharing",
            "POS: httpHead with no headers is still a valid frame (status line then blank line)",
            result: empty.hasPrefix("HTTP/1.1 404 ") && empty.hasSuffix("\r\n\r\n") && empty.components(separatedBy: "\r\n").count == 3)
    }

    /// LL-055: exercise the file-streaming path (`streamResponseHeader`, now delegating to
    /// `httpHead`) end-to-end with a real range request — the 206 head must be well-framed and
    /// carry the range headers.
    private static func testRangeResponseHeaderIsWellFramed() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let file = tempDir.appendingPathComponent("payload.bin")
        try? Data(repeating: 0x41, count: 200).write(to: file)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil(timeoutSeconds: 3) { server.isRunning }

        var ok = false
        if let sock = rawConnect(port: server.port.rawValue) {
            rawSend(sock, "GET /payload.bin HTTP/1.1\r\nHost: localhost\r\nRange: bytes=0-49\r\n\r\n")
            let text = String(data: rawRecvAll(sock, timeoutMs: 1500), encoding: .utf8) ?? ""
            Darwin.close(sock)
            let headEnd = text.range(of: "\r\n\r\n")
            let head = headEnd.map { String(text[text.startIndex ..< $0.lowerBound]) } ?? ""
            ok = text.hasPrefix("HTTP/1.1 206")
                && head.contains("\r\nContent-Range: bytes 0-49/200\r\n")
                && head.contains("\r\nAccept-Ranges: bytes\r\n")
                && head.contains("\r\nConnection: close")
                && headEnd != nil
        }
        report(
            "Feature/HttpSharing",
            "POS: a Range request's 206 response head is CRLF-framed and carries Content-Range / Accept-Ranges (LL-055)",
            result: ok)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func testParseByteRange() {
        typealias Range = LocalHttpServerService.RequestedByteRange
        func isSatisfiable(_ range: Range, _ start: Int, _ end: Int) -> Bool {
            if case let .satisfiable(gotStart, gotEnd) = range {
                return gotStart == start && gotEnd == end
            }
            return false
        }
        func isNone(_ range: Range) -> Bool {
            if case .none = range {
                return true
            }
            return false
        }
        func isUnsatisfiable(_ range: Range) -> Bool {
            if case .unsatisfiable = range {
                return true
            }
            return false
        }
        let parse = LocalHttpServerService.parseByteRange

        report("Feature/HttpSharing", "POS: no Range header -> .none", result: isNone(parse(nil, 100)))
        report("Feature/HttpSharing", "POS: 'Range: bytes=0-99' -> .satisfiable(0, 99)", result: isSatisfiable(parse("Range: bytes=0-99", 500), 0, 99))
        report("Feature/HttpSharing", "POS: open-ended 'bytes=100-' clamps to last byte", result: isSatisfiable(parse("Range: bytes=100-", 500), 100, 499))
        report("Feature/HttpSharing", "POS: suffix 'bytes=-50' is the last 50 bytes", result: isSatisfiable(parse("Range: bytes=-50", 500), 450, 499))
        report("Feature/HttpSharing", "POS: end past EOF is clamped to last byte", result: isSatisfiable(parse("Range: bytes=0-99999", 500), 0, 499))
        report("Feature/HttpSharing", "NEG: start beyond EOF -> .unsatisfiable", result: isUnsatisfiable(parse("Range: bytes=999-", 500)))
        report("Feature/HttpSharing", "NEG: multi-range spec is ignored -> .none", result: isNone(parse("Range: bytes=0-9,20-29", 500)))
        report("Feature/HttpSharing", "NEG: non-bytes unit is ignored -> .none", result: isNone(parse("Range: items=0-9", 500)))
        report("Feature/HttpSharing", "NEG: reversed range (end < start) -> .none", result: isNone(parse("Range: bytes=200-100", 500)))
    }

    private static func testPasswordProtectedRequestWithDifferentLengthPasswordReturns401() async {
        // The constant-time check compares SHA-256 digests (no length guard) — a wrong password of a
        // very different length must still be rejected.
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir, password: "secret123")
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: server.port.rawValue) {
            let wrongAuth = "Basic " + Data("someone:x".utf8).base64EncodedString()
            rawSend(sock, "GET / HTTP/1.1\r\nHost: localhost\r\nAuthorization: \(wrongAuth)\r\n\r\n")
            let response = rawRecvAll(sock, timeoutMs: 1000)
            passed = (String(data: response, encoding: .utf8) ?? "").hasPrefix("HTTP/1.1 401")
            Darwin.close(sock)
        }
        report("Feature/HttpSharing", "NEG: GET / with a wrong password of a different length still returns 401 Unauthorized", result: passed)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// `isSafeRequestPath` rejects a decoded path with a NUL byte or an interior empty component,
    /// before it reaches `appendingPathComponent` / the C-API file open.
    private static func testRequestPathRejectsNulByteAndEmptyComponents() {
        let safe = ["/", "/file.txt", "/sub/file.txt", "/sub/", "/a b/c.txt"]
        let unsafe = ["/file\u{0}.txt", "//file.txt", "/a//b.txt", "/\u{0}"]
        let allSafePass = safe.allSatisfy { LocalHttpServerService.isSafeRequestPath($0) }
        let allUnsafeRejected = unsafe.allSatisfy { !LocalHttpServerService.isSafeRequestPath($0) }
        report("Feature/HttpSharing", "POS: isSafeRequestPath accepts well-formed request paths", result: allSafePass)
        report("Feature/HttpSharing", "NEG: isSafeRequestPath rejects NUL bytes and empty path components", result: allUnsafeRejected)
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

        let server = LocalHttpServerService()
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

    /// Sharing a project folder must not leak `.git`/`.env`/`.ssh` etc. over the LAN — hidden
    /// entries are absent from the listing and a direct request for one is refused.
    private static func testHiddenEntriesAreNeitherListedNorServed() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? "SECRET=1".write(to: tempDir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try? "visible".write(to: tempDir.appendingPathComponent("readme.txt"), atomically: true, encoding: .utf8)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var listingHidesDotfile = false
        if let (data, _) = try? await requestSession.data(from: URL(string: "http://localhost:8080/")!) {
            let body = String(data: data, encoding: .utf8) ?? ""
            listingHidesDotfile = body.contains("readme.txt") && !body.contains(".env")
        }
        var dotfileRequestRefused = false
        if let (_, resp) = try? await requestSession.data(from: URL(string: "http://localhost:8080/.env")!),
           let httpResp = resp as? HTTPURLResponse {
            dotfileRequestRefused = httpResp.statusCode == 403
        }
        report("Feature/HttpSharing", "POS: the LAN listing omits hidden entries", result: listingHidesDotfile)
        report("Feature/HttpSharing", "NEG: a direct GET for a hidden file is refused with 403", result: dotfileRequestRefused)

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

        let server = LocalHttpServerService()
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

    /// The `href` of every listing entry must be attribute-safe — a `"` in a file name can't break
    /// out of `href="…"` (percent-encoded on the normal path; the nil-fallback is now HTML-escaped
    /// rather than the raw name).
    private static func testDirectoryListingHrefCannotBreakOutOfTheAttribute() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let nasty = dir.appendingPathComponent("a\" onmouseover=x b<c.txt")
        let html = LocalHttpServerService.listingItemsHTML(sorted: [nasty], linkPrefix: "", language: .english)

        // The raw `" onmouseover=x` sequence (a real quote closing the attribute early) must appear
        // nowhere — the name's `"` is `%22` in the href and `&quot;` in the label.
        let noAttributeBreakout = !html.contains("\" onmouseover=x") && !html.contains("<c.txt")
        report(
            "Feature/HttpSharing",
            "NEG: a file name containing a double quote / '<' produces no href/attribute breakout",
            result: noAttributeBreakout)
    }

    // MARK: - Fragmented / oversized request head (M11 regression)

    /// The request line and headers can arrive in separate TCP segments. Before the fix,
    /// `receiveRequest` parsed whatever landed in the first `receive`, so a split request produced a
    /// spurious 401/404. Now bytes accumulate until `\r\n\r\n`.
    private static func testFragmentedRequestHeadIsAccumulatedBeforeParsing() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: server.port.rawValue) {
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

        let server = LocalHttpServerService()
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var passed = false
        if let sock = rawConnect(port: server.port.rawValue) {
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

    // MARK: - Slowloris (MM-146 regression)

    /// A client that opens a connection and dribbles head bytes without ever sending the `\r\n\r\n`
    /// terminator used to hold its connection slot until it chose to close — 32 of them stopped the
    /// server accepting connections. The request-head deadline is now a hard limit from connect
    /// time, not extended by incoming bytes, so the connection is cancelled at the deadline.
    private static func testSlowlorisPartialHeadIsCancelledAtTheRequestHeadDeadline() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let server = LocalHttpServerService()
        server.requestHeadDeadlineOverride = 0.4
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        let sock = rawConnect(port: server.port.rawValue)
        var connectionClosedWithoutResponse = false
        if let sock {
            // A partial request head, never terminated with `\r\n\r\n`.
            rawSend(sock, "GET / HTTP/1.1\r\n")
        }
        // Wait past the (overridden) request-head deadline; the server must cancel the connection.
        try? await Task.sleep(nanoseconds: 900_000_000)
        if let sock {
            let response = rawRecvAll(sock, timeoutMs: 300)
            connectionClosedWithoutResponse = response.isEmpty
            Darwin.close(sock)
        }
        report(
            "Feature/HttpSharing",
            "NEG: a slowloris connection that never completes its head is cancelled at the request-head deadline",
            result: connectionClosedWithoutResponse)

        var stillHealthy = false
        let healthURL = URL(string: "http://localhost:\(server.port.rawValue)/") ?? URL(fileURLWithPath: "/")
        if let (_, resp) = try? await requestSession.data(from: healthURL),
           let httpResp = resp as? HTTPURLResponse {
            stillHealthy = httpResp.statusCode == 200
        }
        report(
            "Feature/HttpSharing",
            "POS: the server keeps serving after a slowloris connection is cancelled",
            result: stillHealthy)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }

    /// The deadline must not punish a legitimate client: a complete head that arrives before it
    /// (even under a very tight deadline) is served, and the deadline is cleared so it can't later
    /// fire against the now-streaming connection.
    private static func testCompleteHeadWithinTheDeadlineIsServedNormally() async {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try? "hello".write(to: tempDir.appendingPathComponent("f.txt"), atomically: true, encoding: .utf8)

        let server = LocalHttpServerService()
        server.requestHeadDeadlineOverride = 0.5
        server.start(sharing: tempDir)
        await waitUntil { server.isRunning }

        var served = false
        if let sock = rawConnect(port: server.port.rawValue) {
            rawSend(sock, "GET /f.txt HTTP/1.1\r\nHost: localhost\r\n\r\n")
            let text = String(data: rawRecvAll(sock, timeoutMs: 1000), encoding: .utf8) ?? ""
            served = text.hasPrefix("HTTP/1.1 200") && text.hasSuffix("hello")
            Darwin.close(sock)
        }
        // Well past the deadline: a spuriously-surviving timer would have torn state down by now.
        try? await Task.sleep(nanoseconds: 700_000_000)
        var stillHealthy = false
        let healthURL = URL(string: "http://localhost:\(server.port.rawValue)/") ?? URL(fileURLWithPath: "/")
        if let (_, resp) = try? await requestSession.data(from: healthURL),
           let httpResp = resp as? HTTPURLResponse {
            stillHealthy = httpResp.statusCode == 200
        }
        report(
            "Feature/HttpSharing",
            "POS: a complete head received before the deadline is served and the deadline is cleared",
            result: served && stillHealthy)

        server.stop()
        await waitUntil { !server.isRunning }
        try? FileManager.default.removeItem(at: tempDir)
    }
}
