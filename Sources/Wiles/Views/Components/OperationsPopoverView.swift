import SwiftUI

public struct OperationsPopoverView: View {
    var appState: AppState
    var service = BackgroundOperationsService.shared

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(appState.tr(.backgroundOperations))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(service.activeTasks.count) \(appState.tr(.activeSuffix))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Divider()

            if service.activeTasks.isEmpty {
                Text(appState.tr(.noActiveOperations))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: 10) {
                        ForEach(service.activeTasks) { task in
                            taskRow(for: task)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func taskRow(for task: FileOperationTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(task.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    service.cancelTask(id: task.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            ProgressView(value: task.progress)
                .progressViewStyle(.linear)

            HStack {
                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}
