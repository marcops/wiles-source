@testable import Wiles
import Foundation

@MainActor
public struct HttpServerTests {
    public static func run() async {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let sampleFile = tempDir.appendingPathComponent("public_share.txt")
        try? "Public Data".write(to: sampleFile, atomically: true, encoding: .utf8)
        
        let server = LocalHttpServerService.shared
        server.start(sharing: tempDir)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Positive: HTTP 200 OK Directory Index
        var posHttpPassed = false
        if let rootURL = URL(string: "http://localhost:8080") {
            if let (data, resp) = try? await URLSession.shared.data(from: rootURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let html = String(data: data, encoding: .utf8) ?? ""
                posHttpPassed = html.contains("public_share.txt")
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET / returns 200 OK & directory HTML", result: posHttpPassed)
        
        // Positive: File Content Download
        var posFileFetchPassed = false
        if let fileURL = URL(string: "http://localhost:8080/public_share.txt") {
            if let (data, resp) = try? await URLSession.shared.data(from: fileURL),
               let httpResp = resp as? HTTPURLResponse, httpResp.statusCode == 200 {
                let text = String(data: data, encoding: .utf8) ?? ""
                posFileFetchPassed = text == "Public Data"
            }
        }
        TestReporter.report("LocalHttpServer", "POS: GET /public_share.txt returns 200 OK & file payload", result: posFileFetchPassed)
        
        // Negative: Path Traversal Attack (/../)
        var negTraversalBlocked = false
        if let traversalURL = URL(string: "http://localhost:8080/../etc/passwd") {
            if let (_, resp) = try? await URLSession.shared.data(from: traversalURL),
               let httpResp = resp as? HTTPURLResponse {
                negTraversalBlocked = httpResp.statusCode == 403 || httpResp.statusCode == 400
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Path traversal attempt (/../etc/passwd) blocked with 403 Forbidden", result: negTraversalBlocked)
        
        // Negative: Non-Existent File 404
        var neg404Passed = false
        if let missingURL = URL(string: "http://localhost:8080/does_not_exist.txt") {
            if let (_, resp) = try? await URLSession.shared.data(from: missingURL),
               let httpResp = resp as? HTTPURLResponse {
                neg404Passed = httpResp.statusCode == 404
            }
        }
        TestReporter.report("LocalHttpServer", "NEG: Requesting non-existent file returns 404 Not Found", result: neg404Passed)
        
        server.stop()
        try? FileManager.default.removeItem(at: tempDir)
    }
}
