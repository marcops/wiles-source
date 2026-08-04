@testable import Wiles
import Foundation

@MainActor
public struct HttpServerTests {
    public static func run() async {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let sampleFile = tempDir.appendingPathComponent("public_share.txt")
        try? "Public Data".write(to: sampleFile, atomically: true, encoding: .utf8)

        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        try? await Task.sleep(nanoseconds: 500_000_000)

        await checkDirectoryIndex()
        await checkFileDownload()
        await checkPathTraversalBlocked()
        await checkMissingFile404()

        server.stop()
        try? FileManager.default.removeItem(at: tempDir)
    }

    private static func checkDirectoryIndex() async {
        var passed = false
        if let rootURL = URL(string: "http://localhost:8080") {
            if let (data, resp) = try? await URLSession.shared.data(from: rootURL),
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
            if let (data, resp) = try? await URLSession.shared.data(from: fileURL),
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
            if let (_, resp) = try? await URLSession.shared.data(from: traversalURL),
               let httpResp = resp as? HTTPURLResponse {
                blocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Path traversal attempt (/../etc/passwd) blocked with 403 Forbidden", result: blocked)
    }

    private static func checkMissingFile404() async {
        var passed = false
        if let missingURL = URL(string: "http://localhost:8080/does_not_exist.txt") {
            if let (_, resp) = try? await URLSession.shared.data(from: missingURL),
               let httpResp = resp as? HTTPURLResponse {
                passed = httpResp.statusCode == 404
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requesting non-existent file returns 404 Not Found", result: passed)
    }
}
