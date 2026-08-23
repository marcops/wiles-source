import AppKit
import SwiftUI

struct ShortcutsHUDOverlay: View {
    private static let backdropOpacity: Double = 0.3

    private static let cardSpacing: CGFloat = 16
    private static let cardHorizontalPadding: CGFloat = 20
    private static let cardTopPadding: CGFloat = 20
    private static let cardBottomPadding: CGFloat = 20
    private static let cardMinWidth: CGFloat = 350
    private static let cardMaxWidth: CGFloat = 450
    private static let cardMinHeight: CGFloat = 390
    private static let cardMaxHeight: CGFloat = 510
    private static let cardBackgroundOpacity: Double = 0.85
    private static let cardCornerRadius: CGFloat = 16
    private static let cardBorderOpacity: Double = 0.1
    private static let cardBorderLineWidth: CGFloat = 1
    private static let cardShadowOpacity: Double = 0.25
    private static let cardShadowRadius: CGFloat = 15
    private static let cardShadowOffsetY: CGFloat = 8

    private static let headerIconFontSize: CGFloat = 18
    private static let headerTitleFontSize: CGFloat = 16
    private static let headerSubtitleFontSize: CGFloat = 11
    private static let headerTextSpacing: CGFloat = 2

    private static let tabRowSpacing: CGFloat = 8
    private static let tabLabelFontSize: CGFloat = 11
    private static let tabBadgeFontSize: CGFloat = 8
    private static let tabBadgeHorizontalPadding: CGFloat = 5
    private static let tabBadgeVerticalPadding: CGFloat = 2
    private static let tabBadgeBackgroundOpacity: Double = 0.25
    private static let tabBadgeCornerRadius: CGFloat = 4
    private static let tabContentSpacing: CGFloat = 5
    private static let tabHorizontalPadding: CGFloat = 10
    private static let tabVerticalPadding: CGFloat = 5
    private static let tabSelectedBackgroundOpacity: Double = 0.2
    private static let tabUnselectedBackgroundOpacity: Double = 0.08
    private static let tabCornerRadius: CGFloat = 8

    private static let columnsOuterSpacing: CGFloat = 12
    private static let columnsLeadingPadding: CGFloat = 20
    private static let columnsTrailingPadding: CGFloat = 12

    private static let groupTitleFontSize: CGFloat = 9
    private static let groupTitleTopPadding: CGFloat = 4
    private static let groupTitleBottomPadding: CGFloat = 2
    private static let groupItemSpacing: CGFloat = 6

