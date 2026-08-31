import SwiftUI

public struct OperationsPopoverView: View {
    private static let popoverWidth: CGFloat = 300
    private static let popoverPadding: CGFloat = 14
    private static let outerSpacing: CGFloat = 12
    private static let titleFontSize: CGFloat = 13
    private static let emptyStatePadding: CGFloat = 8
    private static let taskListSpacing: CGFloat = 10
    private static let taskListMaxHeight: CGFloat = 200
    private static let taskRowSpacing: CGFloat = 4
    private static let taskTitleFontSize: CGFloat = 11
    private static let percentFontSize: CGFloat = 10
    private static let taskRowPadding: CGFloat = 6
    private static let taskRowBackgroundOpacity: Double = 0.5
    private static let taskRowCornerRadius: CGFloat = 6

    var appState: AppState
    var service: BackgroundOperationsService

    public init(appState: AppState) {
        self.appState = appState
        service = appState.backgroundOperations
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Self.outerSpacing) {
            HStack {
                Text(appState.tr(.backgroundOperations))
                    .font(.system(size: Self.titleFontSize, weight: .bold))
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
                    .padding(.vertical, Self.emptyStatePadding)
            } else {
                ScrollView(.vertical) {
                    VStack(spacing: Self.taskListSpacing) {
                        ForEach(service.activeTasks) { task in
                            taskRow(for: task)
                        }
                    }
                }
                .frame(maxHeight: Self.taskListMaxHeight)
            }
        }
        .padding(Self.popoverPadding)
        .frame(width: Self.popoverWidth)
    }

    private func taskRow(for task: FileOperationTask) -> some View {
        VStack(alignment: .leading, spacing: Self.taskRowSpacing) {
            HStack {
                Text(task.title)
                    .font(.system(size: Self.taskTitleFontSize, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    service.cancelTask(id: task.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(appState.tr(.cancel)): \(task.title)")
                .accessibilityHint(appState.tr(.cancelTaskAccessibilityHint))
            }

            ProgressView(value: task.progress)
                .progressViewStyle(.linear)

            HStack {
                Text("\(Int(task.progress * 100))%")
                    .font(.system(size: Self.percentFontSize))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(Self.taskRowPadding)
        .background(Color(NSColor.controlBackgroundColor).opacity(Self.taskRowBackgroundOpacity))
        .cornerRadius(Self.taskRowCornerRadius)
    }
}
