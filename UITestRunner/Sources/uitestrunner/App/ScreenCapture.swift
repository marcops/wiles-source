import CoreGraphics
import Foundation

/// Captures a screen region to a PNG via `/usr/sbin/screencapture -R` (region capture, so an
/// open sheet inside the window bounds is included — unlike `-l<windowID>`, which grabs the
/// parent window without its sheet). The region is the Wiles window's AX frame.
enum ScreenCapture {
    @discardableResult
    static func capture(region rect: CGRect, to file: URL) -> Bool {
        guard rect.width > 1, rect.height > 1 else { return false }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let region = "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-o", "-t", "png", "-R", region, file.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0 && FileManager.default.fileExists(atPath: file.path)
    }
}
