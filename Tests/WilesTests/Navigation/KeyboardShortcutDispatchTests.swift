import AppKit
import Foundation
import SwiftUI
@testable import Wiles

/// Characterization coverage for the keyboard-dispatch layer, locked in before the [A3]
/// `ShortcutRegistry` refactor so the refactor can't silently change behavior:
/// `KeyboardSelectionNavigator` (arrows / F2 / Delete / Return by navigation mode),
/// `KeyboardZoomController` (zoom keys, incl. Cmd+] no longer zooming), and `ShortcutRegistry`
/// itself (every menu command has a unique, labelled combo).
@MainActor
public struct KeyboardShortcutDispatchTests {
    public static func run() {
        testArrowNavigationMovesSelection()
        testFavoriteReorderShortcut()
        testCommandUpGoesToEnclosingFolder()
        testCommandDownOpensSelectedInMacOS()
        testF2TriggersRename()
        testDeleteKeyTrashesSelection()
        testBackspaceWithoutSelectionGoesUpInWindows()
        testReturnKeyByNavigationMode()
        testCmdReturnTrashesSelection()
        testZoomKeys()
        testCmdBracketRightNoLongerZooms()
        testRegistryMenuCommandsAreCompleteAndUnique()
    }

    private static func makeItems(_ names: [String]) -> [FileItem] {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        return names.map { FileItem.load(url: dir.appendingPathComponent($0), icon: NSImage()) }
    }

    private static let nav = KeyboardSelectionNavigator()

    private static func context(mode: NavigationMode = .macOS, items: [FileItem] = [])
        -> (AppState, WindowUIState) {
        let appState = AppState()
        appState.preferences.view.navigationMode = mode
        appState.preferences.view.applyPreset(mode)
        appState.fileSystem.items = items
        return (appState, WindowUIState(preferences: appState.preferences))
    }

    private static func testArrowNavigationMovesSelection() {
        let items = makeItems(["a", "b", "c"])
        let (appState, windowUIState) = context(items: items)
        appState.selection.selectedURLs = [items[0].url]
        let handled = nav.handleNavigationKeyDown(
            code: KeyCode.arrowDown, isCmd: false, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: ↓ is handled and moves selection to the next item",
            result: handled && appState.selection.selectedURLs == [items[1].url])
    }

    private static func testFavoriteReorderShortcut() {
        let items = makeItems(["only"])
        let (appState, windowUIState) = context(items: items)
        appState.navigation.currentURL = items[0].url
        windowUIState.selectedFavoriteURL = items[0].url
        appState.preferences.favorites.favoriteURLs = [items[0].url, URL(fileURLWithPath: "/tmp/other-\(UUID().uuidString)")]
        let handled = nav.handleNavigationKeyDown(code: KeyCode.arrowDown, isCmd: true, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Cmd+↓ on the browsed favorite is handled as a reorder",
            result: handled && appState.preferences.favorites.favoriteURLs.last == items[0].url)
    }

    private static func testCommandUpGoesToEnclosingFolder() {
        let parent = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let child = parent.appendingPathComponent("child")
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let (appState, windowUIState) = context(mode: .macOS)
        appState.navigateTo(child)
        appState.selection.selectedURLs = []
        let handled = nav.handleNavigationKeyDown(code: KeyCode.arrowUp, isCmd: true, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Cmd+↑ (no favorite) navigates to the enclosing folder",
            result: handled && appState.navigation.currentURL.standardizedFileURL.path == parent.standardizedFileURL.path)
    }

    private static func testCommandDownOpensSelectedInMacOS() {
        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let sub = dir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let subItem = FileItem.load(url: sub, icon: NSImage())
        let (appState, windowUIState) = context(mode: .macOS, items: [subItem])
        appState.selection.selectedURLs = [subItem.url]
        let handled = nav.handleNavigationKeyDown(code: KeyCode.arrowDown, isCmd: true, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Cmd+↓ in macOS mode opens the selected folder",
            result: handled && appState.navigation.currentURL.standardizedFileURL == sub.standardizedFileURL)
    }

    private static func testF2TriggersRename() {
        let items = makeItems(["file"])
        let (appState, windowUIState) = context(mode: .windows, items: items)
        appState.selection.selectedURLs = [items[0].url]
        let handled = nav.handleNavigationKeyDown(code: KeyCode.f2, isCmd: false, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: F2 with one item selected is handled and sets renameItem",
            result: handled && windowUIState.renameItem?.url == items[0].url)
    }

    private static func testDeleteKeyTrashesSelection() {
        let items = makeItems(["file"])
        let (appState, windowUIState) = context(items: items)
        appState.selection.selectedURLs = [items[0].url]
        appState.preferences.view.skipDeleteConfirmation = false
        let handled = nav.handleNavigationKeyDown(code: KeyCode.backspace, isCmd: false, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Delete with a selection is handled and raises the trash confirm",
            result: handled && windowUIState.showDeleteConfirmAlert)
    }

