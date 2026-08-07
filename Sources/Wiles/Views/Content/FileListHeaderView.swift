import SwiftUI

/// The sortable column header row above `FileListView`'s rows, plus the column-width layout math
/// (`totalWidth`/`adjustNameColumnWidth`) shared with the row content, since both must agree on
/// exactly which columns are visible and how wide each one is.
struct FileListHeaderView: View {
    var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.visibleColumns(appState).enumerated()), id: \.element) { _, col in
                headerCell(columnTitle(col), option: sortOption(for: col), isLeading: col == .name)
                    .frame(width: appState.columnWidth(for: col), alignment: col == .name ? .leading : .trailing)
                    .overlay(alignment: .trailing) {
                        ColumnResizeHandle(column: col, appState: appState)
                            .offset(x: 4)
                    }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.secondary)
        .padding(.horizontal, 22)
        .frame(height: 30)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.08))
        .clipped()
        .contextMenu { columnVisibilityMenu }
    }

    /// Columns currently set to visible, in canonical order.
    static func visibleColumns(_ appState: AppState) -> [ListColumn] {
        ListColumn.allCases.filter { appState.isColumnVisible($0) }
    }

    static func totalColumnsWidth(_ appState: AppState) -> CGFloat {
        visibleColumns(appState).map { appState.columnWidth(for: $0) }.reduce(0, +) + 44
    }

    static func adjustNameColumnWidth(for containerWidth: CGFloat, appState: AppState) {
        let otherWidths = visibleColumns(appState).filter { $0 != .name }.map { appState.columnWidth(for: $0) }.reduce(0, +) + 44
        let targetNameWidth = max(LayoutTokens.columnMinWidth, containerWidth - otherWidths)
        if abs(appState.columnWidth(for: .name) - targetNameWidth) > 1 {
            appState.setColumnWidth(.name, width: targetNameWidth)
        }
    }

    static func columnTitle(_ col: ListColumn, appState: AppState) -> String {
        switch col {
        case .name:         return appState.tr(.name)
        case .size:         return appState.tr(.size)
        case .dateModified: return appState.tr(.dateModified)
        case .dateCreated:  return appState.tr(.created)
        case .dateAccessed: return appState.tr(.lastOpened)
        case .kind:         return appState.tr(.kind)
        case .owner:        return appState.tr(.owner)
        case .group:        return appState.tr(.group)
        }
    }

    private func columnTitle(_ col: ListColumn) -> String {
        Self.columnTitle(col, appState: appState)
    }

    private func headerCell(_ title: String, option: SortOption, isLeading: Bool) -> some View {
        Button {
            if appState.preferences.sortOption == option {
                appState.preferences.sortAscending.toggle()
            } else {
                appState.preferences.sortOption = option
                appState.preferences.sortAscending = true
            }
            appState.refreshCurrentDirectory()
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if appState.preferences.sortOption == option {
                    Image(systemName: appState.preferences.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.trailing, isLeading ? 0 : 4)
        }
        .buttonStyle(.plain)
    }

    private func sortOption(for col: ListColumn) -> SortOption {
        switch col {
        case .name:         return .name
        case .size:         return .size
        case .dateModified: return .dateModified
        case .dateCreated:  return .dateCreated
        case .dateAccessed: return .dateAccessed
        case .kind:         return .kind
        case .owner:        return .owner
        case .group:        return .group
        }
    }

    @ViewBuilder private var columnVisibilityMenu: some View {
        ForEach(ListColumn.allCases.filter { !$0.isAlwaysVisible }, id: \.self) { col in
            Button { appState.toggleColumnVisibility(col) } label: {
                HStack {
                    Text(columnTitle(col))
                    Spacer()
                    if appState.isColumnVisible(col) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}
