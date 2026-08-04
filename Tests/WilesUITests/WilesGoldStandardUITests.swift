import XCTest

// MARK: - Robot (Page Object) Pattern for Wiles macOS UI Tests
@MainActor
final class WilesAppRobot {
    private var app: XCUIApplication

    init(_ app: XCUIApplication) {
        self.app = app
    }

    @discardableResult
    func launch() -> Self {
        let appURL = URL(fileURLWithPath: "Wiles.app")
        app = FileManager.default.fileExists(atPath: appURL.path) ? XCUIApplication(url: appURL) : XCUIApplication(bundleIdentifier: "com.marco.wiles")
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return self
    }

    @discardableResult
    func navigate(to path: String) -> Self {
        app.typeKey("l", modifierFlags: .command)
        let pathField = app.textFields.firstMatch
        XCTAssertTrue(pathField.waitForExistence(timeout: 2.0), "Path input field did not appear")
        pathField.click()
        pathField.typeText("\(path)\r")
        return self
    }

    @discardableResult
    func search(for query: String) -> Self {
        app.typeKey("f", modifierFlags: .command)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2.0), "Search bar did not appear")
        searchField.typeText(query)
        return self
    }

    @discardableResult
    func verifyItemExists(_ name: String, file: StaticString = #file, line: UInt = #line) -> Self {
        let element = app.staticTexts[name]
        XCTAssertTrue(element.waitForExistence(timeout: 3.0), "Item '\(name)' should exist", file: file, line: line)
        return self
    }

    @discardableResult
    func verifyItemDoesNotExist(_ name: String, file: StaticString = #file, line: UInt = #line) -> Self {
        let element = app.staticTexts[name]
        XCTAssertFalse(element.exists, "Item '\(name)' should NOT exist", file: file, line: line)
        return self
    }

    @discardableResult
    func rightClickItem(_ name: String) -> Self {
        let element = app.staticTexts[name]
        XCTAssertTrue(element.waitForExistence(timeout: 2.0))
        element.rightClick()
        return self
    }

    @discardableResult
    func verifyContextMenuVisible(file: StaticString = #file, line: UInt = #line) -> Self {
        let menu = app.menus.firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 2.0), "Context menu was not displayed", file: file, line: line)
        return self
    }
}

// MARK: - Gold Standard Test Case
@MainActor
final class WilesGoldStandardUITests: XCTestCase {

    // swiftlint:disable:next implicitly_unwrapped_optional - standard XCTest lifecycle property, set in setUp/tearDown
    private var app: XCUIApplication!
    private let testPath = (NSTemporaryDirectory() as NSString).appendingPathComponent("WilesGoldStandardTests")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()

        // Setup clean mock file system state
        let fm = FileManager.default
        if fm.fileExists(atPath: testPath) {
            try fm.removeItem(atPath: testPath)
        }
        try fm.createDirectory(atPath: testPath, withIntermediateDirectories: true)
        try "Target".write(toFile: "\(testPath)/TargetFile.txt", atomically: true, encoding: .utf8)
        try "Decoy".write(toFile: "\(testPath)/DecoyFile.txt", atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws {
        // Capture screenshot on failure
        if let run = self.testRun, !run.hasSucceeded {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Failure_Screenshot"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        app = nil
        try? FileManager.default.removeItem(atPath: testPath)
    }

    func testSearchFilteringGoldStandard() throws {
        // Using the Robot pattern for declarative, clean, and self-documenting tests
        WilesAppRobot(app)
            .launch()
            .navigate(to: testPath)
            .verifyItemExists("TargetFile.txt")
            .verifyItemExists("DecoyFile.txt")
            .search(for: "Target")
            .verifyItemExists("TargetFile.txt")
            .verifyItemDoesNotExist("DecoyFile.txt")
    }

    func testContextMenuOnSearchResultGoldStandard() throws {
        WilesAppRobot(app)
            .launch()
            .navigate(to: testPath)
            .search(for: "Target")
            .rightClickItem("TargetFile.txt")
            .verifyContextMenuVisible()
    }
}
