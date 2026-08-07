import Foundation
import AppKit

/// Dedicated service responsible for calculating optimal auto-fit column widths based on item content and headers.
@MainActor
public final class ColumnAutoFitService {

    public static func calculateAutoFitWidth(for column: ListColumn, in appState: AppState) -> CGFloat {
        let headerWidth = calculateHeaderWidth(for: column, appState: appState)
        let itemsMax = appState.fileSystem.items.map { calculateItemWidth(for: $0, column: column, appState: appState) }.max() ?? 0
        let maxRequired = max(headerWidth, itemsMax)
        return min(LayoutTokens.columnMaxWidth, max(LayoutTokens.columnMinWidth, maxRequired))
    }

    private static func calculateHeaderWidth(for column: ListColumn, appState: AppState) -> CGFloat {
        let title = appState.tr(localizationKey(for: column))
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        return measureText(title, font: font) + LayoutTokens.columnHeaderExtraPadding
    }

    private static func calculateItemWidth(for item: FileItem, column: ListColumn, appState: AppState) -> CGFloat {
        let spec = itemTextFontAndPadding(for: item, column: column, appState: appState)
        return measureText(spec.text, font: spec.font) + spec.extraPadding
    }

    private struct ColumnTextSpec {
        let text: String
        let font: NSFont
        let extraPadding: CGFloat
    }

    private static func itemTextFontAndPadding(
        for item: FileItem,
        column: ListColumn,
        appState: AppState
    ) -> ColumnTextSpec {
        let font12 = NSFont.systemFont(ofSize: 12, weight: .regular)
        let font13Bold = NSFont.systemFont(ofSize: 13, weight: .semibold)

        switch column {
        case .name:
            let iconSize = max(
                LayoutTokens.listIconMinSize,
                min(LayoutTokens.listIconMaxSize, CGFloat(appState.preferences.iconSize) * LayoutTokens.listIconScaleMultiplier)
            )
            let tagExtra = item.tags.isEmpty ? 0 : LayoutTokens.columnNameTagExtraPadding
            let extra = iconSize + LayoutTokens.columnNameIconSpacing + tagExtra + LayoutTokens.columnCellExtraPadding
            return ColumnTextSpec(text: item.name, font: font13Bold, extraPadding: extra)
        case .size:
            return ColumnTextSpec(text: item.formattedSize, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .dateModified:
            return ColumnTextSpec(text: item.formattedDate, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .dateCreated:
            return ColumnTextSpec(text: item.formattedDateCreated, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .dateAccessed:
            return ColumnTextSpec(text: item.formattedDateAccessed, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .kind:
            let kindText = item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased()
            return ColumnTextSpec(text: kindText, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .owner:
            return ColumnTextSpec(text: item.ownerName, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .group:
            return ColumnTextSpec(text: item.groupName, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        }
    }

    private static func localizationKey(for column: ListColumn) -> L10n.Key {
        switch column {
        case .name:         return .name
        case .size:         return .size
        case .dateModified: return .dateModified
        case .dateCreated:  return .created
        case .dateAccessed: return .lastOpened
        case .kind:         return .kind
        case .owner:        return .owner
        case .group:        return .group
        }
    }

    private static func measureText(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
}
