import SwiftUI

struct BatchRenameSheetView: View {
    let items: [FileItem]
    var appState: AppState

    @Environment(\.dismiss)
    private var dismiss
    @State private var tabMode: RenameTabMode = .findReplace

    @State private var findText: String = ""
    @State private var replaceText: String = ""

    @State private var prefixText: String = ""
    @State private var suffixText: String = ""

    @State private var sequencePrefix: String = "file"
    @State private var startNumber: Int = 1
    @State private var paddingDigits: Int = 3

    @State private var regexPattern: String = ""
    @State private var regexTemplate: String = ""

    private var currentMode: BatchRenameMode {
        switch tabMode {
        case .findReplace:
            .replace(find: findText, replaceWith: replaceText)
        case .prefixSuffix:
            .addPrefixSuffix(prefix: prefixText, suffix: suffixText)
        case .sequence:
            .sequenceNumber(prefix: sequencePrefix, startNumber: startNumber, paddingDigits: paddingDigits)
        case .regex:
            .regex(pattern: regexPattern, template: regexTemplate)
        }
    }

    /// Recomputed off `body` by the `.task(id: currentMode)` below (debounced), not synchronously on
    /// every keystroke — a large selection in `.regex` mode makes `previewNewNames` expensive.
    @State private var previews: [(original: FileItem, newName: String)] = []
    /// Set when "Apply" is pressed but the current preview would collide — shown inline
    /// instead of letting the sheet dismiss and the same message surface only after the async
    /// `performBatchRename` throws post-dismissal.
    @State private var conflictMessage: String?

    var body: some View {
        ModalScaffoldView(
            icon: .symbol("textformat.123"),
            title: "\(appState.tr(.batchRename)) (\(items.count))",
            width: 480,
            height: 380,
            primaryButton: ModalFooterButton(title: appState.tr(.apply)) { applyRename() },
            secondaryButton: ModalFooterButton(title: appState.tr(.cancel)) { dismiss() },
            headerAccessory: { modePicker },
            content: { formContent })
    }

    private func applyRename() {
        let mode = currentMode
        do {
            try BatchRenameService.assertNoCollisions(in: BatchRenameService.previewNewNames(items: items, mode: mode))
        } catch {
            conflictMessage = appState.errorText(for: error)
            return
        }
        conflictMessage = nil
        appState.performBatchRename(items: items, mode: mode)
        dismiss()
    }

    private var formContent: some View {
        VStack(spacing: 16) {
            modeInputView
            Divider()
            previewLabel
            previewList
            if let conflictMessage {
                Text(conflictMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(20)
        .task(id: currentMode) {
            conflictMessage = nil
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            previews = BatchRenameService.previewNewNames(items: items, mode: currentMode)
        }
    }

    private var modePicker: some View {
        Picker("", selection: $tabMode) {
            Text(appState.tr(.find)).tag(RenameTabMode.findReplace)
            Text(appState.tr(.prefix)).tag(RenameTabMode.prefixSuffix)
            Text(appState.tr(.sequenceNumbering)).tag(RenameTabMode.sequence)
            Text(appState.tr(.regexReplace)).tag(RenameTabMode.regex)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(appState.tr(.batchRename))
    }

    private var previewLabel: some View {
        Text(appState.tr(.preview))
            .font(.system(size: 13, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var previewList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(previews, id: \.original.url) { pair in
                    previewRow(pair)
                    Divider()
                }
            }
        }
        .frame(height: 140)
    }

    private func previewRow(_ pair: (original: FileItem, newName: String)) -> some View {
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
    }

    @ViewBuilder private var modeInputView: some View {
        switch tabMode {
        case .findReplace:
            HStack(spacing: 12) {
                TextField(appState.tr(.find), text: $findText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.find))
                TextField(appState.tr(.replaceWith), text: $replaceText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.replaceWith))
            }
        case .prefixSuffix:
            HStack(spacing: 12) {
                TextField(appState.tr(.prefix), text: $prefixText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.prefix))
                TextField(appState.tr(.suffix), text: $suffixText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.suffix))
            }
        case .sequence:
            HStack(spacing: 12) {
                TextField(appState.tr(.prefix), text: $sequencePrefix)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.prefix))
                HStack(spacing: 4) {
                    Text(appState.tr(.startNumber) + ":")
                        .font(.system(size: 12))
                    Stepper("\(startNumber)", value: $startNumber, in: 0 ... 9999)
                        .accessibilityLabel(appState.tr(.startNumber))
                        .accessibilityValue("\(startNumber)")
                }
                HStack(spacing: 4) {
                    Text(appState.tr(.paddingDigits) + ":")
                        .font(.system(size: 12))
                    Stepper("\(paddingDigits)", value: $paddingDigits, in: 1 ... 6)
                        .accessibilityLabel(appState.tr(.paddingDigits))
                        .accessibilityValue("\(paddingDigits)")
                }
            }
        case .regex:
            HStack(spacing: 12) {
                TextField(appState.tr(.regexReplace), text: $regexPattern)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.regexReplace))
                TextField(appState.tr(.replaceWith), text: $regexTemplate)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel(appState.tr(.replaceWith))
            }
        }
    }
}
