import SwiftUI
import AppKit

struct AutoOrganizationSheet: View {
    @Environment(\.dismiss) private var dismiss
    var appState: AppState
    
    @State private var rules: [AutoOrganizationRule] = []
    
    // New rule state
    @State private var sourceURL: URL? = URL.userHome.appendingPathComponent("Downloads")
    @State private var destinationURL: URL? = URL.userHome.appendingPathComponent("Documents")
    @State private var conditionType: RuleConditionType = .extensionEquals
    @State private var conditionValue: String = "pdf"
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            
            VStack(spacing: 20) {
                if rules.isEmpty {
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
            
            Divider()
            footerView
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            rules = AutoOrganizationService.shared.rules
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "folder.badge.gearshape")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
            Text(appState.tr(.autoOrganization))
                .font(.headline)
            Spacer()
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    private func ruleRow(_ rule: AutoOrganizationRule) -> some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { newVal in
                    var updated = rule
                    updated.isEnabled = newVal
                    AutoOrganizationService.shared.updateRule(updated)
                    rules = AutoOrganizationService.shared.rules
                }
            ))
            .labelsHidden()
            
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
                Text("If \(rule.conditionType.rawValue) is '\(rule.conditionValue)'")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                AutoOrganizationService.shared.deleteRule(id: rule.id)
                rules = AutoOrganizationService.shared.rules
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
    
    private var newRuleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(appState.tr(.addNewRule))
                .font(.headline)
            
            HStack {
                Text(appState.tr(.ifFileIn))
                    .frame(width: 100, alignment: .trailing)
                
                Button(sourceURL?.lastPathComponent ?? appState.tr(.selectFolder)) {
                    sourceURL = selectFolder()
                }
                .frame(width: 120)
                
                Picker("", selection: $conditionType) {
                    ForEach(RuleConditionType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .frame(width: 140)
                
                TextField(appState.tr(.ruleValuePlaceholder), text: $conditionValue)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text(appState.tr(.moveTo))
                    .frame(width: 100, alignment: .trailing)
                Button(destinationURL?.lastPathComponent ?? appState.tr(.selectFolder)) {
                    destinationURL = selectFolder()
                }
                .frame(width: 120)
                
                Spacer()
                
                Button(appState.tr(.addRule)) {
                    guard let src = sourceURL, let dest = destinationURL, !conditionValue.isEmpty else { return }
                    let rule = AutoOrganizationRule(sourceURL: src, destinationURL: dest, conditionType: conditionType, conditionValue: conditionValue)
                    AutoOrganizationService.shared.addRule(rule)
                    rules = AutoOrganizationService.shared.rules
                    conditionValue = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourceURL == nil || destinationURL == nil || conditionValue.isEmpty)
            }
        }
        .padding(12)
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
    
    private func selectFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            return panel.url
        }
        return nil
    }
}
