import AppKit
import SwiftUI

struct AutoOrganizationSheet: View {
    private static let ruleLabelWidth: CGFloat = 100
    private static let ruleFolderButtonWidth: CGFloat = 220
    private static let ruleConditionPickerWidth: CGFloat = 140
    private static let ruleConditionValueFieldWidth: CGFloat = 60

    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState

    @State private var rules: [AutoOrganizationRule] = []

    // New rule state
    @State private var sourceURL: URL? = URL.userHome.appendingPathComponent("Downloads")
    @State private var destinationURL: URL? = URL.userHome.appendingPathComponent("Documents")
    @State private var conditionType: RuleConditionType = .extensionEquals
    @State private var conditionValue: String = "pdf"
    @State private var folderPickerTarget: FolderPickerTarget?

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("folder.badge.gearshape"),
            title: appState.tr(.autoOrganization),
            subtitle: appState.tr(.autoOrganizationSubtitle),
            width: LayoutTokens.autoOrganizationSheetWidth,
            height: LayoutTokens.autoOrganizationSheetHeight,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            content: { contentArea })
            .onAppear {
                refreshRules()
            }
            .sheet(item: $folderPickerTarget) { target in
                FolderPickerSheet(appState: appState, initialURL: target == .source ? sourceURL : destinationURL) { url in
                    switch target {
                    case .source: sourceURL = url
                    case .destination: destinationURL = url
                    }
                }
            }
    }

    private var contentArea: some View {
        VStack(spacing: 20) {
            if rules.isEmpty {
                emptyRulesView
            } else {
                List {
                    ForEach(rules) { rule in
                        ruleRow(rule)
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            newRuleSection
        }
        .padding(20)
    }

    private var emptyRulesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(appState.tr(.noAutoOrgRules))
                .font(.headline)
            Text(appState.tr(.noAutoOrgRulesDesc))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ruleRow(_ rule: AutoOrganizationRule) -> some View {
        HStack {
            ruleEnabledToggle(rule)
            ruleSummary(rule)
            Spacer()
            ruleDeleteButton(rule)
        }
        .padding(.vertical, 4)
    }

    private func ruleEnabledToggle(_ rule: AutoOrganizationRule) -> some View {
        Toggle("", isOn: Binding(
            get: { rule.isEnabled },
            set: { newVal in
                var updated = rule
                updated.isEnabled = newVal
                AutoOrganizationService.shared.updateRule(updated)
                refreshRules()
            }))
            .labelsHidden()
    }

    private func ruleSummary(_ rule: AutoOrganizationRule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                Text(rule.sourceURL.lastPathComponent)
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                Image(systemName: "folder")
                    .foregroundColor(.green)
                Text(rule.destinationURL.lastPathComponent)
                    .fontWeight(.semibold)
            }
            Text(String(format: appState.tr(.autoOrgRuleCondition), displayName(for: rule.conditionType), rule.conditionValue))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func ruleDeleteButton(_ rule: AutoOrganizationRule) -> some View {
        Button {
            AutoOrganizationService.shared.deleteRule(id: rule.id)
            refreshRules()
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
    }

    private var newRuleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.tr(.addNewRule))
                .font(.headline)
            newRuleConditionRow
            newRuleDestinationRow
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var newRuleConditionRow: some View {
        HStack {
            Text(appState.tr(.ifFileIn))
                .frame(width: Self.ruleLabelWidth, alignment: .trailing)

            Button {
                folderPickerTarget = .source
            } label: {
                HStack {
                    Text(sourceURL?.lastPathComponent ?? appState.tr(.selectFolder))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: Self.ruleFolderButtonWidth)

            Picker("", selection: $conditionType) {
                ForEach(RuleConditionType.allCases) { type in
                    Text(displayName(for: type)).tag(type)
                }
            }
            .frame(width: Self.ruleConditionPickerWidth)

            TextField(appState.tr(.ruleValuePlaceholder), text: $conditionValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: Self.ruleConditionValueFieldWidth)
        }
    }

    private var newRuleDestinationRow: some View {
        HStack {
            Text(appState.tr(.moveTo))
                .frame(width: Self.ruleLabelWidth, alignment: .trailing)
            Button {
                folderPickerTarget = .destination
            } label: {
                HStack {
                    Text(destinationURL?.lastPathComponent ?? appState.tr(.selectFolder))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                }
            }
            .frame(width: Self.ruleFolderButtonWidth)

            Spacer()

            Button(appState.tr(.addRule)) {
                addRule()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAddRule)
        }
    }

    private var canAddRule: Bool {
        sourceURL != nil && destinationURL != nil && !conditionValue.isEmpty
    }

    private func addRule() {
        guard canAddRule, let src = sourceURL, let dest = destinationURL else { return }
        let rule = AutoOrganizationRule(sourceURL: src, destinationURL: dest, conditionType: conditionType, conditionValue: conditionValue)
        AutoOrganizationService.shared.addRule(rule)
        refreshRules()
        conditionValue = ""
    }

    private func refreshRules() {
        rules = AutoOrganizationService.shared.rules
    }

    /// `RuleConditionType.rawValue` is the persisted/matched identifier (`Codable`), always
    /// English — never display it directly. This maps each case to its localized display string.
    private func displayName(for type: RuleConditionType) -> String {
        switch type {
        case .extensionEquals: appState.tr(.ruleConditionExtensionEquals)
        case .nameContains: appState.tr(.ruleConditionNameContains)
        case .namePrefix: appState.tr(.ruleConditionNamePrefix)
        }
    }
}
