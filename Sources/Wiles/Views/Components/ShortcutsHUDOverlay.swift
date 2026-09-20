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

    /// Always the complete, current list — every group shown together, each shortcut's key reading
    /// straight off whatever's actually bound right now (Windows preset, Mac preset, or a Custom
    /// user's own edits). No tabs, no per-mode merging: there's only ever one live combo per command.
    private var shortcutColumns: some View {
        ScrollView {
            VStack(spacing: Self.columnsOuterSpacing) {
                shortcutGroup(title: appState.tr(.shortcutsNav), items: navigationShortcuts)
                shortcutGroup(title: appState.tr(.shortcutsFileActions), items: fileActionsShortcuts)
                shortcutGroup(title: appState.tr(.shortcutsSystem), items: systemShortcuts)
                shortcutGroup(title: appState.tr(.shortcutsGeneral), items: generalShortcuts)
            }
            .padding(.leading, Self.columnsLeadingPadding)
            .padding(.trailing, Self.columnsTrailingPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private typealias Command = ShortcutRegistry.Command

    private var activeShortcuts: [Command: ShortcutBinding] {
        appState.preferences.view.activeShortcutsByCommand
    }

    private func label(_ command: Command) -> String {
        ShortcutRegistry.label(command, in: activeShortcuts)
    }

    private var backForwardLabel: String {
        "\(label(.goBack))  /  \(label(.goForward))"
    }

    private var navigationShortcuts: [(L10n.Key, String)] {
        [
            (.actNavBackForward, backForwardLabel),
            (.actParentFolder, label(.enclosingFolder)),
            (.shortcutsOpenFolder, label(.openSelected))
        ]
    }

    private var fileActionsShortcuts: [(L10n.Key, String)] {
        [
            (.actCopyShortcut, label(.copy)),
            (.actCutShortcut, label(.cut)),
            (.actPasteShortcut, label(.paste)),
            (.shortcutsSelectAll, label(.selectAll)),
            (.shortcutsRename, label(.quickRename)),
            (.actQuickLook, label(.quickLook)),
            (.actItemProperties, label(.properties)),
            (.actNewFolderShortcut, label(.newFolder)),
            (.shortcutsNewFile, label(.newFile)),
            (.actMoveTrash, label(.moveToTrash))
        ]
    }

    private var systemShortcuts: [(L10n.Key, String)] {
        [
            (.actSearch, label(.find)),
            (.shortcutsToggleHidden, label(.toggleHiddenFiles)),
            (.actUndo, label(.undo)),
            (.actRedo, label(.redo)),
            (.shortcutsToggleOverlay, label(.shortcutsHUD))
        ]
    }

    /// App/window-level shortcuts that don't depend on the anchor selection.
    private var generalShortcuts: [(L10n.Key, String)] {
        [
            (.settingsMenuItem, label(.settings)),
            (.newWindow, label(.newWindow)),
            (.close, label(.closeWindow)),
            (.open, label(.open)),
            (.actToggleTerminal, label(.toggleTerminal)),
            (.actTogglePreview, label(.togglePreview)),
            (.goToFolder, label(.goToFolder)),
            (.actConnectServer, label(.connectToServer)),
            (.actDiskVisualizer, label(.toggleDiskUsage)),
            (.wilesHelpAndShortcuts, label(.help))
        ]
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
