import AppKit
import SwiftUI

struct ShortcutsHUDOverlay: View {
    var appState: AppState
    @Binding var isPresented: Bool
    @State private var selectedFilter: ShortcutsFilter

    init(appState: AppState, isPresented: Binding<Bool>) {
        self.appState = appState
        _isPresented = isPresented
        _selectedFilter = State(initialValue: appState.preferences.navigationMode == .macOS ? .macOS : .windows)
    }

    var body: some View {
        ZStack {
            // `MainContentView` applies `.ignoresSafeArea(.all, edges: .top)` so `HeaderBarView`
            // can extend up into the hidden-title-bar region at the very top of the window. This
            // dimming backdrop needs the same treatment, or that same top strip stays undimmed
            // while everything below it darkens.
            Color.black.opacity(0.3)
                .ignoresSafeArea(.all, edges: .top)
                .onTapGesture {
                    withAnimation(MotionTokens.snappySpring) {
                        isPresented = false
                    }
                }

            cardView
            Button("") {
                withAnimation(MotionTokens.snappySpring) {
                    isPresented = false
                }
            }
            .keyboardShortcut(.escape, modifiers: [])
            .hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardView: some View {
        VStack(spacing: 16) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)
            modeTabRow
                .padding(.horizontal, 20)
            Divider()
            shortcutColumns
            Divider()
            footer
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 350, maxWidth: 450, minHeight: 390, maxHeight: 510)
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .hudWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.85)
            })
        // A single `.clipShape` for the whole composited card (content + background layers)
        // instead of separate `.cornerRadius()` calls on each background layer — mismatched
        // per-layer corner clipping is what caused the rounded top area (where the header sits)
        // to render inconsistently against the rest of the card.
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.25), radius: 15, x: 0, y: 8)
    }

    private var header: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.shortcutsCheatsheetTitle))
                    .font(.system(size: 16, weight: .bold))
                Text(appState.tr(.shortcutsCheatsheetSubtitle))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var modeTabRow: some View {
        HStack(spacing: 8) {
            ForEach(ShortcutsFilter.allCases) { filter in
                modeTabButton(filter)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func modeTabButton(_ filter: ShortcutsFilter) -> some View {
        let isSelected = selectedFilter == filter
        let isActual = filter.navigationMode == appState.preferences.navigationMode
        return Button {
            withAnimation(MotionTokens.snappySpring) { selectedFilter = filter }
        } label: {
            HStack(spacing: 5) {
                Text(appState.tr(filter.l10nKey))
                    .font(.system(size: 11, weight: .semibold))
                if isActual {
                    Text(appState.tr(.shortcutsCurrentModeBadge).uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.25))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            .foregroundColor(isSelected ? Color.accentColor : Color.primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.tr(filter.l10nKey))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) {
                withAnimation(MotionTokens.snappySpring) {
                    isPresented = false
                }
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var shortcutColumns: some View {
        ScrollView {
            VStack(spacing: 12) {
                if selectedFilter == .all {
                    shortcutGroup(title: appState.tr(.shortcutsNav), items: merged(navigationShortcuts(for: .macOS), navigationShortcuts(for: .gnome)))
                    shortcutGroup(
                        title: appState.tr(.shortcutsFileActions),
                        items: merged(fileActionsShortcuts(for: .macOS), fileActionsShortcuts(for: .gnome)))
                    shortcutGroup(title: appState.tr(.shortcutsSystem), items: merged(systemShortcuts(for: .macOS), systemShortcuts(for: .gnome)))
                    shortcutGroup(title: appState.tr(.shortcutsGeneral), items: generalShortcuts)
                } else {
                    let mode = selectedFilter.navigationMode ?? appState.preferences.navigationMode
                    shortcutGroup(title: appState.tr(.shortcutsNav), items: navigationShortcuts(for: mode))
                    shortcutGroup(title: appState.tr(.shortcutsFileActions), items: fileActionsShortcuts(for: mode))
                    shortcutGroup(title: appState.tr(.shortcutsSystem), items: systemShortcuts(for: mode))
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func navigationShortcuts(for mode: NavigationMode) -> [(String, String)] {
        if mode == .macOS {
            [
                (appState.tr(.actNavBackForward), KeyLabel.cmdBracketNavigation),
                (appState.tr(.actParentFolder), KeyLabel.cmdUpArrow),
                (appState.tr(.shortcutsOpenFolder), KeyLabel.cmdDownArrow)
            ]
        } else {
            [
                (appState.tr(.actNavBackForward), KeyLabel.cmdBracketNavigation),
                (appState.tr(.actParentFolder), KeyLabel.backspace),
                (appState.tr(.shortcutsOpenFolder), KeyLabel.enter)
            ]
        }
    }

    private func fileActionsShortcuts(for mode: NavigationMode) -> [(String, String)] {
        let renameKey = mode == .gnome ? KeyLabel.f2 : KeyLabel.returnKey
        return [
            (appState.tr(.actCopyShortcut), KeyLabel.cmdC),
            (appState.tr(.actCutShortcut), KeyLabel.cmdX),
            (appState.tr(.actPasteShortcut), KeyLabel.cmdV),
            (appState.tr(.shortcutsRename), renameKey),
            (appState.tr(.actQuickLook), KeyLabel.space),
            (appState.tr(.actItemProperties), KeyLabel.cmdI),
            (appState.tr(.actNewFolderShortcut), KeyLabel.cmdShiftN),
            (appState.tr(.actMoveTrash), KeyLabel.cmdDelete)
        ]
    }

    private func systemShortcuts(for mode: NavigationMode) -> [(String, String)] {
        let hiddenKey = mode == .gnome ? KeyLabel.ctrlH : KeyLabel.cmdShiftPeriod
        return [
            (appState.tr(.actSearch), KeyLabel.cmdF),
            (appState.tr(.shortcutsToggleHidden), hiddenKey),
            (appState.tr(.actUndo), KeyLabel.cmdZ),
            (appState.tr(.actRedo), KeyLabel.cmdShiftZ),
            (appState.tr(.shortcutsToggleOverlay), KeyLabel.cmdSlash)
        ]
    }

    /// App/window-level shortcuts that don't depend on navigation mode, shown only on the "All" tab
    /// (the per-mode tabs stay focused on the shortcuts that actually differ between modes).
    private var generalShortcuts: [(String, String)] {
        [
            (appState.tr(.settingsMenuItem), KeyLabel.cmdComma),
            (appState.tr(.newWindow), KeyLabel.cmdN),
            (appState.tr(.close), KeyLabel.cmdW),
            (appState.tr(.open), KeyLabel.cmdO),
            (appState.tr(.actToggleTerminal), KeyLabel.cmdJ),
            (appState.tr(.actTogglePreview), KeyLabel.cmdShiftP),
            (appState.tr(.goToFolder), KeyLabel.cmdL),
            (appState.tr(.actConnectServer), KeyLabel.cmdK),
            (appState.tr(.actDiskVisualizer), KeyLabel.cmdShiftD),
            (appState.tr(.wilesHelpAndShortcuts), KeyLabel.cmdQuestionMark)
        ]
    }

    /// Combines the macOS- and Windows-mode variants of a shortcut group into one list for the
    /// "All" tab: identical bindings collapse to a single row, differing ones show both labeled.
    private func merged(_ macList: [(String, String)], _ windowsList: [(String, String)]) -> [(String, String)] {
        zip(macList, windowsList).map { mac, windows in
            guard mac.1 != windows.1 else { return mac }
            let macLabel = String(format: appState.tr(.shortcutMacSuffixFormat), mac.1)
            let windowsLabel = String(format: appState.tr(.shortcutWindowsSuffixFormat), windows.1)
            return (mac.0, String(format: appState.tr(.shortcutModePairSeparatorFormat), macLabel, windowsLabel))
        }
    }

    private func shortcutGroup(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 2)

            ForEach(items, id: \.0) { item in
                HStack {
                    Text(item.0)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
