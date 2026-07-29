import SwiftUI

enum RenameTabMode: String, CaseIterable, Identifiable {
    case findReplace = "Find & Replace"
    case prefixSuffix = "Prefix & Suffix"
    case sequence = "Sequence"
    
    var id: String { rawValue }
}

struct BatchRenameSheetView: View {
    let items: [FileItem]
    var appState: AppState
    
    @Environment(\.dismiss) private var dismiss
    @State private var tabMode: RenameTabMode = .findReplace
    
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    
    @State private var prefixText: String = ""
    @State private var suffixText: String = ""
    
    @State private var sequencePrefix: String = "file"
    @State private var startNumber: Int = 1
    @State private var paddingDigits: Int = 3
    
    private var currentMode: BatchRenameMode {
        switch tabMode {
        case .findReplace:
            return .replace(find: findText, replaceWith: replaceText)
        case .prefixSuffix:
            return .addPrefixSuffix(prefix: prefixText, suffix: suffixText)
        case .sequence:
            return .sequenceNumber(prefix: sequencePrefix, startNumber: startNumber, paddingDigits: paddingDigits)
        }
    }
    
    private var previews: [(original: FileItem, newName: String)] {
        BatchRenameService.previewNewNames(items: items, mode: currentMode)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(appState.tr(.batchRename)) (\(items.count))")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
            }
            
            Picker("", selection: $tabMode) {
                Text(appState.tr(.find)).tag(RenameTabMode.findReplace)
                Text(appState.tr(.prefix)).tag(RenameTabMode.prefixSuffix)
                Text(appState.tr(.sequenceNumbering)).tag(RenameTabMode.sequence)
            }
            .pickerStyle(.segmented)
            
            modeInputView
            
            Divider()
            
            Text(appState.tr(.preview))
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(previews, id: \.original.url) { pair in
                        HStack {
                            Text(pair.original.name)
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text(pair.newName)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(pair.original.name == pair.newName ? .secondary : .accentColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                }
            }
            .frame(height: 140)
            
            HStack(spacing: 12) {
                Spacer()
                Button(appState.tr(.cancel)) {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Button(appState.tr(.apply)) {
                    appState.performBatchRename(items: items, mode: currentMode)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(20)
        .frame(width: 480, height: 380)
    }
    
    @ViewBuilder
    private var modeInputView: some View {
        switch tabMode {
        case .findReplace:
            HStack(spacing: 12) {
                TextField(appState.tr(.find), text: $findText)
                    .textFieldStyle(.roundedBorder)
                TextField(appState.tr(.replaceWith), text: $replaceText)
                    .textFieldStyle(.roundedBorder)
            }
        case .prefixSuffix:
            HStack(spacing: 12) {
                TextField(appState.tr(.prefix), text: $prefixText)
                    .textFieldStyle(.roundedBorder)
                TextField(appState.tr(.suffix), text: $suffixText)
                    .textFieldStyle(.roundedBorder)
            }
        case .sequence:
            HStack(spacing: 12) {
                TextField(appState.tr(.prefix), text: $sequencePrefix)
                    .textFieldStyle(.roundedBorder)
                HStack(spacing: 4) {
                    Text(appState.tr(.startNumber) + ":")
                        .font(.system(size: 12))
                    Stepper("\(startNumber)", value: $startNumber, in: 0...9999)
                }
            }
        }
    }
}
