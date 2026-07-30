import SwiftUI

public struct NewFileSheetView: View {
    var appState: AppState
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        SingleInputSheetView(
            title: appState.tr(.newFileTitle),
            iconName: "doc.badge.plus",
            initialValue: "Untitled.txt",
            actionButtonTitle: appState.tr(.create),
            cancelTitle: appState.tr(.cancel),
            onCancel: {
                appState.showNewFileSheet = false
            },
            onSubmit: { fileName in
                createNewFile(name: fileName)
            }
        )
    }
    
    private func createNewFile(name: String) {
        let folder = appState.currentURL
        do {
            let createdURL = try NewFileTemplateService.createTemplateFile(
                in: folder,
                fileName: name,
                template: .text
            )
            appState.refreshCurrentDirectory()
            appState.selectedURLs = [createdURL]
        } catch {
            print("Failed to create file: \(error)")
        }
        appState.showNewFileSheet = false
    }
}
