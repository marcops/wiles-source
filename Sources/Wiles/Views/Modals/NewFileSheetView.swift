import SwiftUI

public struct NewFileSheetView: View {
    @Environment(AppState.self) private var appState
    @FocusState private var isNameFocused: Bool
    
    @State private var fileName: String = ""
    @State private var selectedTemplate: FileTemplate = .text
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 16) {
            headerSection
            templateSelector
            nameInputField
            actionButtons
        }
        .padding(20)
        .frame(width: 380)
        .background(Material.regular)
        .cornerRadius(12)
        .onAppear {
            fileName = selectedTemplate.defaultFileName
            isNameFocused = true
        }
    }
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            Text(appState.tr(.newFileTitle))
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
        }
    }
    
    private var templateSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.selectTemplate))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Picker("", selection: $selectedTemplate) {
                ForEach(FileTemplate.allCases) { template in
                    Text(template.defaultFileName).tag(template)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedTemplate) { _, newTemplate in
                fileName = newTemplate.defaultFileName
            }
        }
    }
    
    private var nameInputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.tr(.fileNameLabel))
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("", text: $fileName)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFocused)
                .onSubmit { createNewFile() }
        }
    }
    
    private var actionButtons: some View {
        HStack {
            Spacer()
            Button(appState.tr(.cancel)) {
                appState.showNewFileSheet = false
            }
            .keyboardShortcut(.escape, modifiers: [])
            
            Button(appState.tr(.create)) {
                createNewFile()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
        }
    }
    
    private func createNewFile() {
        let folder = appState.currentURL
        do {
            let createdURL = try NewFileTemplateService.createTemplateFile(
                in: folder,
                fileName: fileName,
                template: selectedTemplate
            )
            appState.refreshCurrentDirectory()
            appState.selectedURLs = [createdURL]
        } catch {
            print("Failed to create file: \(error)")
        }
        appState.showNewFileSheet = false
    }
}
