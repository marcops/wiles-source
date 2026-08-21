import SwiftUI

struct HelpSheet: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    @State private var selectedTab: HelpTab = .overview

    private static let domainToolsItems: [FeatureHelpItem] = [
        FeatureHelpItem(icon: "tag.fill", titleKey: .helpTagsTitle, descKey: .helpTagsDesc),
        FeatureHelpItem(icon: "terminal.fill", titleKey: .helpTerminalTitle, descKey: .helpTerminalDesc),
        FeatureHelpItem(icon: "doc.zipper", titleKey: .helpZipTitle, descKey: .helpZipDesc),
        FeatureHelpItem(icon: "chart.pie.fill", titleKey: .helpDiskTitle, descKey: .helpDiskDesc),
        FeatureHelpItem(icon: "photo.stack.fill", titleKey: .helpImageTitle, descKey: .helpImageDesc),
        FeatureHelpItem(icon: "textformat.123", titleKey: .helpBatchTitle, descKey: .helpBatchDesc),
        FeatureHelpItem(icon: "link", titleKey: .helpSymlinkTitle, descKey: .helpSymlinkDesc),
        FeatureHelpItem(icon: "doc.badge.plus", titleKey: .helpTemplateTitle, descKey: .helpTemplateDesc),
        FeatureHelpItem(icon: "doc.on.clipboard", titleKey: .helpCopyContentTitle, descKey: .helpCopyContentDesc),
        FeatureHelpItem(icon: "trash.slash.fill", titleKey: .helpShredTitle, descKey: .helpShredDesc),
        FeatureHelpItem(icon: "network", titleKey: .helpServerTitle, descKey: .helpServerDesc),
        FeatureHelpItem(icon: "wifi", titleKey: .helpWifiShareTitle, descKey: .helpWifiShareDesc),
        FeatureHelpItem(icon: "wand.and.stars", titleKey: .helpAutoOrgTitle, descKey: .helpAutoOrgDesc)
    ]

    private static let navigationAndSystemItems: [FeatureHelpItem] = [
        FeatureHelpItem(icon: "arrow.uturn.backward.circle.fill", titleKey: .helpUndoTitle, descKey: .helpUndoDesc),
        FeatureHelpItem(icon: "sidebar.right", titleKey: .helpPreviewTitle, descKey: .helpPreviewDesc),
        FeatureHelpItem(icon: "folder.badge.gearshape", titleKey: .helpViewModeMemoryTitle, descKey: .helpViewModeMemoryDesc),
        FeatureHelpItem(icon: "signpost.right.fill", titleKey: .helpPathBarTitle, descKey: .helpPathBarDesc),
        FeatureHelpItem(icon: "slider.horizontal.3", titleKey: .helpTranslucentTitle, descKey: .helpTranslucentDesc)
    ]

    var body: some View {
        ModalScaffoldView(
            icon: .appIcon,
            title: appState.tr(.wilesFileManager),
            subtitle: appState.tr(.helpGuideTitle),
            width: 660,
            height: 580,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            headerAccessory: { tabPicker },
            content: { scrollableContent })
    }

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(HelpTab.allCases) { tab in
                Text(tab.title(appState: appState)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 500)
    }

    private var scrollableContent: some View {
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
                ForEach(Self.domainToolsItems) { item in
                    featureRow(item)
                }
            }
        }
    }

    private var navigationAndSystemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.tr(.navSystemTitle))
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 8) {
                ForEach(Self.navigationAndSystemItems) { item in
                    featureRow(item)
                }
            }
        }
    }

    private func featureRow(_ item: FeatureHelpItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(item.titleKey))
                    .font(.system(size: 12, weight: .bold))
                Text(appState.tr(item.descKey))
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
            Text(appState.tr(.helpTagsDesc))
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

    /// One row's data in the "Features" / "System" help tabs — icon plus title/description localization keys.
    private struct FeatureHelpItem: Identifiable {
        let id: L10n.Key
        let icon: String
        let titleKey: L10n.Key
        let descKey: L10n.Key

        init(icon: String, titleKey: L10n.Key, descKey: L10n.Key) {
            id = titleKey
            self.icon = icon
            self.titleKey = titleKey
            self.descKey = descKey
        }
    }
}
