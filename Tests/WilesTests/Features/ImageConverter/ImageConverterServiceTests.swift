import Foundation
@testable import Wiles

/// Three branches in `ImageConverterService` are intentionally left uncovered (see
/// `ImageConverterCoverageTests.swift`/`ImageConverterCoverageExtraTests.swift` in
/// `Tests/WilesTests/Services/` for the rest of this service's coverage):
/// - `applyCrop`'s `switch preset { case .none: break }` (line ~48): unreachable in practice — the
///   `guard preset != .none else { return cgImage }` a few lines above already returns before the
///   switch is ever entered with `.none`. Swift's exhaustive-switch requirement forces the case to
///   exist even though no live code path reaches it; not a functional bug, just redundant dead code
///   from the enum's exhaustiveness rule. Worth a look if `CropPreset` is ever revisited, but the
///   guard/switch split is intentional and low-risk as-is.
/// - `renderResizedImage`'s `guard let resizedImage = ctx.makeImage() else { throw }`: `CGContext.makeImage()`
///   failing after a successful draw into a validly-allocated context has no known reliable trigger
///   without corrupting CoreGraphics internals.
/// - `writeImage`'s `if !CGImageDestinationFinalize(destination) { throw }`: finalize failing after a
///   successful `CGImageDestinationCreateWithURL` + `AddImage` similarly has no known reliable trigger
///   from valid inputs. Both are defensive error paths around system APIs with no injectable seam.
@MainActor
public struct ImageConverterFeatureTests {
    public static func run() {
        let tempDir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let missingSource = tempDir.appendingPathComponent("missing.png")
        let result = try? ImageConverterService.convertImage(at: missingSource, targetFormat: .jpeg, preset: .original, quality: 0.8)
        report("Feature/ImageConverter", "NEG: Converting nonexistent image throws error", result: result == nil)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
