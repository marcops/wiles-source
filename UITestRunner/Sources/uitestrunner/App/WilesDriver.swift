import CoreGraphics
import Foundation

/// High-level driving surface over the AX layer: resolve the main window, find elements, click,
/// type, work the menu bar and sheets. Feature steps talk only to this, never to `AXElement`
/// directly, so an interaction quirk is fixed in one place.
final class WilesDriver {
    let process: WilesProcess
    let workspace: TempWorkspace
    let reporter: Reporter

    private(set) var app: AXElement
    private var cachedWindow: AXElement?

    var pid: pid_t { process.pid }

    init(process: WilesProcess, workspace: TempWorkspace, reporter: Reporter) {
        self.process = process
        self.workspace = workspace
        self.reporter = reporter
        app = AXElement.application(pid: process.pid)
    }

    /// Re-bind to the current process pid after a relaunch, and drop the stale window cache.
    func rebindToRelaunchedApp() {
        app = AXElement.application(pid: process.pid)
        cachedWindow = nil
    }

    // Clean slate between steps / suites: no relaunch, just dismiss anything stuck and go home.
    func recover() {
        closeAnyMenu()
        for _ in 0 ..< 3 where sheet() != nil { dismissSheet() }
        deactivateSearch()
        cachedWindow = nil
        process.activate()
        Timing.pause(Timing.brief)
        navigateToWorkspace()
    }

    func resetForNextSuite() { recover() }

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

    /// Forget the cached main window — call after a relaunch, or after ⌘N/⌘W, so the next
    /// `mainWindow()` re-resolves.
    func resetWindowCache() {
        cachedWindow = nil
    }

    var standardWindowCount: Int {
        app.windows.filter { $0.subrole == "AXStandardWindow" }.count
    }

    private var window: AXElement { (try? mainWindow()) ?? app }

    // MARK: - Find

    func find(_ match: AXMatch, timeout: TimeInterval = 3) -> AXElement? {
        window.waitForDescendant(where: match, timeout: timeout)
    }

    /// Search the whole app tree (menus and sheets are siblings of the window, not descendants).
    func findAnywhere(_ match: AXMatch, timeout: TimeInterval = 5) -> AXElement? {
        app.waitForDescendant(where: match, timeout: timeout)
    }

    @discardableResult
    func activateSearch() -> AXElement? {
        let fieldMatch = AXMatch(identifier: "SearchTextField")
        if let field = find(fieldMatch, timeout: 1) { return field }
        process.activate()
        let attempts: [() -> Void] = [
            { _ = self.tap(AXMatch(identifier: "magnifyingglass"), "search button", timeout: 3) },
            { self.menuPick("Edit", itemContains: "Find", "Edit ▸ Find") },
            { self.chord("f", .command) },
        ]
        for attempt in attempts {
            attempt()
            Timing.pause(Timing.animation)
            if let field = find(fieldMatch, timeout: 3) { return field }
        }
        return find(fieldMatch, timeout: 3)
    }

    func deactivateSearch() {
        var tries = 0
        while find(AXMatch(identifier: "SearchTextField"), timeout: 1) != nil, tries < 3 {
            key(Keyboard.escape)
            Timing.pause(Timing.brief)
            tries += 1
        }
    }

    // Types `query` and nudges the field (extra char + delete) so SwiftUI's binding + the search
    // debounce actually fire, then waits out the debounce. Returns the field.
    @discardableResult
    func searchFor(_ query: String) -> AXElement? {
        guard let field = activateSearch() else { return nil }
        focusAndType(field, query)
        type("x")
        key(Keyboard.delete)
        Timing.pause(Timing.animation)
        Timing.pause(Timing.animation)
        return field
    }

