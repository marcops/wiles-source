import AppKit
import SwiftUI

struct AutoOrganizationSheet: View {
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
        VStack(spacing: 0) {
            headerView
            Divider()
            contentArea
            Divider()
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            rules = AutoOrganizationService.shared.rules
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

    private var headerView: some View {
        HStack {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.autoOrganization))
                    .font(.headline)
                Text(appState.tr(.autoOrganizationSubtitle))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
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
                rules = AutoOrganizationService.shared.rules
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
            rules = AutoOrganizationService.shared.rules
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
                .frame(width: 100, alignment: .trailing)

            Button(sourceURL?.lastPathComponent ?? appState.tr(.selectFolder)) {
                folderPickerTarget = .source
            }
            .frame(width: 120)

            Picker("", selection: $conditionType) {
                ForEach(RuleConditionType.allCases) { type in
                    Text(displayName(for: type)).tag(type)
                }
            }
            .frame(width: 140)

            TextField(appState.tr(.ruleValuePlaceholder), text: $conditionValue)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var newRuleDestinationRow: some View {
        HStack {
            Text(appState.tr(.moveTo))
                .frame(width: 100, alignment: .trailing)
            Button(destinationURL?.lastPathComponent ?? appState.tr(.selectFolder)) {
                folderPickerTarget = .destination
            }
            .frame(width: 120)

            Spacer()

            Button(appState.tr(.addRule)) {
                addRule()
            }
            .buttonStyle(.borderedProminent)
            .disabled(sourceURL == nil || destinationURL == nil || conditionValue.isEmpty)
        }
    }

    private func addRule() {
        guard let src = sourceURL, let dest = destinationURL, !conditionValue.isEmpty else { return }
        let rule = AutoOrganizationRule(sourceURL: src, destinationURL: dest, conditionType: conditionType, conditionValue: conditionValue)
        AutoOrganizationService.shared.addRule(rule)
        rules = AutoOrganizationService.shared.rules
        conditionValue = ""
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