    private static func testBackspaceWithoutSelectionGoesUpInWindows() {
        let parent = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let child = parent.appendingPathComponent("child")
        try? FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }
        let (appState, windowUIState) = context(mode: .windows)
        appState.navigateTo(child)
        appState.selection.selectedURLs = []
        let handled = nav.handleNavigationKeyDown(code: KeyCode.backspace, isCmd: false, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Backspace with no selection in Windows mode navigates to the parent folder",
            result: handled && appState.navigation.currentURL.standardizedFileURL.path == parent.standardizedFileURL.path)
    }

    private static func testReturnKeyByNavigationMode() {
        let items = makeItems(["file"])
        let (macState, macWindow) = context(mode: .macOS, items: items)
        macState.selection.selectedURLs = [items[0].url]
        macState.selection.keyboardSelectionAnchorURL = items[0].url
        let macHandled = nav.handleNavigationKeyDown(code: KeyCode.returnKey, isCmd: false, appState: macState, windowUIState: macWindow)
        report(
            "Keyboard/Dispatch", "POS: Return in macOS mode is handled as rename (sets renameItem)",
            result: macHandled && macWindow.renameItem?.url == items[0].url)

        let dir = URL(fileURLWithPath: testTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let realChild = dir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: realChild, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let childItem = FileItem.load(url: realChild, icon: NSImage())
        let (windowsModeState, windowsModeWindow) = context(mode: .windows, items: [childItem])
        windowsModeState.selection.selectedURLs = [childItem.url]
        windowsModeState.selection.keyboardSelectionAnchorURL = childItem.url
        let windowsModeHandled = nav.handleNavigationKeyDown(
            code: KeyCode.returnKey, isCmd: false, appState: windowsModeState, windowUIState: windowsModeWindow)
        report(
            "Keyboard/Dispatch", "POS: Return in Windows mode is handled as open (navigates into the folder)",
            result: windowsModeHandled && windowsModeState.navigation.currentURL.standardizedFileURL == realChild.standardizedFileURL)
    }

    private static func testCmdReturnTrashesSelection() {
        let items = makeItems(["file"])
        let (appState, windowUIState) = context(items: items)
        appState.selection.selectedURLs = [items[0].url]
        appState.preferences.view.skipDeleteConfirmation = false
        let handled = nav.handleNavigationKeyDown(code: KeyCode.returnKey, isCmd: true, appState: appState, windowUIState: windowUIState)
        report(
            "Keyboard/Dispatch", "POS: Cmd+Return with a selection is handled and raises the trash confirm",
            result: handled && windowUIState.showDeleteConfirmAlert)
    }

    private static func testZoomKeys() {
        let appState = AppState()
        let zoom = KeyboardZoomController()
        appState.preferences.view.iconSize = IconSizeToken.defaultSize

        _ = zoom.handleZoomKeyDown(code: KeyCode.equals, appState: appState)
        let grew = appState.preferences.view.iconSize > IconSizeToken.defaultSize
        _ = zoom.handleZoomKeyDown(code: KeyCode.zero, appState: appState)
        let reset = appState.preferences.view.iconSize == IconSizeToken.defaultSize
        _ = zoom.handleZoomKeyDown(code: KeyCode.minus, appState: appState)
        let shrank = appState.preferences.view.iconSize < IconSizeToken.defaultSize
        report("Keyboard/Dispatch", "POS: Cmd+= grows, Cmd+0 resets, Cmd+- shrinks the icon size", result: grew && reset && shrank)
    }

    private static func testCmdBracketRightNoLongerZooms() {
        let appState = AppState()
        let zoom = KeyboardZoomController()
        appState.preferences.view.iconSize = IconSizeToken.defaultSize
        let handled = zoom.handleZoomKeyDown(code: KeyCode.bracketRight, appState: appState)
        report(
            "Keyboard/Dispatch", "NEG: Cmd+] is no longer a zoom key (left free for Go Forward)",
            result: !handled && appState.preferences.view.iconSize == IconSizeToken.defaultSize)
    }

    private static func testRegistryMenuCommandsAreCompleteAndUnique() {
        let menuCommands: [ShortcutRegistry.Command] = [
            .settings, .undo, .redo, .cut, .copy, .paste, .selectAll, .find, .newWindow, .closeWindow,
            .newFolder, .newFile, .open, .properties, .quickLook, .moveToTrash, .rename, .goBack, .goForward,
            .goToFolder, .connectToServer, .help, .shortcutsHUD, .toggleTerminal, .togglePreview, .toggleDiskUsage
        ]
        let preset = ShortcutRegistry.preset(for: .windows)
        let allHaveKeyAndLabel = menuCommands.allSatisfy {
            guard let binding = preset[$0] else { return false }
            return binding.keyEquivalent != nil && !ShortcutRegistry.label($0, in: preset).isEmpty
        }
        report("Keyboard/Dispatch", "POS: every menu-backed command has both a key and a non-empty label", result: allHaveKeyAndLabel)

        let combos = menuCommands.map { command -> String in
            let binding = preset[command]
            return "\(binding?.character ?? "?")|\(binding?.modifiersRawValue ?? -1)"
        }
        report(
            "Keyboard/Dispatch", "POS: no two menu-backed commands share the same key+modifiers combo",
            result: Set(combos).count == combos.count)

        report(
            "Keyboard/Dispatch", "POS: Go Forward owns Cmd+] and zoom-in owns Cmd+=",
            result: preset[.goForward]?.character == "]"
                && preset[.zoomIn]?.character == "="
                && preset[.zoomIn]?.physicalKeyCode != KeyCode.bracketRight)

        let everyCommandLabelled = ShortcutRegistry.Command.allCases.allSatisfy { !ShortcutRegistry.label($0, in: preset).isEmpty }
        report(
            "Keyboard/Dispatch",
            "POS: every ShortcutRegistry.Command has a non-empty label (Windows preset, or the two fixed non-editable interactions' own fixed label)",
            result: everyCommandLabelled)

        report(
            "Keyboard/Dispatch", "POS: toggleHiddenFiles carries its fixed ⌃H alternate",
            result: ShortcutRegistry.toggleHiddenFilesAlternate == KeyboardShortcut("h", modifiers: .control))
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
