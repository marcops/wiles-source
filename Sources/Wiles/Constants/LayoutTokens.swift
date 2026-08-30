import AppKit
import CoreGraphics
import Foundation

/// Constants shared by 2+ types. A value used by only one type belongs as a `private static let`
/// inside that type instead — see `.agents/DEV_RULES.md`'s "No Magic Numbers" section.
public enum LayoutTokens {
    // Sidebar (shared between SidebarView and MainContentView)
    public static let sidebarMinWidth: CGFloat = 180.0
    public static let sidebarIdealWidth: CGFloat = 200.0
    public static let scrollbarReservedThickness: CGFloat = 15.0

    /// Table Columns (shared across AppState+ColumnsAndActions, ColumnResizeHandle,
    /// FileListHeaderView, ColumnAutoFitService)
    public static let columnMinWidth: CGFloat = 60.0

    // Grid Cards (shared between FileGridView and FileGridCardItemView)
    public static let gridCardPadding: CGFloat = 6.0
    public static let gridCardVStackSpacing: CGFloat = 6.0
    /// `cardWidth` minus the card's horizontal padding (`gridCardPadding`) on both sides.
    public static let gridCardLabelHorizontalInset: CGFloat = gridCardPadding * 2
    public static let gridCardLabelMinFontSize: Double = 8.0
    public static let gridCardLabelMaxFontSize: Double = 12.0
    public static let gridCardLabelFontScaleMultiplier: Double = 0.22
    /// The label pill's own top+bottom padding (`.padding(.vertical, 2)` applied once, so 2 edges).
    public static let gridCardLabelVerticalPadding: CGFloat = 4.0

    /// Shared by `FileGridCardItemView` and `FileGridView` so they can't drift apart.
    public static func gridCardLabelFontSize(forIconSize iconSize: CGFloat) -> CGFloat {
        CGFloat(max(gridCardLabelMinFontSize, min(gridCardLabelMaxFontSize, Double(iconSize) * gridCardLabelFontScaleMultiplier)))
    }

    /// Memoized per `iconSize` — this is read from grid `body`/`cardHeight` for every visible card
    /// and on every zoom tick, and `iconSize` only moves in discrete steps, so the `NSFont` build
    /// + metrics arithmetic runs once per distinct size instead of once per call.
    private nonisolated(unsafe) static var twoLineLabelHeightCache: [CGFloat: CGFloat] = [:]
    private static let twoLineLabelHeightCacheLock = NSLock()

    /// Vertical room `FileGridView.cardHeight` must reserve for a wrapped 2-line label.
    public static func gridCardTwoLineLabelHeight(forIconSize iconSize: CGFloat) -> CGFloat {
        twoLineLabelHeightCacheLock.lock()
        defer { twoLineLabelHeightCacheLock.unlock() }
        if let cached = twoLineLabelHeightCache[iconSize] {
            return cached
        }
        let font = NSFont.systemFont(ofSize: gridCardLabelFontSize(forIconSize: iconSize), weight: .semibold)
        let height = (font.ascender - font.descender + font.leading) * 2 + gridCardLabelVerticalPadding
        if twoLineLabelHeightCache.count > 32 { twoLineLabelHeightCache.removeAll(keepingCapacity: true) }
        twoLineLabelHeightCache[iconSize] = height
        return height
    }

    // List Icons (shared between FileListView and ColumnAutoFitService)
    public static let listIconMinSize: CGFloat = 16.0
    public static let listIconMaxSize: CGFloat = 40.0
    public static let listIconScaleMultiplier: CGFloat = 0.35

    /// Modal Scaffold (shared between ModalScaffoldView and ModalHeaderView)
    public static let modalHeaderIconSize: CGFloat = 36.0

    /// Lazy Loading (shared across FileCollectionContainerView, ResetPaginationAndPrefetchThumbnails,
    /// PaginatedItemsSection)
    public static let paginationThreshold: Int = 500
}
