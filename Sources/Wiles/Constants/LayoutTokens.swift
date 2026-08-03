import Foundation
import CoreGraphics

public enum LayoutTokens {
    // Sidebar
    public static let sidebarMinWidth: CGFloat = 140.0
    public static let sidebarIdealWidth: CGFloat = 200.0
    public static let sidebarMaxWidth: CGFloat = 260.0
    public static let sidebarTrafficLightInset: CGFloat = 12.0
    public static let sidebarDoubleClickZoneHeight: CGFloat = sidebarTrafficLightInset
    public static let sidebarWidthSaveDebounceMs: Int = 400
    public static let scrollbarReservedThickness: CGFloat = 15.0
    public static let contentTranslucencyDarkenOffset: Double = 0.20
    public static let thumbnailMinimumIconSize: CGFloat = 48.0

    // Content Area
    public static let contentMinWidth: CGFloat = 400.0
    public static let windowMinWidth: CGFloat = 650.0
    public static let windowMinHeight: CGFloat = 450.0

    // Table Columns
    public static let columnSizeWidth: CGFloat = 90.0
    public static let columnDateWidth: CGFloat = 140.0
    public static let columnKindWidth: CGFloat = 90.0
    public static let columnMinWidth: CGFloat = 60.0
    public static let columnMaxWidth: CGFloat = 600.0
    public static let columnHeaderExtraPadding: CGFloat = 32.0
    public static let columnCellExtraPadding: CGFloat = 24.0
    public static let columnNameIconSpacing: CGFloat = 8.0
    public static let columnNameTagExtraPadding: CGFloat = 16.0

    // Grid Cards
    public static let cardWidthOffset: CGFloat = 20.0
    public static let cardHeightOffset: CGFloat = 25.0
    public static let gridSpacing: CGFloat = 20.0
    public static let gridPadding: CGFloat = 20.0
    public static let gridIconScaleMultiplier: CGFloat = 1.25

    // List Icons
    public static let listIconMinSize: CGFloat = 16.0
    public static let listIconMaxSize: CGFloat = 40.0
    public static let listIconScaleMultiplier: CGFloat = 0.35

    // Maximum Recent Items
    public static let maxRecentItemsCount: Int = 5
    public static let maxFunctionLineCount: Int = 25

    // About Sheet
    public static let aboutWindowWidth: CGFloat = 400.0
    public static let aboutIconSize: CGFloat = 80.0
    public static let aboutTitleFontSize: CGFloat = 24.0
    public static let aboutTextFontSize: CGFloat = 13.0

    // Lazy Loading
    public static let lazyLoadingBatchSize: Int = 100
}
