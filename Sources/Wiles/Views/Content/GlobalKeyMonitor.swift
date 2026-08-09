import SwiftUI
import QuickLook
import AppKit

struct GlobalKeyMonitor: NSViewRepresentable {
    var appState: AppState
    var windowUIState: WindowUIState

    func makeNSView(context: Context) -> KeyMonitorNSView {
        let view = KeyMonitorNSView()
        view.appState = appState
        view.windowUIState = windowUIState
        return view
    }

    func updateNSView(_ nsView: KeyMonitorNSView, context: Context) {
        nsView.appState = appState
        nsView.windowUIState = windowUIState
    }

    class KeyMonitorNSView: NSView {
        var appState: AppState?
        var windowUIState: WindowUIState?
        private var monitor: Any?
        private var accumulatedScrollDelta: Double = 0

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil && monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) { [weak self] event in
                    self?.processLocalEvent(event)
                }
            }
        }

        private func processLocalEvent(_ event: NSEvent) -> NSEvent? {
            guard let appState = appState, let windowUIState = windowUIState else { return event }
            if let firstResponder = event.window?.firstResponder, firstResponder is NSTextView || firstResponder is NSTextField {
                return event
            }

            if event.type == .scrollWheel {
                return handleScrollEvent(event, appState: appState)
            } else if event.type == .keyDown {
                return handleKeyDownEvent(event, appState: appState, windowUIState: windowUIState)
            }
            return event
        }

        private func handleScrollEvent(_ event: NSEvent, appState: AppState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            guard isCmd || isCtrl else { return event }

            let delta = event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
            guard delta != 0 else { return event }

            accumulatedScrollDelta += delta
            let stepMagnitude = IconSizeToken.scrollWheelStep
            while abs(accumulatedScrollDelta) >= stepMagnitude {
                let step = accumulatedScrollDelta > 0 ? stepMagnitude : -stepMagnitude
                appState.preferences.iconSize = min(IconSizeToken.maxSize, max(IconSizeToken.minSize, appState.preferences.iconSize + step))
                accumulatedScrollDelta -= step
            }
            return nil
        }

        private func handleKeyDownEvent(_ event: NSEvent, appState: AppState, windowUIState: WindowUIState) -> NSEvent? {
            let isCmd = event.modifierFlags.contains(.command)
            let isCtrl = event.modifierFlags.contains(.control)
            let code = event.keyCode

            if (isCmd || isCtrl) && handleZoomKeyDown(code: code, appState: appState) {
                return nil
            }
            if handleNavigationKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState) {
                return nil
            }
            return event
        }

        private func handleZoomKeyDown(code: UInt16, appState: AppState) -> Bool {
            switch code {
            case KeyCode.equals, KeyCode.keypadPlus, KeyCode.bracketRight:
                appState.preferences.iconSize = min(IconSizeToken.maxSize, appState.preferences.iconSize + IconSizeToken.step)
                return true
            case KeyCode.minus, KeyCode.keypadMinus:
                appState.preferences.iconSize = max(IconSizeToken.minSize, appState.preferences.iconSize - IconSizeToken.step)
                return true
            case KeyCode.zero:
                appState.preferences.iconSize = IconSizeToken.defaultSize
                return true
            default:
                return false
            }
        }

        private func handleNavigationKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if let arrowCode = ArrowKey(code: code) {
                if isCmd, let fav = windowUIState.selectedFavoriteURL,
                    fav.standardizedFileURL == appState.navigation.currentURL.standardizedFileURL,
                    arrowCode == .up || arrowCode == .down {
                    appState.moveSelectedFavorite(offset: arrowCode == .up ? -1 : 1, windowUIState: windowUIState)
                    return true
                }
                let isShift = NSEvent.modifierFlags.contains(.shift)
                handleArrowKeyDown(arrowCode, isShift: isShift, appState: appState)
                return true
            }
            return handleEditActionKeyDown(code: code, isCmd: isCmd, appState: appState, windowUIState: windowUIState)
        }

        private enum ArrowKey: Equatable {
            case up, down, left, right

            init?(code: UInt16) {
                switch code {
                case KeyCode.arrowUp: self = .up
                case KeyCode.arrowDown: self = .down
                case KeyCode.arrowLeft: self = .left
                case KeyCode.arrowRight: self = .right
                default: return nil
                }
            }
        }

        private func handleArrowKeyDown(_ key: ArrowKey, isShift: Bool, appState: AppState) {
            switch key {
            case .up:
                if appState.preferences.viewMode == .column {
                    appState.selection.columnViewVerticalDirection = -1
                    appState.selection.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.preferences.viewMode == .grid ? -appState.selection.gridColumnCount : -1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
            case .down:
                if appState.preferences.viewMode == .column {
                    appState.selection.columnViewVerticalDirection = 1
                    appState.selection.columnViewVerticalTrigger += 1
                } else {
                    let offset = appState.preferences.viewMode == .grid ? appState.selection.gridColumnCount : 1
                    moveSelection(by: offset, isShift: isShift, appState: appState)
                }
            case .left:
                if appState.preferences.viewMode == .grid {
                    moveSelection(by: -1, isShift: isShift, appState: appState)
                } else if appState.preferences.viewMode == .column {
                    appState.selection.columnViewMoveLeftTrigger += 1
                } else {
                    appState.goUp()
                }
            case .right:
                if appState.preferences.viewMode == .grid {
                    moveSelection(by: 1, isShift: isShift, appState: appState)
                } else if appState.preferences.viewMode == .column {
                    appState.selection.columnViewDrillRightTrigger += 1
                } else if let first = appState.selectedURLs.first,
                    let item = appState.fileSystem.items.first(where: { $0.url == first }), item.isDirectory {
                    appState.navigateTo(first)
                }
            }
        }

        private func handleEditActionKeyDown(code: UInt16, isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if code == KeyCode.f2 {
                if !appState.selectedURLs.isEmpty {
                    triggerRenameForSelected(appState: appState, windowUIState: windowUIState)
                    return true
                }
            } else if code == KeyCode.backspace || code == KeyCode.forwardDelete {
                if !appState.selectedURLs.isEmpty {
                    appState.deleteSelected(windowUIState: windowUIState)
                    return true
                } else if appState.navigationMode == .gnome && !isCmd {
                    appState.goUp()
                    return true
                }
            } else if code == KeyCode.returnKey {
                return handleReturnKeyDown(isCmd: isCmd, appState: appState, windowUIState: windowUIState)
            }
            return false
        }

        private func handleReturnKeyDown(isCmd: Bool, appState: AppState, windowUIState: WindowUIState) -> Bool {
            if isCmd && !appState.selectedURLs.isEmpty {
                appState.deleteSelected(windowUIState: windowUIState)
                return true
            } else if !isCmd {
                if appState.navigationMode == .gnome, let first = appState.selectedURLs.first {
                    appState.navigateTo(first)
                    return true
                } else if appState.navigationMode == .macOS, let first = appState.selectedURLs.first,
                    let item = appState.fileSystem.items.first(where: { $0.url == first }) {
                    windowUIState.renameItem = item
                    return true
                }
            }
            return false
        }

        private func moveSelection(by offset: Int, isShift: Bool, appState: AppState) {
            let items = appState.fileSystem.items
            guard !items.isEmpty else { return }
            let anchorURL = appState.selectedURLs.first
            let anchorIndex = items.firstIndex(where: { $0.url == anchorURL }) ?? -1
            let newIndex = max(0, min(items.count - 1, anchorIndex + offset))
            let newURL = items[newIndex].url
            if isShift && anchorIndex >= 0 {
                let lo = min(anchorIndex, newIndex)
                let hi = max(anchorIndex, newIndex)
                appState.selectedURLs = Set(items[lo...hi].map { $0.url })
            } else {
                appState.selectedURLs = [newURL]
            }
        }

        private func triggerRenameForSelected(appState: AppState, windowUIState: WindowUIState) {
            if appState.selectedURLs.count > 1 {
                windowUIState.showBatchRenameSheet = true
            } else if let first = appState.selectedURLs.first, let item = appState.fileSystem.items.first(where: { $0.url == first }) {
                windowUIState.renameItem = item
            }
        }
    }
}