    // Fast "it disappeared" check — bails the moment it's absent instead of waiting the timeout.
    func isGone(_ match: AXMatch, within timeout: TimeInterval = 1.2) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if window.firstDescendant(where: match) == nil { return true }
            Timing.pause(Timing.poll)
        } while Date() < deadline
        return window.firstDescendant(where: match) == nil
    }

    // MARK: - Click

    @discardableResult
    // Mouse-click first: much of Wiles' UI is a plain view + `.onTapGesture` (+ `.isButton` trait),
    // and AXPress reports success on those without firing the gesture. AXPress is only the fallback
    // for an element with no usable frame.
    func tapElement(_ element: AXElement) -> Bool {
        let rect = element.frame
        if !rect.isEmpty {
            Mouse.click(center: rect, pid: pid)
            return true
        }
        return element.actionNames.contains(AXAction.press) && element.press()
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

    /// Always a real pointer click at the element centre (never `AXPress`) — the reliable way to
    /// make a text field the first responder so keystrokes and `.onSubmit` reach it.
    @discardableResult
    func clickCentre(_ element: AXElement) -> Bool {
        let rect = element.frame
        guard !rect.isEmpty else { return false }
        Mouse.click(center: rect, pid: pid)
        Timing.pause(Timing.brief)
        return true
    }

    /// Replaces a text field's contents: focus it (AX-press, AX-focus, and a real click), ⌘A +
    /// delete, then synthesised keystrokes (SwiftUI `TextField` ignores a bare AX value set).
    func replaceText(in field: AXElement, with text: String) {
        tapElement(field)
        field.focus()
        Timing.pause(Timing.brief)
        clickCentre(field)
        chord("a", .command)
        Timing.pause(Timing.brief)
        key(Keyboard.delete)
        Timing.pause(Timing.brief)
        type(text)
        Timing.pause(Timing.brief)
    }

    /// Focuses `field` (activate app + real click + AX focus) and types `text`, verifying it
    /// landed by reading the value back — retrying up to 3× (synthetic keys can be dropped if the
    /// app isn't key, or if the operator is using the keyboard). Returns whether it stuck.
    @discardableResult
    func focusAndType(_ field: AXElement, _ text: String, clearFirst: Bool = true) -> Bool {
        for _ in 0 ..< 3 {
            process.activate()
            Timing.pause(Timing.brief)
            clickCentre(field)
            field.focus()
            Timing.pause(Timing.brief)
            if clearFirst {
                chord("a", .command)
                key(Keyboard.delete)
                Timing.pause(Timing.brief)
            }
            type(text)
            Timing.pause(Timing.settle)
            if (field.stringValue ?? "").localizedCaseInsensitiveContains(text) { return true }
        }
        return (field.stringValue ?? "").localizedCaseInsensitiveContains(text)
    }

    /// Commits a field edit — tries ⏎, the AX confirm action, and a literal carriage return.
    func commitField(_ field: AXElement) {
        key(Keyboard.returnKey)
        Timing.pause(Timing.brief)
        _ = field.perform(AXAction.confirm)
        Timing.pause(Timing.brief)
    }

    /// Waits for the inline rename field, replaces its text with `name`, and commits with ⏎.
    @discardableResult
    func commitInlineRename(to name: String) -> Bool {
        guard let field = find(AXMatch(identifier: "InlineRenameField"), timeout: 4) else {
            reporter.fail("InlineRenameField did not appear")
            return false
        }
        replaceText(in: field, with: name)
        commitField(field)
        Timing.pause(Timing.settle)
        return true
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
        guard let item = container.waitForDescendant(where: AXMatch(role: "AXMenuItem", textContains: leafFragment), timeout: 3, maxDepth: 10) else {
            key(Keyboard.escape)
            reporter.fail("\(label): '\(leafFragment)' not found under \(menuTitle) ▸ \(path.joined(separator: " ▸ "))")
            return false
        }
        // Real NSMenuItems in the menu bar respond to AXPress; a mouse click on an open dropdown is racy.
        let pressed = item.perform(AXAction.press) || pressMenuItem(item)
        Timing.pause(Timing.settle)
        return pressed
    }

    /// Opens `menuTitle` then each nested submenu named by `path`, returning the innermost open
    /// menu container (or `nil` on failure, with the menu dismissed).
    private func openMenu(_ menuTitle: String, path: [String], _ label: String) -> AXElement? {
        // Clear any menu/popover left open by a previous step so a stale tree can't wedge the walk.
        key(Keyboard.escape)
        Timing.pause(Timing.brief)
        guard let barItem = app.menuBar?.children.first(where: { $0.title == menuTitle }) else {
            reporter.fail("\(label): menu '\(menuTitle)' not in menu bar")
            return nil
        }
        barItem.press()
        Timing.pause(Timing.settle)
        var container = barItem
        for fragment in path {
            guard let submenuItem = container.waitForDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment), timeout: 3, maxDepth: 10) else {
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
        // A real click on the visibly-open menu item is the only thing that reliably fires
        // SwiftUI `.contextMenu` Button actions — AXPick/AXPress return success without invoking them.
        let rect = item.frame
        if !rect.isEmpty {
            Mouse.click(center: rect, pid: pid)
            return true
        }
        if item.perform(AXAction.pick) { return true }
        return item.press()
    }

    func closeAnyMenu() {
        // Only send Escape if something is actually open — a stray Escape on the focused file list
        // can drop the selection / collapse the view and make rows momentarily unfindable.
        guard app.firstDescendant(where: AXMatch(role: "AXMenu"), maxDepth: 6) != nil
            || app.firstDescendant(where: AXMatch(role: "AXMenuItem"), maxDepth: 6) != nil
            || sheet() != nil else { return }
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
        let found = container.firstDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment), maxDepth: 10) != nil
        key(Keyboard.escape)
        Timing.pause(Timing.brief)
        return found
    }

    func allRows(textEquals name: String) -> [AXElement] {
        (try? mainWindow())?.allDescendants(where: AXMatch(textEquals: name), maxDepth: 20) ?? []
    }

    // A real content row: on screen, plausibly-sized, in the content area (not the sidebar, not 0,0).
    func rowFrameIsSane(_ f: CGRect) -> Bool {
        f.width > 40 && f.height > 8 && f.height < 400 && f.minX > 200 && f.minY > 40
    }

    // MARK: - Context menu

    // Left-click first: AXShowMenu opens the menu without selecting the row, so the action runs on an empty selection.
    @discardableResult
    func openContextItem(onFileRow name: String, containing fragment: String, _ label: String) -> Bool {
        for attempt in 0 ..< 2 {
            closeAnyMenu()
            var row = allRows(textEquals: name).first { rowFrameIsSane($0.frame) }
            if row == nil {
                Timing.pause(Timing.settle)
                row = allRows(textEquals: name).first { rowFrameIsSane($0.frame) }
            }
            guard let row else {
                if attempt == 1 { reporter.fail("'\(name)' row (for context menu): not found (for context menu)") }
                continue
            }
            Mouse.click(center: row.frame, pid: pid)
            Timing.pause(Timing.brief)
            Mouse.click(center: row.frame, rightButton: true, pid: pid)
            Timing.pause(Timing.settle)
            if app.waitForDescendant(where: AXMatch(role: "AXMenuItem", textContains: fragment), timeout: 3, maxDepth: 14) != nil {
                return pickContextItem(containing: fragment, label)
            }
            if attempt == 1 {
                closeAnyMenu()
                reporter.fail("\(label): context item '\(fragment)' not in the menu for '\(name)'")
            }
        }
        return false
    }

    @discardableResult
    func pickContextItem(containing fragment: String, _ label: String) -> Bool {
        let match = AXMatch(role: "AXMenuItem", textContains: fragment)
        guard let item = app.waitForDescendant(where: match, timeout: 5, maxDepth: 14) else {
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

    /// Right-clicks an empty spot in the content pane (below the last row) to raise the
    /// folder-background context menu (New Folder / Paste / …).
    @discardableResult
    func rightClickContentArea() -> Bool {
        contentAreaClick(rightButton: true)
    }

    /// Left-clicks the same empty spot — deselects everything / dismisses an inline edit.
    @discardableResult
    func clickContentArea() -> Bool {
        contentAreaClick(rightButton: false)
    }

    @discardableResult
    private func contentAreaClick(rightButton: Bool) -> Bool {
        guard let window = try? mainWindow() else { return false }
        let frame = window.frame
        let point = CGPoint(x: frame.midX + frame.width * 0.15, y: frame.maxY - 60)
        Mouse.click(at: point, rightButton: rightButton, pid: pid)
        Timing.pause(Timing.settle)
        return true
    }

    // MARK: - Sheets

    func sheet() -> AXElement? {
        app.firstDescendant(where: AXMatch(role: "AXSheet"))
    }

    func waitForSheet(timeout: TimeInterval = 5) -> Bool {
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

    /// Points Wiles at `path` via the Go ▸ Go to Folder text field.
    /// Enters `path` in the Go ▸ Go to Folder field. When `expectRow` is non-empty, returns true
    /// only once that row is listed (with one retry); when empty, just performs the navigation.
    @discardableResult
    func navigateToPath(_ path: String, expectRow: String = "", timeout: TimeInterval = 8) -> Bool {
        for attempt in 0 ..< 3 {
            closeAnyMenu()
            process.activate()
            chord("l", .command) // Go ▸ Go to Folder
            Timing.pause(Timing.settle)
            if find(AXMatch(identifier: "PathBarTextField"), timeout: 1) == nil {
                menuPick("Go", itemContains: "Go to Folder", "Go ▸ Go to Folder")
                Timing.pause(Timing.settle)
            }
            guard let field = find(AXMatch(identifier: "PathBarTextField"), timeout: 4) else {
                if attempt == 2 { reporter.fail("PathBarTextField not found after Go to Folder") }
                continue
            }
            clickCentre(field)
            field.focus()
            Timing.pause(Timing.brief)
            chord("a", .command)
            key(Keyboard.delete)
            Timing.pause(Timing.brief)
            if attempt == 0 {
                // Fastest path: set the field value directly, then fire its submit action.
                field.setValue(path)
                Timing.pause(Timing.brief)
            } else {
                type(path)
                Timing.pause(Timing.brief)
            }
            _ = field.perform(AXAction.confirm)
            key(Keyboard.returnKey)
            if expectRow.isEmpty {
                Timing.pause(Timing.animation)
                return true
            }
            if fileRow(expectRow, timeout: timeout) != nil { return true }
        }
        return false
    }

    /// Ensures Wiles is showing the seeded temp directory (normally already true — the launch
    /// defaults domain seeds `wiles_lastOpenedFolder`).
    @discardableResult
    func navigateToWorkspace() -> Bool {
        if fileRow(workspace.alphaFile, timeout: 2) != nil { return true }
        return navigateToPath(workspace.root.path, expectRow: workspace.alphaFile)
    }

    func fileRow(_ name: String, timeout: TimeInterval = 5) -> AXElement? {
        find(AXMatch(textEquals: name), timeout: timeout)
    }

    /// Opens a folder/file row and confirms we navigated by `expectRow` appearing (or, when it's
    /// empty, just that the row we double-clicked is gone). Double-click, then AXPress on the row,
    /// then File ▸ Open — whichever lands first.
    @discardableResult
    func openRow(_ name: String, expectRow: String = "", timeout: TimeInterval = 5) -> Bool {
        guard let row = fileRow(name, timeout: timeout), !row.frame.isEmpty else {
            reporter.fail("row '\(name)': not found (to open)")
            return false
        }
        func landed() -> Bool {
            if !expectRow.isEmpty { return fileRow(expectRow, timeout: 3) != nil }
            return fileRow(name, timeout: 1) == nil
        }
        Mouse.doubleClick(center: row.frame, pid: pid)
        Timing.pause(Timing.animation)
        if landed() { return true }

        row.press()
        Timing.pause(Timing.brief)
        _ = menuPick("File", itemContains: "Open", "File ▸ Open ('\(name)')")
        Timing.pause(Timing.animation)
        return landed()
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
        // The 4 tab buttons are a row of small (~64×44) `.onTapGesture` views near the sheet top;
        // the tab's content view shares its label, so match the row, sort by x, click by index.
        let order = ["General", "Appearance", "Sidebar", "Advanced"]
        guard let s = sheet(), !s.frame.isEmpty else { reporter.fail("Settings sheet gone"); return false }
        let topY = s.frame.minY
        let tabRow = s.allDescendants(where: AXMatch(role: "AXButton"), maxDepth: 26)
            .filter { e in
                let f = e.frame
                return f.height > 0 && f.height <= 80 && f.width > 0 && f.width <= 170
                    && f.minY < topY + 90 && order.contains(where: { e.descriptionText == $0 || e.title == $0 })
            }
            .sorted { $0.frame.minX < $1.frame.minX }
        var target = tabRow.first { $0.descriptionText == tab || $0.title == tab }
        if target == nil, let idx = order.firstIndex(of: tab), tabRow.indices.contains(idx) {
            target = tabRow[idx]
        }
        guard let target else {
            reporter.fail("Settings tab '\(tab)' not found among \(tabRow.map(\.descriptionText))")
            return false
        }
        Mouse.click(center: target.frame, pid: pid)
        Timing.pause(Timing.settle)
        return true
    }

    /// Opens Settings (⌘, then the Wiles-menu item as fallback) on the General tab and sets the
    /// Language picker to `endonym` ("English", "Português", …) — endonyms render identically in
    /// every locale. Returns whether the app-menu titles then reflect the target language.
    @discardableResult
    func setLanguage(to endonym: String, expectMenu: String) -> Bool {
        for attempt in 0 ..< 2 {
            if sheet() == nil {
                chord(",", .command)
                if !waitForSheet(timeout: 4) {
                    _ = menuPick("Wiles", itemContains: "Settings", "Wiles ▸ Settings")
                        || menuPick("Wiles", itemContains: "Ajustes", "Wiles ▸ Ajustes")
                    _ = waitForSheet(timeout: 4)
                }
            }
            if let picker = sheet()?.firstDescendant(where: AXMatch(role: "AXPopUpButton")) {
                tapElement(picker)
                Timing.pause(Timing.settle)
                if let item = app.waitForDescendant(where: AXMatch(role: "AXMenuItem", textEquals: endonym), timeout: 3, maxDepth: 12) {
                    _ = item.perform(AXAction.pick) || item.press()
                } else {
                    closeAnyMenu()
                }
            }
            Timing.pause(Timing.animation)
            dismissSheet()
            // A language switch rebuilds the whole SwiftUI tree — let it settle and re-focus.
            Timing.pause(Timing.launch)
            process.activate()
            Timing.pause(Timing.settle)
            if menuBarTitles().contains(expectMenu) { return true }
            if attempt == 0 { Timing.pause(Timing.settle) }
        }
        return menuBarTitles().contains(expectMenu)
    }

    /// Selects `option` on a SwiftUI `Picker` inside the current sheet — coping with either shape
    /// it can render as here (pop-up menu button, or an inline segmented / radio group).
    /// `popupIndex` picks which pop-up when the sheet has several (0 = first).
    @discardableResult
    func selectPickerOption(_ option: String, popupIndex: Int = 0) -> Bool {
        guard let sheet = sheet() else { return false }

        let segmented = sheet.firstDescendant(where: AXMatch(role: "AXRadioButton", textContains: option))
            ?? sheet.firstDescendant(where: AXMatch(role: "AXButton", predicate: { element in
                element.subrole == "AXToggle" && element.title.localizedCaseInsensitiveContains(option)
            }))
        if let segmented {
            return tapElement(segmented)
        }
        let popups = sheet.allDescendants(where: AXMatch(role: "AXPopUpButton"), maxDepth: 16)
        guard popupIndex < popups.count else { return false }
        let popup = popups[popupIndex]
        if !popup.frame.isEmpty {
            Mouse.click(center: popup.frame, pid: pid)
        } else {
            popup.press()
        }
        Timing.pause(Timing.settle)
        if let item = app.waitForDescendant(where: AXMatch(role: "AXMenuItem", textContains: option), timeout: 3, maxDepth: 12) {
            return pressMenuItem(item)
        }
        closeAnyMenu()
        return false
    }

    @discardableResult
    func selectThemeOption(_ option: String) -> Bool {
        selectPickerOption(option)
    }
}
