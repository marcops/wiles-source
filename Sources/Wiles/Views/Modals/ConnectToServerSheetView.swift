import SwiftUI

public struct ConnectToServerSheetView: View {
    var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    public init(appState: AppState) {
        self.appState = appState
    }
    
    public var body: some View {
        SingleInputSheetView(
            title: appState.tr(.connectToServer),
            iconName: "network",
            initialValue: "smb://",
            actionButtonTitle: appState.tr(.connect),
            cancelTitle: appState.tr(.cancel),
            onCancel: {
                dismiss()
            },
            onSubmit: { serverURL in
                do {
                    try NetworkServerService.connectToServer(urlAddress: serverURL)
                    dismiss()
                } catch {
                    print("Error connecting to server: \(error)")
                }
            }
        )
    }
}
