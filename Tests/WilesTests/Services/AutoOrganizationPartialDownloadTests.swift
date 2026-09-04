import Foundation
@testable import Wiles

/// MM-209: browser/torrent partial-download files are skipped by auto-org regardless of any rule
/// match. Split out of `AutoOrganizationTests.swift` to stay under `file_length`.
@MainActor
extension AutoOrganizationTests {
    static func runPartialDownloadChecks(service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        testInProgressDownloadExtensionCheck()
        await testInProgressDownloadFilesAreNeverMoved(service: service, inputDir: inputDir, targetDir: targetDir)
    }

    /// The pure denylist decision — the closed set of browser/torrent partial-download extensions.
    private static func testInProgressDownloadExtensionCheck() {
        let partials = [
            "a.pdf.crdownload",
            "b.zip.download",
            "c.iso.part",
            "d.dmg.partial",
            "e.mp4.opdownload",
            "movie.!ut",
            "linux.aria2"
        ]
        let normal = ["report.pdf", "photo.jpeg", "archive.zip", "notes.download.txt", "x"]
        let allPartialsRejected = partials.allSatisfy {
            AutoOrganizationService.isInProgressDownload(URL(fileURLWithPath: "/tmp/\($0)"))
        }
        let noNormalRejected = normal.allSatisfy {
            !AutoOrganizationService.isInProgressDownload(URL(fileURLWithPath: "/tmp/\($0)"))
        }
        TestReporter.report(
            "AutoOrganization", "POS: every known in-progress-download extension is recognized",
            result: allPartialsRejected)
        TestReporter.report(
            "AutoOrganization", "NEG: a normal file (incl. one merely named *.download.txt) is not treated as a partial download",
            result: noNormalRejected)
    }

    /// A `nameContains` rule can match a browser's temp download name (`report.pdf.crdownload`), and
    /// the size+mtime stability window is beatable by a download that pauses through it — so a
    /// cross-volume auto-move would strand a truncated file. Partial-download extensions are skipped
    /// deterministically, before the stability check.
    private static func testInProgressDownloadFilesAreNeverMoved(
        service: AutoOrganizationService, inputDir: URL, targetDir: URL) async {
        let partial = inputDir.appendingPathComponent("report.pdf.crdownload")
        let partial2 = inputDir.appendingPathComponent("dataset.part")
        try? "half".write(to: partial, atomically: true, encoding: .utf8)
        try? "half".write(to: partial2, atomically: true, encoding: .utf8)
        let realMatch = inputDir.appendingPathComponent("report-final.pdf")
        try? "PDF".write(to: realMatch, atomically: true, encoding: .utf8)

        let containsRule = AutoOrganizationRule(
            sourceURL: inputDir, destinationURL: targetDir,
            conditionType: .nameContains, conditionValue: "report", isEnabled: true)
        service.rules = [containsRule]

        service.processFolder(inputDir)
        let movedReal = targetDir.appendingPathComponent("report-final.pdf")
        await waitUntil { FileManager.default.fileExists(atPath: movedReal.path) }

        TestReporter.report(
            "AutoOrganization",
            "NEG: a *.crdownload / *.part file matching a nameContains rule is never auto-moved",
            result: FileManager.default.fileExists(atPath: partial.path)
                && FileManager.default.fileExists(atPath: partial2.path)
                && !FileManager.default.fileExists(atPath: targetDir.appendingPathComponent("report.pdf.crdownload").path))
        TestReporter.report(
            "AutoOrganization", "POS: a real matching file alongside the partial downloads is still moved",
            result: FileManager.default.fileExists(atPath: movedReal.path))

        try? FileManager.default.removeItem(at: partial)
        try? FileManager.default.removeItem(at: partial2)
    }
}
