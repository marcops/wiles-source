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
        menuPick(menuTitle, path: [fragment], label)
    }

    /// Walks a menu-bar path, opening each submenu before looking inside it (AX doesn't populate a
    /// submenu's items until it is actually opened). Every `path` entry is a case-insensitive
    /// substring of the item's title.
    @discardableResult
    func menuPick(_ menuTitle: String, path: [String], _ label: String) -> Bool {
        guard let container = openMenu(menuTitle, path: Array(path.dropLast()), label) else { return false }
        guard let leafFragment = path.last else { return false }
        guard let item = container.waitForDescendant(
            where: AXMatch(role: "AXMenuItem", textContains: leafFragment), timeout: 3) else {
            key(Keyboard.escape)
            reporter.fail("\(label): '\(leafFragment)' not found under \(menuTitle) ▸ \(path.joined(separator: " ▸ "))")
            return false
        }
        let pressed = pressMenuItem(item)
        Timing.pause(Timing.settle)
        return pressed
    }

    /// Opens `menuTitle` then each nested submenu named by `path`, returning the innermost open
    /// menu container (or `nil` on failure, with the menu dismissed).
    private func openMenu(_ menuTitle: String, path: [String], _ label: String) -> AXElement? {
        guard let barItem = app.menuBar?.children.first(where: { $0.title == menuTitle }) else {
            reporter.fail("\(label): menu '\(menuTitle)' not in menu bar")
            return nil
        }
        barItem.press()
        Timing.pause(Timing.settle)
        var container = barItem
        for fragment in path {
            guard let submenuItem = container.waitForDescendant(
                where: AXMatch(role: "AXMenuItem", textContains: fragment), timeout: 3) else {
                key(Keyboard.escape)
                reporter.fail("\(label): submenu '\(fragment)' not found under '\(menuTitle)'")
                return nil
            }
            submenuItem.press()
            Timing.pause(Timing.settle)
            container = submenuItem
        }
        return container
    }

    private func pressMenuItem(_ item: AXElement) -> Bool {
        if item.perform(AXAction.pick) { return true }
        if item.press() { return true }
        let rect = item.frame
        guard !rect.isEmpty else { return false }
        Mouse.click(center: rect, pid: pid)
        return true
    }

    func closeAnyMenu() {
        key(Keyboard.escape)
        Timing.pause(Timing.brief)
    }

    func menuBarTitles() -> [String] {
        (app.menuBar?.children ?? []).map(\.title).filter { !$0.isEmpty }
    }

    /// Whether `menuTitle ▸ path` currently contains an item with `fragment` (menu opened, then
    /// dismissed). Used to assert a toggle flipped its menu label.
    func menuHasItem(_ menuTitle: String, path: [String] = [], containing fragment: String) -> Bool {
        guard let container = openMenu(menuTitle, path: path, "menuHasItem") else { return false }
        let found = container.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment)) != nil
        key(Keyboard.escape)
        Timing.pause(Timing.brief)
        return found
    }

    // MARK: - Context menu

    /// Right-clicks a file row and picks the context-menu item whose text contains `fragment`.
    @discardableResult
    func openContextItem(onFileRow name: String, containing fragment: String, _ label: String) -> Bool {
        guard rightClick(AXMatch(textEquals: name), "'\(name)' row (for context menu)", timeout: 5) else { return false }
        Timing.pause(Timing.settle)
        return pickContextItem(containing: fragment, label)
    }

    @discardableResult
    func pickContextItem(containing fragment: String, _ label: String) -> Bool {
        let match = AXMatch(role: "AXMenuItem", textContains: fragment)
        guard let item = app.waitForDescendant(where: match, timeout: 3) else {
            key(Keyboard.escape)
            reporter.fail("\(label): context item '\(fragment)' not found")
            return false
        }
        let pressed = pressMenuItem(item)
        Timing.pause(Timing.settle)
        return pressed
    }

    /// Presses the button whose text contains `fragment` in a confirmation alert, if one is up.
    @discardableResult
    func confirmDialog(pressing fragment: String, timeout: TimeInterval = 3) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let dialog = app.firstDescendant(where: AXMatch(role: "AXSheet"))
                ?? app.firstDescendant(where: AXMatch(role: "AXDialog")),
                let button = dialog.firstDescendant(where: AXMatch(role: "AXButton", textContains: fragment)) {
                tapElement(button)
                Timing.pause(Timing.animation)
                return true
            }
            Timing.pause(Timing.poll)
        } while Date() < deadline
        return false
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

    private static let dismissButtonLabels = ["cancel", "close", "done", "ok"]

    @discardableResult
    func dismissSheet() -> Bool {
        for attempt in 0 ..< 4 {
            guard let sheet = sheet() else { return true }
            if attempt < 2 {
                key(Keyboard.escape)
            } else if let button = dismissButton(in: sheet) {
                tapElement(button)
            } else {
                key(Keyboard.escape)
            }
            Timing.pause(Timing.animation)
        }
        return sheet() == nil
    }

    private func dismissButton(in sheet: AXElement) -> AXElement? {
        sheet.firstDescendant(where: AXMatch(role: "AXButton", predicate: { element in
            Self.dismissButtonLabels.contains { element.title.lowercased() == $0 || element.descriptionText.lowercased() == $0 }
        }))
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

    /// Mouse-clicks a file row, optionally with modifiers held (⌘-click to extend a selection).
    @discardableResult
    func clickRow(_ name: String, modifiers: Keyboard.Modifiers = [], timeout: TimeInterval = 5) -> Bool {
        guard let row = fileRow(name, timeout: timeout) else {
            reporter.fail("row '\(name)': not found")
            return false
        }
        let rect = row.frame
        guard !rect.isEmpty else {
            reporter.fail("row '\(name)': no frame")
            return false
        }
        Mouse.click(center: rect, modifiers: modifiers, pid: pid)
        Timing.pause(Timing.brief)
        return true
    }

    // MARK: - Settings

    /// Opens the Settings sheet (if not already open) and selects `tab` by its localized label.
    @discardableResult
    func openSettings(tab: String) -> Bool {
        if sheet() == nil {
            guard menuPick("Wiles", itemContains: "Settings", "Wiles ▸ Settings") else { return false }
            guard waitForSheet() else {
                reporter.fail("Settings sheet did not open")
                return false
            }
        }
        guard let tabElement = sheet()?.firstDescendant(where: AXMatch(textEquals: tab)) else {
            reporter.fail("Settings tab '\(tab)' not found")
            return false
        }
        tapElement(tabElement)
        Timing.pause(Timing.settle)
        return true
    }

    /// Sets the Appearance-tab Theme control to `option`, coping with either rendering SwiftUI's
    /// `Picker` can take here — a pop-up menu button or an inline set of radio buttons.
    @discardableResult
    func selectThemeOption(_ option: String) -> Bool {
        guard let sheet = sheet() else { return false }

        if let radio = sheet.firstDescendant(where: AXMatch(role: "AXRadioButton", textContains: option)) {
            return tapElement(radio)
        }
        guard let popup = sheet.firstDescendant(where: AXMatch(role: "AXPopUpButton")) else { return false }
        let rect = popup.frame
        if !rect.isEmpty {
            Mouse.click(center: rect, pid: pid)
        } else {
            popup.press()
        }
        Timing.pause(Timing.settle)
        if let item = app.waitForDescendant(where: AXMatch(role: "AXMenuItem", textContains: option), timeout: 3) {
            return pressMenuItem(item)
        }
        closeAnyMenu()
        return false
    }
}
