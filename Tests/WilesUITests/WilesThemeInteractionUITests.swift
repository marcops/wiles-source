import XCTest

@MainActor
final class WilesThemeInteractionUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
    private var app: XCUIApplication!
    private let opPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("WilesThemeInteractionUITests")

    override func setUpWithError() throws {
        continueAfterFailure = false

        let fm = FileManager.default
        if fm.fileExists(atPath: opPath) {
            try fm.removeItem(atPath: opPath)
        }
        try fm.createDirectory(atPath: opPath, withIntermediateDirectories: true)

        let appURL = URL(fileURLWithPath: "Wiles.app")
        app = FileManager.default.fileExists(atPath: appURL.path) ? XCUIApplication(url: appURL) : XCUIApplication(bundleIdentifier: "com.marco.wiles")
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let window = app.windows.firstMatch
        if window.waitForExistence(timeout: 5.0) {
            window.click()
        }
    }

    override func tearDownWithError() throws {
        if let run = self.testRun, !run.hasSucceeded {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure_Screenshot_ThemeInteraction"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        app = nil
        try? FileManager.default.removeItem(atPath: opPath)
    }

    /// Navigates the app to `opPath` via the Cmd+L "go to path" field, mirroring the
    /// pattern used by WilesFileOperationsUITests.
    private func navigateToOpPath() {
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0), "Path text field should appear after Cmd+L")
        pathField.click()
        pathField.typeText("\(opPath)\r")
    }

    /// Hovering a file-list row is driven by `HoverItemHighlightModifier` (onHover toggles
    /// `isHovered`, which changes background/scale purely visually — there is no accessibility
    /// value/label exposed for hover state). This test can't observe the highlight itself via
    /// the accessibility tree, so it verifies the row survives a real hover event: it must still
    /// exist, be hittable, and remain clickable/selectable afterward — i.e. the hover modifier
    /// doesn't break the row's interaction path.
    func testFileListRowSurvivesHoverAndRemainsInteractive() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: "\(opPath)/HoverRow", withIntermediateDirectories: true)

        navigateToOpPath()

        let row = app.staticTexts["HoverRow"]
        XCTAssertTrue(row.waitForExistence(timeout: 3.0), "HoverRow should appear in the file list")
        XCTAssertTrue(row.isHittable, "HoverRow should be hittable before hover")

        row.hover()

        XCTAssertTrue(row.exists, "HoverRow should still exist immediately after hover")
        XCTAssertTrue(row.isHittable, "HoverRow should remain hittable after hover")

        // Move the hover off the row to a neutral area, then confirm the row is still
        // present and clickable (i.e. hover in/out didn't corrupt the row's hit testing
        // or remove it from the tree).
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)).hover()
        XCTAssertTrue(row.exists, "HoverRow should still exist after hover moves away")

        row.click()
        XCTAssertTrue(row.exists, "HoverRow should still exist and be clickable after the hover/click sequence")
    }

    /// SpringLoadedFolderModifier registers an onDrop(isTargeted:) that, once a drag has
    /// hovered a directory row for 750ms, navigates into that folder before the drop is even
    /// released. This drives a real drag: hold over the folder row past the spring-load delay,
    /// then release, and confirm the breadcrumb path bar reflects that we navigated into the
    /// target folder.
    func testDraggingFileOverFolderRowSpringLoadsNavigation() throws {
        let fm = FileManager.default
        try fm.createDirectory(atPath: "\(opPath)/SpringFolder", withIntermediateDirectories: true)
        fm.createFile(atPath: "\(opPath)/DragMe.txt", contents: Data("hello".utf8))

        navigateToOpPath()

        let sourceRow = app.staticTexts["DragMe.txt"]
        let targetRow = app.staticTexts["SpringFolder"]
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 3.0), "DragMe.txt should appear in the file list")
        XCTAssertTrue(targetRow.waitForExistence(timeout: 3.0), "SpringFolder should appear in the file list")

        let sourceCoordinate = sourceRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let targetCoordinate = targetRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // Hold over the target well past the 750ms spring-load delay before releasing, so the
        // navigateTo(folderURL) inside the spring task has a chance to fire before drop.
        sourceCoordinate.press(forDuration: 0.2, thenDragTo: targetCoordinate, withVelocity: .default, thenHoldForDuration: 1.2)

        // The onDrop handler cancels the spring task and moves the file into SpringFolder on
        // release, so after the drag+drop, DragMe.txt should no longer be listed at opPath's
        // top level (it either moved into SpringFolder directly, or we spring-navigated into
        // SpringFolder and the list now shows that folder's contents instead).
        let stillAtTopLevel = sourceRow.waitForExistence(timeout: 1.0)
        XCTAssertFalse(stillAtTopLevel, "DragMe.txt should no longer be listed at the top level after being dropped onto SpringFolder")

        // Verify the breadcrumb path bar reflects a folder named SpringFolder somewhere in the
        // ancestry, which is only true if the spring-loaded navigation (or the post-drop
        // location) actually took us into that folder.
        let breadcrumbTarget = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", "SpringFolder")).firstMatch
        XCTAssertTrue(breadcrumbTarget.waitForExistence(timeout: 3.0), "Breadcrumb should show SpringFolder after the spring-loaded drag navigation")
    }

    /// Negative case: dragging a file over another plain file (non-directory) row must never
    /// trigger navigation, since SpringLoadedFolderModifier gates the spring timer behind
    /// `isDirectory`. This exercises the same drag path as the folder case but asserts nothing
    /// changes in the path bar.
    func testDraggingFileOverNonFolderRowDoesNotNavigate() throws {
        let fm = FileManager.default
        fm.createFile(atPath: "\(opPath)/SourceFile.txt", contents: Data("a".utf8))
        fm.createFile(atPath: "\(opPath)/TargetFile.txt", contents: Data("b".utf8))

        navigateToOpPath()

        let sourceRow = app.staticTexts["SourceFile.txt"]
        let targetRow = app.staticTexts["TargetFile.txt"]
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 3.0), "SourceFile.txt should appear in the file list")
        XCTAssertTrue(targetRow.waitForExistence(timeout: 3.0), "TargetFile.txt should appear in the file list")

        let sourceCoordinate = sourceRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let targetCoordinate = targetRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        sourceCoordinate.press(forDuration: 0.2, thenDragTo: targetCoordinate, withVelocity: .default, thenHoldForDuration: 1.2)

        // Both files should still be visible in the same directory listing: dropping a file on
        // a non-directory row is a no-op (isDirectory guard returns false before handleDrop),
        // and there must be no spring-loaded navigation away from opPath.
        XCTAssertTrue(sourceRow.waitForExistence(timeout: 2.0), "SourceFile.txt should still be listed at opPath after dropping on a non-folder row")
        XCTAssertTrue(app.staticTexts["TargetFile.txt"].waitForExistence(timeout: 2.0), "TargetFile.txt should still be listed at opPath after dropping on a non-folder row")
    }
}
