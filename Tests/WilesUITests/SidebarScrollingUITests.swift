import XCTest

// MARK: - Sidebar Directory-Tree Scrollbar Regression Test

//
// Confirms a real regression: expanding the directory tree deep enough to overflow the sidebar
// used to leave it with NO visible scroll indicator at all (mouse wheel still scrolled the
// content, but nothing on screen showed there was more to scroll). Root-caused to a `LazyVStack`
// nested recursively — once per expanded tree node — inside the sidebar's single ancestor
// `ScrollView`; that pattern is documented as a red flag in the render-focused eval doc.
//
// Run via (NOT `swift test` — see `WilesLaunchUITests.swift`'s header):
//   xcodebuild test -scheme Wiles -destination 'platform=macOS' \
//     -only-testing:WilesUITests/SidebarScrollingUITests
//
// Accessibility identifiers relied on:
//   "Section_DIRECTORY_TREE"   SidebarSectionHeaderView.swift (identifierKey "DIRECTORY_TREE")
//   "Root (/)"                 DirectoryTreeNodeView.swift — root FolderNode.name
//   "Applications"              DirectoryTreeNodeView.swift — child FolderNode.name
//
// Uses `/Applications` (not the user's home folder) so this test doesn't depend on the machine's
// username or personal folder contents — every Mac has enough entries there to overflow a normal
// sidebar height once expanded.
@MainActor
final class SidebarScrollingUITests: XCTestCase {
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        // The UI-testing build runs under its own bundle id (`com.marco.wiles.uitest`, isolated
        // from the developer's real `com.marco.wiles` defaults) — `showDirectoryTree` defaults to
        // `false` there just like a first launch, so the DIRECTORY_TREE section wouldn't even
        // render without seeding this first.
        let seed = Process()
        seed.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        seed.arguments = ["write", "com.marco.wiles.uitest", "wiles_showDirectoryTree", "-bool", "YES"]
        try seed.run()
        seed.waitUntilExit()

        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.activate()
    }

    override func tearDown() async throws {
        app.terminate()
        app = nil
    }

    /// Taps the disclosure chevron at the left edge of a directory-tree row identified by
    /// `nodeName`, rather than the row's own accessibility element — the chevron toggles
    /// expand/collapse (`toggleExpanded()`), while the rest of the row navigates into the folder
    /// instead (`appState.navigateTo`). The chevron itself has no stable identifier (only a
    /// localized accessibility label), so this targets it by position instead.
    private func tapDisclosureChevron(forNodeNamed nodeName: String, timeout: TimeInterval = 5.0) {
        // `.firstMatch`, not the bare subscript: a still-settling tree occasionally exposes more
        // than one accessibility node for the same row mid-animation, which throws "multiple
        // matching elements" on an exact single-element lookup.
        let row = app.buttons.matching(identifier: nodeName).firstMatch
        XCTAssertTrue(
            row.waitForExistence(timeout: timeout),
            "Directory-tree row '\(nodeName)' not found — accessibilityIdentifier changed or row never rendered")
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
    }

    /// Expands the sidebar's directory tree down into `/Applications`, which on any Mac has
    /// enough entries to overflow a normal-height sidebar alongside the other sections
    /// (Favorites/Places/Network) above it — without depending on the current user's home folder.
    func testDirectoryTreeScrollbarAppearsOnceExpandedContentOverflows() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5.0), "Wiles main window did not appear within 5 seconds")

        // The DIRECTORY_TREE section may start collapsed or expanded depending on the persisted
        // preference — only click its header if the root row isn't visible yet.
        if !app.buttons.matching(identifier: "Root (/)").firstMatch.waitForExistence(timeout: 2.0) {
            let treeSection = app.buttons.matching(identifier: "Section_DIRECTORY_TREE").firstMatch
            XCTAssertTrue(
                treeSection.waitForExistence(timeout: 3.0),
                "Sidebar DIRECTORY_TREE section header not found")
            treeSection.click()
        }

        tapDisclosureChevron(forNodeNamed: "Root (/)")
        tapDisclosureChevron(forNodeNamed: "Applications")

        // A visible scroll indicator must appear once /Applications' contents push the sidebar
        // past one screen of content. `waitForExistence` gives the (auto-hiding) scroller time to
        // actually draw after the new rows land.
        let scrollBar = app.scrollBars.firstMatch
        XCTAssertTrue(
            scrollBar.waitForExistence(timeout: 5.0),
            "No scroll indicator appeared in the sidebar after expanding /Applications — " +
                "the directory tree's overflow isn't being reflected by the scroll view")

        // Reported regression: the indicator shows correctly right after expanding, but a real
        // wheel-scroll gesture (not just the content-size change) makes it vanish and get stuck —
        // a later scroll no longer brings it back, unlike the normal auto-hide-then-reappear cycle.
        let sidebarScrollView = app.scrollViews.firstMatch
        sidebarScrollView.scroll(byDeltaX: 0, deltaY: -50)
        Thread.sleep(forTimeInterval: 2.0) // past the overlay scroller's normal auto-hide fade
        sidebarScrollView.scroll(byDeltaX: 0, deltaY: -50)

        XCTAssertTrue(
            scrollBar.waitForExistence(timeout: 5.0),
            "Scroll indicator got stuck hidden after a wheel scroll and did not reappear on a subsequent scroll")
    }
}
