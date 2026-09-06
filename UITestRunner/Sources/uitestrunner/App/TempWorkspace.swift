import Foundation
import PDFKit

/// A throwaway directory the walkthrough navigates Wiles into, pre-seeded with the files the
/// feature steps act on. Everything the run creates or mutates stays inside it; `cleanup()`
/// removes the whole tree.
final class TempWorkspace {
    /// The folder Wiles is pointed at. Named "Downloads" (not a raw UUID) so the path bar / title
    /// reads cleanly in screenshots; the UUID lives one level up, in `container`.
    let root: URL
    private let container: URL

    let alphaFile = "alpha-uitest.txt"
    let betaFile = "beta-uitest.txt"
    let subFolder = "sub-uitest"
    let imageFile = "pic-uitest.png"
    let zipFile = "archive-uitest.zip"
    let pdfOne = "one-uitest.pdf"
    let pdfTwo = "two-uitest.pdf"

    /// 1×1 transparent PNG.
    private let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    init() {
        container = FileManager.default.temporaryDirectory
            .appendingPathComponent("WilesAXUITest-\(UUID().uuidString)", isDirectory: true)
        root = container.appendingPathComponent("Downloads", isDirectory: true)
    }

    func prepare() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        try "alpha contents".write(to: url(alphaFile), atomically: true, encoding: .utf8)
        try "beta contents".write(to: url(betaFile), atomically: true, encoding: .utf8)
        try fileManager.createDirectory(at: url(subFolder), withIntermediateDirectories: true)
        if let png = Data(base64Encoded: onePixelPNGBase64) {
            try png.write(to: url(imageFile))
        }
        writeBlankPDF(to: url(pdfOne))
        writeBlankPDF(to: url(pdfTwo))
        makeSeedZip()
    }

    func url(_ name: String) -> URL {
        root.appendingPathComponent(name)
    }

    func exists(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: url(name).path)
    }

    func waitForExistence(_ name: String, shouldExist: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if exists(name) == shouldExist { return true }
            Timing.pause(Timing.brief)
        } while Date() < deadline
        return exists(name) == shouldExist
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: container)
    }

    private func writeBlankPDF(to url: URL) {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)
        document.write(to: url)
    }

    private func makeSeedZip() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = root
        process.arguments = ["-j", "-q", url(zipFile).path, url(alphaFile).path]
        try? process.run()
        process.waitUntilExit()
    }
}
