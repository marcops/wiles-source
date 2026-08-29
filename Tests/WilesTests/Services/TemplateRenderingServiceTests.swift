import XCTest
@testable import Wiles

/// Standalone dedicated suite for `TemplateRenderingService` — follows the standalone-XCTestCase
/// precedent (see `DefaultFolderHandlerServiceTests`) since this is a new source file with no prior
/// coverage and needs no wiring elsewhere.
final class TemplateRenderingServiceTests: XCTestCase {
    func testRenderSubstitutesAllPlaceholders() throws {
        let rendered = try XCTUnwrap(TemplateRenderingService.render(
            resource: "SharedFolder",
            replacements: ["FOLDER_NAME": "Downloads", "ITEMS": "<li>a.txt</li>"]))

        XCTAssertTrue(rendered.contains("Downloads"))
        XCTAssertTrue(rendered.contains("<li>a.txt</li>"))
        XCTAssertFalse(rendered.contains("{{FOLDER_NAME}}"))
        XCTAssertFalse(rendered.contains("{{ITEMS}}"))
    }

    func testRenderWithMissingResourceReturnsNil() {
        let rendered = TemplateRenderingService.render(
            resource: "ThisTemplateDoesNotExist",
            replacements: [:])
        XCTAssertNil(rendered)
    }

    func testRenderLeavesUnknownPlaceholdersUntouched() throws {
        let rendered = try XCTUnwrap(TemplateRenderingService.render(
            resource: "SharedFolder",
            replacements: ["FOLDER_NAME": "Docs"]))
        // ITEMS was never supplied, so its placeholder must survive unreplaced rather than
        // silently vanishing — a missing replacement is a caller bug that should stay visible.
        XCTAssertTrue(rendered.contains("{{ITEMS}}"))
    }

    /// A replacement value that itself contains a `{{...}}` token must not be re-scanned — a single
    /// pass means an injected placeholder in a dynamic value (e.g. a filename shared over the LAN)
    /// stays literal instead of pulling in another key's substitution.
    func testReplacementValueContainingAnotherPlaceholderIsNotReExpanded() {
        let rendered = TemplateRenderingService.substitute(
            in: "name: {{NAME}} / secret: {{SECRET}}",
            replacements: ["NAME": "evil {{SECRET}}", "SECRET": "s3cr3t"])
        XCTAssertEqual(rendered, "name: evil {{SECRET}} / secret: s3cr3t")
    }

    /// Covers the `catch` branch: the resource exists (so the `url(forResource:)` guard passes) but
    /// isn't valid UTF-8 text, so `String(contentsOf:encoding:)` throws. AppIcon.png is a real bundled
    /// resource that's guaranteed not to decode as UTF-8.
    func testRenderWithNonUTF8ResourceReturnsNilViaCatchBranch() {
        let rendered = TemplateRenderingService.render(resource: "AppIcon", extension: "png", replacements: [:])
        XCTAssertNil(rendered)
    }
}
