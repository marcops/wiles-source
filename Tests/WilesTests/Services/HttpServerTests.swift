@testable import Wiles
import Foundation

@MainActor
public struct HttpServerTests {
    // A short, strict timeout so a server that fails to bind (e.g. port contention across test
    // runs) makes requests fail fast instead of hanging up to Self.requestSession's default 60s —
    // with 15+ requests in this file, that default could turn a real failure into a multi-minute
    // stall that looks like a deadlock.
    private static let requestSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 3
        return URLSession(configuration: config)
    }()

    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let sampleFile = tempDir.appendingPathComponent("public_share.txt")
        try? "Public Data".write(to: sampleFile, atomically: true, encoding: .utf8)

        let nestedDir = tempDir.appendingPathComponent("subdir")
        try? FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
        let nestedFile = nestedDir.appendingPathComponent("nested.txt")
        try? "Nested Data".write(to: nestedFile, atomically: true, encoding: .utf8)

        let htmlFile = tempDir.appendingPathComponent("page.html")
        try? "<h1>Hi</h1>".write(to: htmlFile, atomically: true, encoding: .utf8)

        let spacedFile = tempDir.appendingPathComponent("file with space.txt")
        try? "Spaced".write(to: spacedFile, atomically: true, encoding: .utf8)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        try? await Task.sleep(nanoseconds: 500_000_000)

        await checkDirectoryIndex()
        await checkFileDownload()
        await checkPathTraversalBlocked()
        await checkMissingFile404()
        checkServerURLPopulatedWhileRunning(server)
        checkIsRunningTrueWhileRunning(server)
        await checkMethodNotAllowed()
        await checkHeadMethodNotAllowed()
        await checkNestedFileServed()
        await checkRequestingDirectoryPathReturns500()
        await checkNoMimeTypeSniffing()
        await checkFileWithSpaceInNameServed()
        await checkEncodedPathTraversalBlocked()
        await checkNestedPathTraversalBlocked()
        await checkDirectoryListingSortedOrder()
        await checkContentLengthMatchesBodySize()
        await checkSiblingDirectoryTraversalBlocked(tempDir: tempDir)
        await checkTrailingSlashDirectoryReturns500()
        await checkEmptyDirectoryListing()

        server.stop()
        try? await Task.sleep(nanoseconds: 300_000_000)
        checkIsRunningFalseAfterStop(server)
        checkServerURLNilAfterStop(server)
        await checkRequestFailsAfterStop()

        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func checkDirectoryIndex() async {
        var passed = false
        if let rootURL = URL(string: "http://localhost:8080") {
            if let (data, resp) = try? await Self.requestSession.data(from: rootURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let html = String(data: data, encoding: .utf8) ?? ""
                passed = html.contains("public_share.txt")
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET / returns 200 OK & directory HTML", result: passed)
    }

    private static func checkFileDownload() async {
        var passed = false
        if let fileURL = URL(string: "http://localhost:8080/public_share.txt") {
            if let (data, resp) = try? await Self.requestSession.data(from: fileURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                passed = text == "Public Data"
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET /public_share.txt returns 200 OK & file payload", result: passed)
    }

    private static func checkPathTraversalBlocked() async {
        var blocked = false
        if let traversalURL = URL(string: "http://localhost:8080/../etc/passwd") {
            if let (_, resp) = try? await Self.requestSession.data(from: traversalURL),
               let httpResp = resp as? HTTPURLResponse {
                blocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Path traversal attempt (/../etc/passwd) blocked with 403 Forbidden", result: blocked)
    }

    private static func checkMissingFile404() async {
        var passed = false
        if let missingURL = URL(string: "http://localhost:8080/does_not_exist.txt") {
            if let (_, resp) = try? await Self.requestSession.data(from: missingURL),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 404
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requesting non-existent file returns 404 Not Found", result: passed)
    }

    private static func checkServerURLPopulatedWhileRunning(_ server: LocalHttpServerService) {
        TestReporter.report("LocalHttpServer", "POS: serverURL is populated (non-nil) while the server is running", result: server.serverURL != nil)
    }

    private static func checkIsRunningTrueWhileRunning(_ server: LocalHttpServerService) {
        TestReporter.report("LocalHttpServer", "POS: isRunning is true after start()", result: server.isRunning)
    }

    private static func checkMethodNotAllowed() async {
        var passed = false
        if let url = URL(string: "http://localhost:8080/") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            if let (_, resp) = try? await Self.requestSession.data(for: request),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 405
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Non-GET request (POST) returns 405 Method Not Allowed", result: passed)
    }

    private static func checkIsRunningFalseAfterStop(_ server: LocalHttpServerService) {
        TestReporter.report("LocalHttpServer", "POS: isRunning becomes false after stop()", result: !server.isRunning)
    }

    private static func checkServerURLNilAfterStop(_ server: LocalHttpServerService) {
        TestReporter.report("LocalHttpServer", "POS: serverURL becomes nil after stop()", result: server.serverURL == nil)
    }

    private static func checkRequestFailsAfterStop() async {
        var requestFailed = false
        if let rootURL = URL(string: "http://localhost:8080") {
            do {
                _ = try await Self.requestSession.data(from: rootURL)
                requestFailed = false
            } catch {
                requestFailed = true
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requests fail after stop() has been called", result: requestFailed)
    }

    private static func checkHeadMethodNotAllowed() async {
        var passed = false
        if let url = URL(string: "http://localhost:8080/") {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            if let (_, resp) = try? await Self.requestSession.data(for: request),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 405
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Non-GET request (HEAD) returns 405 Method Not Allowed", result: passed)
    }

    private static func checkNestedFileServed() async {
        var passed = false
        if let url = URL(string: "http://localhost:8080/subdir/nested.txt") {
            if let (data, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                passed = text == "Nested Data"
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET /subdir/nested.txt (nested subdirectory file) returns 200 OK & correct payload", result: passed)
    }

    private static func checkRequestingDirectoryPathReturns500() async {
        // Requesting a path that resolves to a directory (not a file) passes the fileExists()
        // check (which is true for directories too) but then Data(contentsOf:) fails,
        // exercising the internalServerError branch in serveFile.
        var passed = false
        if let url = URL(string: "http://localhost:8080/subdir") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 500
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requesting a directory path (not a file) as a download returns 500 Internal Server Error", result: passed)
    }

    private static func checkNoMimeTypeSniffing() async {
        // The server does not inspect file extensions when serving downloads; it always
        // responds with application/octet-stream, even for an .html file. This asserts the
        // real (perhaps surprising) current behavior rather than an idealized one.
        var passed = false
        if let url = URL(string: "http://localhost:8080/page.html") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                passed = httpResp.value(forHTTPHeaderField: "Content-Type") == "application/octet-stream"
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Served .html file has no MIME sniffing - Content-Type is application/octet-stream, not text/html", result: passed)
    }

    private static func checkFileWithSpaceInNameServed() async {
        var passed = false
        if let url = URL(string: "http://localhost:8080/file%20with%20space.txt") {
            if let (data, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                passed = text == "Spaced"
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET percent-encoded filename with space returns 200 OK & correct payload", result: passed)
    }

    private static func checkEncodedPathTraversalBlocked() async {
        var blocked = false
        if let url = URL(string: "http://localhost:8080/%2e%2e/%2e%2e/etc/passwd") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse {
                blocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Percent-encoded path traversal (%2e%2e/) is blocked with 403/400", result: blocked)
    }

    private static func checkNestedPathTraversalBlocked() async {
        var blocked = false
        if let url = URL(string: "http://localhost:8080/subdir/../../../../etc/passwd") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse {
                blocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Path traversal via nested subdirectory (/subdir/../../../etc/passwd) is blocked", result: blocked)
    }

    private static func checkDirectoryListingSortedOrder() async {
        var passed = false
        if let rootURL = URL(string: "http://localhost:8080") {
            if let (data, resp) = try? await Self.requestSession.data(from: rootURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let html = String(data: data, encoding: .utf8) ?? ""
                if let fileRange = html.range(of: "file with space.txt"),
                   let publicRange = html.range(of: "public_share.txt") {
                    // "file with space.txt" sorts before "public_share.txt" alphabetically.
                    passed = fileRange.lowerBound < publicRange.lowerBound
                }
            }
        }
        TestReporter.report("LocalHttpServer", "POS: Directory listing entries are sorted alphabetically by filename", result: passed)
    }

    private static func checkContentLengthMatchesBodySize() async {
        var passed = false
        if let url = URL(string: "http://localhost:8080/public_share.txt") {
            if let (data, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let headerLength = httpResp.value(forHTTPHeaderField: "Content-Length").flatMap { Int($0) }
                passed = headerLength == data.count && data.count == "Public Data".utf8.count
            }
        }
        TestReporter.report("LocalHttpServer", "POS: Content-Length header matches actual response body byte count", result: passed)
    }

    private static func checkSiblingDirectoryTraversalBlocked(tempDir: URL) async {
        // Regression test for the path-separator-boundary hardening in serveFile: a plain
        // hasPrefix(stdFolder) check would wrongly let this through, since a sibling directory
        // whose name starts with the shared folder's name (e.g. "<uuid>EVIL") also has
        // stdFolder as a string prefix. Requiring the "/" boundary must block it.
        var blocked = false
        let siblingDir = tempDir.deletingLastPathComponent()
            .appendingPathComponent(tempDir.lastPathComponent + "EVIL")
        try? FileManager.default.createDirectory(at: siblingDir, withIntermediateDirectories: true)
        let secretFile = siblingDir.appendingPathComponent("secret.txt")
        try? "Top Secret".write(to: secretFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: siblingDir) }

        let path = "/../\(tempDir.lastPathComponent)EVIL/secret.txt"
        if let url = URL(string: "http://localhost:8080\(path)") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse {
                blocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Path traversal into a sibling directory sharing the shared folder's name prefix (e.g. \"<uuid>EVIL\") is blocked", result: blocked)
    }

    private static func checkTrailingSlashDirectoryReturns500() async {
        // A path with a trailing slash (e.g. /subdir/) does not equal "/" and is not empty, so
        // it goes through serveFile (not serveDirectoryListing). It resolves to a directory,
        // passes fileExists(), then fails Data(contentsOf:), exercising the same 500 branch as
        // the no-trailing-slash case but via a distinct path-parsing route.
        var passed = false
        if let url = URL(string: "http://localhost:8080/subdir/") {
            if let (_, resp) = try? await Self.requestSession.data(from: url),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 500
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requesting a directory path with a trailing slash (/subdir/) returns 500 Internal Server Error", result: passed)
    }

    private static func checkEmptyDirectoryListing() async {
        // Requires a genuinely empty shared folder, so this spins the singleton server
        // down and back up on an isolated temp directory, then restores nothing further
        // since the caller stops/tears down the server again right after this returns.
        var passed = false
        let emptyDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let server = LocalHttpServerService.shared
        server.stop()
        try? await Task.sleep(nanoseconds: 300_000_000)

        server.start(sharing: emptyDir)
        try? await Task.sleep(nanoseconds: 500_000_000)

        if let rootURL = URL(string: "http://localhost:8080") {
            if let (data, resp) = try? await Self.requestSession.data(from: rootURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let html = String(data: data, encoding: .utf8) ?? ""
                passed = html.contains("<ul>") && html.contains("</ul>") && !html.contains("<li")
            }
        }

        server.stop()
        try? await Task.sleep(nanoseconds: 300_000_000)

        TestReporter.report("LocalHttpServer", "POS: Directory listing for an empty shared folder returns 200 OK with an empty <ul> and no entries", result: passed)
    }
}
