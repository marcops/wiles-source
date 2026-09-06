import CoreGraphics
import Foundation

/// High-level driving surface over the AX layer: resolve the main window, find elements, click,
/// type, work the menu bar and sheets. Feature steps talk only to this, never to `AXElement`
/// directly, so an interaction quirk is fixed in one place.
final class WilesDriver {
    let process: WilesProcess
    let workspace: TempWorkspace
    let reporter: Reporter

    let app: AXElement
    private var cachedWindow: AXElement?

    var pid: pid_t { process.pid }

    init(process: WilesProcess, workspace: TempWorkspace, reporter: Reporter) {
        self.process = process
        self.workspace = workspace
        self.reporter = reporter
        app = AXElement.application(pid: process.pid)
    }

    // MARK: - Window

    /// A window this small is Wiles mid-construction — the SwiftUI hierarchy isn't laid out yet, so
    /// every sidebar/footer query against it would spuriously miss.
    private static let minReadyWindowSize = CGSize(width: 400, height: 200)

    @discardableResult
    func mainWindow(timeout: TimeInterval = 20) throws -> AXElement {
        if let cachedWindow, isReady(cachedWindow) { return cachedWindow }
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let window = app.windows.first(where: { $0.subrole == "AXStandardWindow" }) {
                cachedWindow = window
                if isReady(window) { return window }
            }
            Timing.pause(Timing.settle)
        } while Date() < deadline
        if let cachedWindow { return cachedWindow }
        throw RunnerError.mainWindowNeverAppeared
    }

    private func isReady(_ window: AXElement) -> Bool {
        let size = window.frame.size
        return size.width >= Self.minReadyWindowSize.width && size.height >= Self.minReadyWindowSize.height
    }

    private var window: AXElement { (try? mainWindow()) ?? app }

    // MARK: - Find

    func find(_ match: AXMatch, timeout: TimeInterval = 5) -> AXElement? {
        window.waitForDescendant(where: match, timeout: timeout)
    }

    /// Search the whole app tree (menus and sheets are siblings of the window, not descendants).
    func findAnywhere(_ match: AXMatch, timeout: TimeInterval = 5) -> AXElement? {
        app.waitForDescendant(where: match, timeout: timeout)
    }

    // MARK: - Click

    @discardableResult
    func tapElement(_ element: AXElement) -> Bool {
        if element.actionNames.contains(AXAction.press), element.press() { return true }
        let rect = element.frame
        guard !rect.isEmpty else { return false }
        Mouse.click(center: rect, pid: pid)
        return true
    }

    @discardableResult
    func tap(_ match: AXMatch, _ label: String, timeout: TimeInterval = 5) -> Bool {
        guard let element = find(match, timeout: timeout) else {
            reporter.fail("\(label): not found")
            return false
        }
        guard tapElement(element) else {
            reporter.fail("\(label): found but not clickable")
            return false
        }
        return true
    }

    @discardableResult
    func rightClick(_ match: AXMatch, _ label: String, timeout: TimeInterval = 5) -> Bool {
        guard let element = find(match, timeout: timeout) else {
            reporter.fail("\(label): not found (for context menu)")
            return false
        }
        if element.actionNames.contains(AXAction.showMenu), element.perform(AXAction.showMenu) {
            Timing.pause(Timing.settle)
            return true
        }
        let rect = element.frame
        guard !rect.isEmpty else {
            reporter.fail("\(label): no frame for right-click")
            return false
        }
        Mouse.click(center: rect, rightButton: true, pid: pid)
        Timing.pause(Timing.settle)
        return true
    }

    // MARK: - Keyboard

    func key(_ key: Keyboard.Key, _ modifiers: Keyboard.Modifiers = []) {
        Keyboard.press(key, modifiers: modifiers, pid: pid)
    }

    func chord(_ character: Character, _ modifiers: Keyboard.Modifiers) {
        Keyboard.press(character: character, modifiers: modifiers, pid: pid)
    }

    func type(_ text: String) {
        Keyboard.type(text, pid: pid)
    }

    /// Replaces a text field's contents: AX-focus + click for focus, ⌘A to select any existing
    /// text, then synthesised keystrokes (SwiftUI `TextField` ignores a bare AX value set).
    func replaceText(in field: AXElement, with text: String) {
        field.focus()
        tapElement(field)
        Timing.pause(Timing.brief)
        chord("a", .command)
        Timing.pause(Timing.brief)
        key(Keyboard.delete)
        Timing.pause(Timing.brief)
        type(text)
        Timing.pause(Timing.brief)
    }

    // MARK: - Menu bar

    @discardableResult
    func menuPick(_ menuTitle: String, itemContains fragment: String, _ label: String) -> Bool {
        guard let menuBar = app.menuBar else {
            reporter.fail("\(label): app has no menu bar")
            return false
        }
        guard let barItem = menuBar.children.first(where: { $0.title == menuTitle }) else {
            reporter.fail("\(label): menu '\(menuTitle)' not in menu bar")
            return false
        }
        barItem.press()
        Timing.pause(Timing.settle)
        let itemMatch = AXMatch(role: "AXMenuItem", textContains: fragment)
        guard let item = barItem.waitForDescendant(where: itemMatch, timeout: 3) else {
            key(Keyboard.escape)
            reporter.fail("\(label): item containing '\(fragment)' not under '\(menuTitle)'")
            return false
        }
        let pressed = item.perform(AXAction.pick) || item.press()
        Timing.pause(Timing.settle)
        return pressed
    }

    /// Whether `menuTitle` currently contains an item whose text has `fragment` (menu is opened
    /// then dismissed). Used to assert a toggle flipped its menu label.
    func menuHasItem(_ menuTitle: String, containing fragment: String) -> Bool {
        guard
            let menuBar = app.menuBar,
            let barItem = menuBar.children.first(where: { $0.title == menuTitle })
        else { return false }
        barItem.press()
        Timing.pause(Timing.settle)
        let found = barItem.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment)) != nil
        key(Keyboard.escape)
        Timing.pause(Timing.brief)
        return found
    }

    // MARK: - Context menu

    @discardableResult
    func pickContextItem(containing fragment: String, _ label: String) -> Bool {
        let match = AXMatch(role: "AXMenuItem", textContains: fragment)
        guard let item = app.waitForDescendant(where: match, timeout: 3) else {
            key(Keyboard.escape)
            reporter.fail("\(label): context item '\(fragment)' not found")
            return false
        }
        let pressed = item.perform(AXAction.pick) || item.press()
        Timing.pause(Timing.settle)
        return pressed
    }

    // MARK: - Sheets

    func sheet() -> AXElement? {
        app.firstDescendant(where: AXMatch(role: "AXSheet"))
    }

    func waitForSheet(timeout: TimeInterval = 6) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if sheet() != nil { return true }
            Timing.pause(Timing.brief)
        } while Date() < deadline
        return sheet() != nil
    }

    func dismissSheet() {
        for _ in 0 ..< 3 where sheet() != nil {
            key(Keyboard.escape)
            Timing.pause(Timing.settle)
        }
    }

    // MARK: - Navigation

    /// Ensures Wiles is showing the seeded temp directory. It normally already is (the launch
    /// defaults domain was seeded with `wiles_lastOpenedFolder`); this is the ⌘L fallback.
    @discardableResult
    func navigateToWorkspace() -> Bool {
        if fileRow(workspace.alphaFile, timeout: 3) != nil { return true }
        menuPick("Go", itemContains: "Go to Folder", "Go ▸ Go to Folder")
        Timing.pause(Timing.settle)
        guard let field = find(AXMatch(identifier: "PathBarTextField"), timeout: 4) else {
            reporter.fail("navigate: PathBarTextField not found after Go to Folder")
            return false
        }
        replaceText(in: field, with: workspace.root.path)
        key(Keyboard.returnKey)
        return fileRow(workspace.alphaFile, timeout: 6) != nil
    }

    func fileRow(_ name: String, timeout: TimeInterval = 5) -> AXElement? {
        find(AXMatch(textEquals: name), timeout: timeout)
    }
}
