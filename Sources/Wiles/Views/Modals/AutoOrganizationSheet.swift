import AppKit
import SwiftUI

struct AutoOrganizationSheet: View {
    private static let ruleLabelWidth: CGFloat = 100
    private static let ruleFolderButtonWidth: CGFloat = 220
    private static let ruleConditionPickerWidth: CGFloat = 140
    private static let ruleConditionValueFieldWidthNarrow: CGFloat = 60
    private static let ruleConditionValueFieldWidthWide: CGFloat = 140
    private static let sheetWidth: CGFloat = 600.0
    private static let sheetHeight: CGFloat = 500.0

    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState

    /// Read straight from the `@Observable` store — no local copy, no manual refresh. Updates on
    /// every add/update/delete and on background `totalMovedCount`/`lastTriggeredAt` bumps.
    private var rules: [AutoOrganizationRule] {
        AutoOrganizationService.shared.rules
    }

    // New rule state
    @State private var sourceURL: URL? = URL.userHome.appendingPathComponent("Downloads")
    @State private var destinationURL: URL? = URL.userHome.appendingPathComponent("Documents")
    @State private var conditionType: RuleConditionType = .extensionEquals
    @State private var conditionValue: String = "pdf"
    @State private var folderPickerTarget: FolderPickerTarget?
    @State private var pendingDeleteRuleID: UUID?

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("folder.badge.gearshape"),
            title: appState.tr(.autoOrganization),
            subtitle: appState.tr(.autoOrganizationSubtitle),
            width: Self.sheetWidth,
            height: Self.sheetHeight,
            primaryButton: ModalFooterButton(title: appState.tr(.done)) { dismiss() },
            content: { contentArea })
            .sheet(item: $folderPickerTarget) { target in
                FolderPickerSheet(appState: appState, initialURL: target == .source ? sourceURL : destinationURL) { url in
                    switch target {
                    case .source: sourceURL = url
                    case .destination: destinationURL = url
                    }
                }
            }
            .confirmationDialog(
                appState.tr(.deleteAutoOrgRuleConfirmMessage),
                isPresented: Binding(get: { pendingDeleteRuleID != nil }, set: {
                    if !$0 {
                        pendingDeleteRuleID = nil
                    }
                }),
                titleVisibility: .visible) {
                    Button(appState.tr(.deleteRule), role: .destructive) {
                        if let pendingDeleteRuleID {
                            AutoOrganizationService.shared.deleteRule(id: pendingDeleteRuleID)
                        }
                        pendingDeleteRuleID = nil
                    }
                    Button(appState.tr(.cancel), role: .cancel) { pendingDeleteRuleID = nil }
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
            }))
            .labelsHidden()
            .accessibilityLabel(appState.tr(.ruleEnabledToggle))
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
            Text(String(format: appState.tr(.autoOrgRuleCondition), appState.tr(rule.conditionType.l10nKey), rule.conditionValue))
                .font(.caption)
                .foregroundColor(.secondary)
            if let statusText = ruleStatusText(rule) {
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private static let lastTriggeredFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// nil when the rule has never fired, so a freshly-added rule doesn't imply activity it hasn't had yet.
    private func ruleStatusText(_ rule: AutoOrganizationRule) -> String? {
        guard let lastTriggeredAt = rule.lastTriggeredAt else { return nil }
        let date = Self.lastTriggeredFormatter.string(from: lastTriggeredAt)
        return String(format: appState.tr(.autoOrgRuleStatus), rule.totalMovedCount, date)
    }

    private func ruleDeleteButton(_ rule: AutoOrganizationRule) -> some View {
        Button {
            pendingDeleteRuleID = rule.id
        } label: {
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appState.tr(.deleteRule))
    }

    private var newRuleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.tr(.addNewRule))
                .font(.headline)
            newRuleConditionRow
            newRuleDestinationRow
            Text(appState.tr(.autoOrgRuleConflictNotice))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(appState.tr(.autoOrgNoUndoNotice))
                .font(.caption)
                .foregroundColor(.secondary)
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
            .accessibilityLabel(appState.tr(.ifFileIn))

            Picker("", selection: $conditionType) {
                ForEach(RuleConditionType.allCases) { type in
                    Text(appState.tr(type.l10nKey)).tag(type)
                }
            }
            .frame(width: Self.ruleConditionPickerWidth)
            .accessibilityLabel(appState.tr(.ruleConditionTypePicker))

            TextField(appState.tr(.ruleValuePlaceholder), text: $conditionValue)
                .textFieldStyle(.roundedBorder)
                .frame(width: ruleConditionValueFieldWidth)
                .onSubmit(addRule)
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
            .accessibilityLabel(appState.tr(.moveTo))

            Spacer()

            Button(appState.tr(.addRule)) {
                addRule()
            }
            .disabled(!canAddRule)
        }
    }

    /// `.extensionEquals` values are short ("pdf"); name-matching conditions need more room.
    private var ruleConditionValueFieldWidth: CGFloat {
        conditionType == .extensionEquals ? Self.ruleConditionValueFieldWidthNarrow : Self.ruleConditionValueFieldWidthWide
    }

    private var canAddRule: Bool {
        guard let sourceURL, let destinationURL else { return false }
        // Match `AutoOrganizationRule.init`'s own normalization (`resolvingSymlinksInPath()`), so a
        // source/dest pair that only differs by a symlink can't slip past this and then be created
        // as a self-referential rule.
        guard sourceURL.resolvingSymlinksInPath() != destinationURL.resolvingSymlinksInPath() else { return false }
        return !conditionValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addRule() {
        guard canAddRule, let src = sourceURL, let dest = destinationURL else { return }
        var trimmedValue = conditionValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if conditionType == .extensionEquals, trimmedValue.hasPrefix(".") {
            trimmedValue.removeFirst()
        }
        let rule = AutoOrganizationRule(sourceURL: src, destinationURL: dest, conditionType: conditionType, conditionValue: trimmedValue)
        AutoOrganizationService.shared.addRule(rule)
        conditionValue = ""
    }
}
