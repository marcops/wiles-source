import AppKit
import GitBeacon
import SwiftUI

struct FeedbackSheetView: View {
    @Environment(\.dismiss)
    private var dismiss
    var appState: AppState
    @State private var kind: UserReportKind = .feature
    @State private var title: String = ""
    @State private var requestDescription: String = ""
    @State private var isSubmitting: Bool = false
    @State private var didSucceed: Bool = false
    @State private var submitError: String?
    @State private var showConfirmation: Bool = false

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !requestDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()

            contentArea
                .padding(20)

            Divider()
            footerView
        }
        .frame(width: LayoutTokens.feedbackSheetWidth)
        .background(Color(NSColor.windowBackgroundColor))
        .confirmationDialog(appState.tr(.feedbackConfirmMessage), isPresented: $showConfirmation, titleVisibility: .visible) {
            Button(appState.tr(.feedbackSubmit)) { Task { await submit() } }
            Button(appState.tr(.cancel), role: .cancel) { }
        }
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.tr(.feedbackMenuItem))
                    .font(.system(size: 16, weight: .bold))
                Text(appState.tr(.feedbackSubtitle))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder private var contentArea: some View {
        if didSucceed {
            successView
        } else {
            formView
        }
    }

    private var formView: some View {
        VStack(alignment: .leading, spacing: 12) {
            kindSelector

            TextField(appState.tr(.feedbackTitleFieldPlaceholder), text: $title)
                .textFieldStyle(.roundedBorder)
                .disabled(isSubmitting)
                .accessibilityLabel(appState.tr(.feedbackTitleFieldPlaceholder))

            descriptionField

            if let submitError {
                errorBanner(submitError)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// `Picker(selection:).pickerStyle(.radioGroup)` always stacks vertically on macOS — there is no
    /// public SwiftUI API to force it horizontal — so this hand-rolls the two options side by side.
    /// Composite content (icon + text), so per rule 33 it's a plain view + `.onTapGesture`, not a
    /// real `Button`.
    private var kindSelector: some View {
        HStack(spacing: 20) {
            radioOption(.feature, label: appState.tr(.feedbackKindFeature))
            radioOption(.bug, label: appState.tr(.feedbackKindBug))
            Spacer()
        }
    }

    private func radioOption(_ value: UserReportKind, label: String) -> some View {
        let isSelected = kind == value
        return HStack(spacing: 6) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
            Text(label)
                .font(.system(size: 12))
        }
        .contentShape(Rectangle())
        .onTapGesture { kind = value }
        .opacity(isSubmitting ? 0.5 : 1)
        .allowsHitTesting(!isSubmitting)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityLabel(label)
    }

    private var descriptionField: some View {
        TextEditor(text: $requestDescription)
            .scrollContentBackground(.hidden)
            .disabled(isSubmitting)
            .accessibilityLabel(appState.tr(.feedbackDescriptionPlaceholder))
            .overlay(alignment: .topLeading) {
                if requestDescription.isEmpty {
                    Text(appState.tr(.feedbackDescriptionPlaceholder))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: LayoutTokens.feedbackDescriptionFieldHeight)
            .padding(4)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(NSColor.separatorColor)))
    }

    private var successView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)
            Text(appState.tr(.feedbackSuccessMessage))
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }

    private var footerView: some View {
        HStack {
            Spacer()
            if didSucceed {
                Button(appState.tr(.done)) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button(appState.tr(.cancel)) { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(isSubmitting)
                Button(isSubmitting ? appState.tr(.feedbackSubmitting) : appState.tr(.feedbackSubmit)) {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || isSubmitting)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func submit() async {
        guard !isSubmitting, !didSucceed else { return }
        isSubmitting = true
        submitError = nil
        do {
            _ = try await UserReportReporter.submit(UserReport(kind: kind, title: title, description: requestDescription))
            didSucceed = true
        } catch {
            submitError = error.localizedDescription
        }
        isSubmitting = false
    }
}