    private static let shortcutLabelFontSize: CGFloat = 12
    private static let keyLabelFontSize: CGFloat = 11
    private static let keyLabelHorizontalPadding: CGFloat = 6
    private static let keyLabelVerticalPadding: CGFloat = 2
    private static let keyLabelBackgroundOpacity: Double = 0.12
    private static let keyLabelCornerRadius: CGFloat = 4

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
            Color.black.opacity(Self.backdropOpacity)
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
        VStack(spacing: Self.cardSpacing) {
            header
                .padding(.horizontal, Self.cardHorizontalPadding)
                .padding(.top, Self.cardTopPadding)
            modeTabRow
                .padding(.horizontal, Self.cardHorizontalPadding)
            Divider()
            shortcutColumns
            Divider()
            footer
                .padding(.horizontal, Self.cardHorizontalPadding)
                .padding(.bottom, Self.cardBottomPadding)
        }
        .frame(minWidth: Self.cardMinWidth, maxWidth: Self.cardMaxWidth, minHeight: Self.cardMinHeight, maxHeight: Self.cardMaxHeight)
        .background(
            ZStack {
                TranslucentVisualEffectView(material: .hudWindow)
                Color(NSColor.windowBackgroundColor).opacity(Self.cardBackgroundOpacity)
            })
        // A single `.clipShape` for the whole composited card (content + background layers)
        // instead of separate `.cornerRadius()` calls on each background layer — mismatched
        // per-layer corner clipping is what caused the rounded top area (where the header sits)
        // to render inconsistently against the rest of the card.
        .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cardCornerRadius)
                .stroke(Color.primary.opacity(Self.cardBorderOpacity), lineWidth: Self.cardBorderLineWidth))
        .shadow(color: Color.black.opacity(Self.cardShadowOpacity), radius: Self.cardShadowRadius, x: 0, y: Self.cardShadowOffsetY)
    }

    private var header: some View {
        HStack {
            Image(systemName: "keyboard")
                .font(.system(size: Self.headerIconFontSize, weight: .bold))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
                Text(appState.tr(.shortcutsCheatsheetTitle))
                    .font(.system(size: Self.headerTitleFontSize, weight: .bold))
                Text(appState.tr(.shortcutsCheatsheetSubtitle))
                    .font(.system(size: Self.headerSubtitleFontSize))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var modeTabRow: some View {
        HStack(spacing: Self.tabRowSpacing) {
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
            HStack(spacing: Self.tabContentSpacing) {
                Text(appState.tr(filter.l10nKey))
                    .font(.system(size: Self.tabLabelFontSize, weight: .semibold))
                if isActual {
                    Text(appState.tr(.shortcutsCurrentModeBadge).uppercased())
                        .font(.system(size: Self.tabBadgeFontSize, weight: .bold))
                        .padding(.horizontal, Self.tabBadgeHorizontalPadding)
                        .padding(.vertical, Self.tabBadgeVerticalPadding)
                        .background(Color.accentColor.opacity(Self.tabBadgeBackgroundOpacity))
                        .cornerRadius(Self.tabBadgeCornerRadius)
                }
            }
            .padding(.horizontal, Self.tabHorizontalPadding)
            .padding(.vertical, Self.tabVerticalPadding)
            .background(isSelected ? Color.accentColor.opacity(Self.tabSelectedBackgroundOpacity) : Color.secondary
                .opacity(Self.tabUnselectedBackgroundOpacity))
            .foregroundColor(isSelected ? Color.accentColor : Color.primary)
            .cornerRadius(Self.tabCornerRadius)
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
            VStack(spacing: Self.columnsOuterSpacing) {
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
            .padding(.leading, Self.columnsLeadingPadding)
            .padding(.trailing, Self.columnsTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    /// Keeps `L10n.Key` (not resolved text) so `merged` can match entries by stable identity, not position.
    private func navigationShortcuts(for mode: NavigationMode) -> [(L10n.Key, String)] {
        if mode == .macOS {
            [
                (.actNavBackForward, KeyLabel.cmdBracketNavigation),
                (.actParentFolder, KeyLabel.cmdUpArrow),
                (.shortcutsOpenFolder, KeyLabel.cmdDownArrow)
            ]
        } else {
            [
                (.actNavBackForward, KeyLabel.cmdBracketNavigation),
                (.actParentFolder, KeyLabel.backspace),
                (.shortcutsOpenFolder, KeyLabel.enter)
            ]
        }
    }

    private func fileActionsShortcuts(for mode: NavigationMode) -> [(L10n.Key, String)] {
        let renameKey = mode == .gnome ? KeyLabel.f2 : KeyLabel.returnKey
        return [
            (.actCopyShortcut, KeyLabel.cmdC),
            (.actCutShortcut, KeyLabel.cmdX),
            (.actPasteShortcut, KeyLabel.cmdV),
            (.shortcutsRename, renameKey),
            (.actQuickLook, KeyLabel.space),
            (.actItemProperties, KeyLabel.cmdI),
            (.actNewFolderShortcut, KeyLabel.cmdShiftN),
            (.actMoveTrash, KeyLabel.cmdDelete)
        ]
    }

    private func systemShortcuts(for mode: NavigationMode) -> [(L10n.Key, String)] {
        let hiddenKey = mode == .gnome ? KeyLabel.ctrlH : KeyLabel.cmdShiftPeriod
        return [
            (.actSearch, KeyLabel.cmdF),
            (.shortcutsToggleHidden, hiddenKey),
            (.actUndo, KeyLabel.cmdZ),
            (.actRedo, KeyLabel.cmdShiftZ),
            (.shortcutsToggleOverlay, KeyLabel.cmdSlash)
        ]
    }

    /// App/window-level shortcuts that don't depend on navigation mode, shown only on the "All" tab
    /// (the per-mode tabs stay focused on the shortcuts that actually differ between modes).
    private var generalShortcuts: [(L10n.Key, String)] {
        [
            (.settingsMenuItem, KeyLabel.cmdComma),
            (.newWindow, KeyLabel.cmdN),
            (.close, KeyLabel.cmdW),
            (.open, KeyLabel.cmdO),
            (.actToggleTerminal, KeyLabel.cmdJ),
            (.actTogglePreview, KeyLabel.cmdShiftP),
            (.goToFolder, KeyLabel.cmdL),
            (.actConnectServer, KeyLabel.cmdK),
            (.actDiskVisualizer, KeyLabel.cmdShiftD),
            (.wilesHelpAndShortcuts, KeyLabel.cmdQuestionMark)
        ]
    }

    /// Merges macOS/Windows variants for the "All" tab, matching by `L10n.Key` (not `zip` position) so a length/order drift can't silently mispair actions.
    private func merged(_ macList: [(L10n.Key, String)], _ windowsList: [(L10n.Key, String)]) -> [(L10n.Key, String)] {
        let windowsByKey = Dictionary(windowsList, uniquingKeysWith: { first, _ in first })
        return macList.compactMap { mac in
            guard let windowsKeyLabel = windowsByKey[mac.0] else { return mac }
            guard mac.1 != windowsKeyLabel else { return mac }
            let macLabel = String(format: appState.tr(.shortcutMacSuffixFormat), mac.1)
            let windowsLabel = String(format: appState.tr(.shortcutWindowsSuffixFormat), windowsKeyLabel)
            return (mac.0, String(format: appState.tr(.shortcutModePairSeparatorFormat), macLabel, windowsLabel))
        }
    }

    private func shortcutGroup(title: String, items: [(L10n.Key, String)]) -> some View {
        VStack(alignment: .leading, spacing: Self.groupItemSpacing) {
            Text(title.uppercased())
                .font(.system(size: Self.groupTitleFontSize, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, Self.groupTitleTopPadding)
                .padding(.bottom, Self.groupTitleBottomPadding)

            ForEach(items, id: \.0) { item in
                HStack {
                    Text(appState.tr(item.0))
                        .font(.system(size: Self.shortcutLabelFontSize))
                        .foregroundColor(.primary)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: Self.keyLabelFontSize, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, Self.keyLabelHorizontalPadding)
                        .padding(.vertical, Self.keyLabelVerticalPadding)
                        .background(Color.secondary.opacity(Self.keyLabelBackgroundOpacity))
                        .cornerRadius(Self.keyLabelCornerRadius)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
