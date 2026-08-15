import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct HelpSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    @State private var selectedTab: HelpTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .overview:
                        overviewSection
                        navigationModesSection
                        sidebarAndTagsSection
                    case .features:
                        featureHighlightsSection
                    case .system:
                        navigationAndSystemSection
                    }
                }
                .padding(20)
            }

            Divider()
            footerView
        }
        .frame(width: 660, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .folder))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.tr(.wilesFileManager))
                        .font(.system(size: 16, weight: .bold))
                    Text(appState.tr(.helpGuideTitle))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Picker("", selection: $selectedTab) {
                ForEach(HelpTab.allCases) { tab in
                    Text(tab.title(appState: appState)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 500)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.tabOverview))
                .font(.system(size: 14, weight: .semibold))
            Text(appState.tr(.overviewDesc))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var featureHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.tr(.domainToolsTitle))
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 8) {
                featureRow(icon: "tag.fill", title: appState.tr(.helpTagsTitle), desc: appState.tr(.helpTagsDesc))
                featureRow(icon: "terminal.fill", title: appState.tr(.helpTerminalTitle), desc: appState.tr(.helpTerminalDesc))
                featureRow(icon: "doc.zipper", title: appState.tr(.helpZipTitle), desc: appState.tr(.helpZipDesc))
                featureRow(icon: "chart.pie.fill", title: appState.tr(.helpDiskTitle), desc: appState.tr(.helpDiskDesc))
                featureRow(icon: "photo.stack.fill", title: appState.tr(.helpImageTitle), desc: appState.tr(.helpImageDesc))
                featureRow(icon: "textformat.123", title: appState.tr(.helpBatchTitle), desc: appState.tr(.helpBatchDesc))
                featureRow(icon: "link", title: appState.tr(.helpSymlinkTitle), desc: appState.tr(.helpSymlinkDesc))
                featureRow(icon: "doc.badge.plus", title: appState.tr(.helpTemplateTitle), desc: appState.tr(.helpTemplateDesc))
                featureRow(icon: "doc.on.clipboard", title: appState.tr(.helpCopyContentTitle), desc: appState.tr(.helpCopyContentDesc))
                featureRow(icon: "trash.slash.fill", title: appState.tr(.helpShredTitle), desc: appState.tr(.helpShredDesc))
                featureRow(icon: "network", title: appState.tr(.helpServerTitle), desc: appState.tr(.helpServerDesc))
                featureRow(icon: "wifi", title: appState.tr(.helpWifiShareTitle), desc: appState.tr(.helpWifiShareDesc))
                featureRow(icon: "wand.and.stars", title: appState.tr(.helpAutoOrgTitle), desc: appState.tr(.helpAutoOrgDesc))
            }
        }
    }

    private var navigationAndSystemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.tr(.navSystemTitle))
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 8) {
                featureRow(icon: "arrow.uturn.backward.circle.fill", title: appState.tr(.helpUndoTitle), desc: appState.tr(.helpUndoDesc))
                featureRow(icon: "sidebar.right", title: appState.tr(.helpPreviewTitle), desc: appState.tr(.helpPreviewDesc))
                featureRow(icon: "folder.badge.gearshape", title: appState.tr(.helpViewModeMemoryTitle), desc: appState.tr(.helpViewModeMemoryDesc))
                featureRow(icon: "signpost.right.fill", title: appState.tr(.helpPathBarTitle), desc: appState.tr(.helpPathBarDesc))
                featureRow(icon: "slider.horizontal.3", title: appState.tr(.helpTranslucentTitle), desc: appState.tr(.helpTranslucentDesc))
            }
        }
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }

    private var sidebarAndTagsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.sidebarMode))
                .font(.system(size: 14, weight: .semibold))
            Text(appState.tr(.helpTranslucentDesc))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var navigationModesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(appState.tr(.navProfilesTitle))
                .font(.system(size: 14, weight: .semibold))
            navigationModeCards
        }
    }

    private var navigationModeCards: some View {
        HStack(alignment: .top, spacing: 12) {
            navModeCard(title: appState.tr(.gnomeModeTitle), desc: appState.tr(.gnomeModeDesc))
            navModeCard(title: appState.tr(.macModeTitle), desc: appState.tr(.macModeDesc))
        }
    }

    private func navModeCard(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var footerView: some View {
        HStack {
            Spacer()
            Button(appState.tr(.done)) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.large)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
