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

    @discardableResult
    func mainWindow(timeout: TimeInterval = 15) throws -> AXElement {
        if let cachedWindow, !cachedWindow.frame.isEmpty { return cachedWindow }
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let window = app.windows.first(where: { $0.subrole == "AXStandardWindow" || !$0.frame.isEmpty }) {
                cachedWindow = window
                return window
            }
            Thread.sleep(forTimeInterval: 0.3)
        } while Date() < deadline
        throw RunnerError.mainWindowNeverAppeared
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
            Thread.sleep(forTimeInterval: 0.4)
            return true
        }
        let rect = element.frame
        guard !rect.isEmpty else {
            reporter.fail("\(label): no frame for right-click")
            return false
        }
        Mouse.click(center: rect, rightButton: true, pid: pid)
        Thread.sleep(forTimeInterval: 0.4)
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
        Thread.sleep(forTimeInterval: 0.35)
        let itemMatch = AXMatch(role: "AXMenuItem", textContains: fragment)
        guard let item = barItem.waitForDescendant(where: itemMatch, timeout: 3) else {
            key(Keyboard.escape)
            reporter.fail("\(label): item containing '\(fragment)' not under '\(menuTitle)'")
            return false
        }
        let pressed = item.perform(AXAction.pick) || item.press()
        Thread.sleep(forTimeInterval: 0.3)
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
        Thread.sleep(forTimeInterval: 0.35)
        let found = barItem.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment)) != nil
        key(Keyboard.escape)
        Thread.sleep(forTimeInterval: 0.15)
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
        Thread.sleep(forTimeInterval: 0.3)
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
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return sheet() != nil
    }

    func dismissSheet() {
        for _ in 0 ..< 3 where sheet() != nil {
            key(Keyboard.escape)
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    // MARK: - Navigation

    /// Points Wiles at the seeded temp directory via the ⌘L "Go to Folder" path field.
    func navigateToWorkspace() {
        chord("l", .command)
        Thread.sleep(forTimeInterval: 0.4)
        guard let field = find(AXMatch(identifier: "PathBarTextField"), timeout: 4) else {
            reporter.fail("navigate: PathBarTextField not found after ⌘L")
            return
        }
        tapElement(field)
        Thread.sleep(forTimeInterval: 0.2)
        chord("a", .command)
        type(workspace.root.path)
        key(Keyboard.returnKey)
        _ = fileRow(workspace.alphaFile, timeout: 8)
    }

    func fileRow(_ name: String, timeout: TimeInterval = 5) -> AXElement? {
        find(AXMatch(textEquals: name), timeout: timeout)
    }
}
