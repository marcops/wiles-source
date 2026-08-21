import AppKit
import Foundation

/// Dedicated service responsible for calculating optimal auto-fit column widths based on item content and headers.
@MainActor
public final class ColumnAutoFitService {
    private static let columnHeaderFontSize: CGFloat = 11
    private static let columnCellFontSize: CGFloat = 12
    private static let columnNameFontSize: CGFloat = 13

    /// - Parameters:
    ///   - items: The currently listed file items whose content widths are measured.
    ///   - iconSize: The user's configured list icon size preference (pre-scale/pre-clamp), used only
    ///     for the `.name` column's leading icon width.
    ///   - language: The active app language, used to measure the localized column header/kind text.
    public static func calculateAutoFitWidth(
        for column: ListColumn,
        items: [FileItem],
        iconSize: Double,
        language: AppLanguage) -> CGFloat {
        let headerWidth = calculateHeaderWidth(for: column, language: language)
        let itemsMax = items.map { calculateItemWidth(for: $0, column: column, iconSize: iconSize, language: language) }.max() ?? 0
        let maxRequired = max(headerWidth, itemsMax)
        return min(LayoutTokens.columnMaxWidth, max(LayoutTokens.columnMinWidth, maxRequired))
    }

    private static func calculateHeaderWidth(for column: ListColumn, language: AppLanguage) -> CGFloat {
        let title = L10n.string(localizationKey(for: column), lang: language)
        let font = NSFont.systemFont(ofSize: columnHeaderFontSize, weight: .semibold)
        return measureText(title, font: font) + LayoutTokens.columnHeaderExtraPadding
    }

    private static func calculateItemWidth(
        for item: FileItem,
        column: ListColumn,
        iconSize: Double,
        language: AppLanguage) -> CGFloat {
        let spec = itemTextFontAndPadding(for: item, column: column, iconSize: iconSize, language: language)
        return measureText(spec.text, font: spec.font) + spec.extraPadding
    }

    private static func itemTextFontAndPadding(
        for item: FileItem,
        column: ListColumn,
        iconSize: Double,
        language: AppLanguage) -> ColumnTextSpec {
        let font12 = NSFont.systemFont(ofSize: columnCellFontSize, weight: .regular)
        let font13Bold = NSFont.systemFont(ofSize: columnNameFontSize, weight: .semibold)

        switch column {
        case .name:
            let clampedIconSize = max(
                LayoutTokens.listIconMinSize,
                min(LayoutTokens.listIconMaxSize, CGFloat(iconSize) * LayoutTokens.listIconScaleMultiplier))
            let tagExtra = item.tags.isEmpty ? 0 : LayoutTokens.columnNameTagExtraPadding
            let extra = clampedIconSize + LayoutTokens.columnNameIconSpacing + tagExtra + LayoutTokens.columnCellExtraPadding
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
            let kindText = item.isDirectory ? L10n.string(.folder, lang: language) : item.fileExtension.uppercased()
            return ColumnTextSpec(text: kindText, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .owner:
            return ColumnTextSpec(text: item.ownerName, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        case .group:
            return ColumnTextSpec(text: item.groupName, font: font12, extraPadding: LayoutTokens.columnCellExtraPadding)
        }
    }

    private static func localizationKey(for column: ListColumn) -> L10n.Key {
        switch column {
        case .name: .name
        case .size: .size
        case .dateModified: .dateModified
        case .dateCreated: .created
        case .dateAccessed: .lastOpened
        case .kind: .kind
        case .owner: .owner
        case .group: .group
        }
    }

    private static func measureText(_ text: String, font: NSFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return (text as NSString).size(withAttributes: attributes).width
    }
}
