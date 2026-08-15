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
}
