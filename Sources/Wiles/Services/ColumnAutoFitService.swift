import Foundation
import AppKit

/// Dedicated service responsible for calculating optimal auto-fit column widths based on item content and headers.
@MainActor
public final class ColumnAutoFitService {
    
    public static func calculateAutoFitWidth(for column: ListColumn, in appState: AppState) -> CGFloat {
        let headerWidth = calculateHeaderWidth(for: column, appState: appState)
        let itemsMax = appState.items.map { calculateItemWidth(for: $0, column: column, appState: appState) }.max() ?? 0
        let maxRequired = max(headerWidth, itemsMax)
        return min(LayoutTokens.columnMaxWidth, max(LayoutTokens.columnMinWidth, maxRequired))
    }
    
    private static func calculateHeaderWidth(for column: ListColumn, appState: AppState) -> CGFloat {
        let title = appState.tr(localizationKey(for: column))
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        return measureText(title, font: font) + LayoutTokens.columnHeaderExtraPadding
    }
    
    private static func calculateItemWidth(for item: FileItem, column: ListColumn, appState: AppState) -> CGFloat {
        let (text, font, extra) = itemTextFontAndPadding(for: item, column: column, appState: appState)
        return measureText(text, font: font) + extra
    }
    
    private static func itemTextFontAndPadding(
        for item: FileItem,
        column: ListColumn,
        appState: AppState
    ) -> (String, NSFont, CGFloat) {
        let font12 = NSFont.systemFont(ofSize: 12, weight: .regular)
        let font13Bold = NSFont.systemFont(ofSize: 13, weight: .semibold)
        
        switch column {
        case .name:
            let iconSize = max(
                LayoutTokens.listIconMinSize,
                min(LayoutTokens.listIconMaxSize, CGFloat(appState.iconSize) * LayoutTokens.listIconScaleMultiplier)
            )
            let tagExtra = item.tags.isEmpty ? 0 : LayoutTokens.columnNameTagExtraPadding
            let extra = iconSize + LayoutTokens.columnNameIconSpacing + tagExtra + LayoutTokens.columnCellExtraPadding
            return (item.name, font13Bold, extra)
        case .size:
            return (item.formattedSize, font12, LayoutTokens.columnCellExtraPadding)
        case .dateModified:
            return (item.formattedDate, font12, LayoutTokens.columnCellExtraPadding)
        case .dateCreated:
            return (item.formattedDateCreated, font12, LayoutTokens.columnCellExtraPadding)
        case .dateAccessed:
            return (item.formattedDateAccessed, font12, LayoutTokens.columnCellExtraPadding)
        case .kind:
            let kindText = item.isDirectory ? appState.tr(.folder) : item.fileExtension.uppercased()
            return (kindText, font12, LayoutTokens.columnCellExtraPadding)
        case .owner:
            return (item.ownerName, font12, LayoutTokens.columnCellExtraPadding)
        case .group:
            return (item.groupName, font12, LayoutTokens.columnCellExtraPadding)
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
