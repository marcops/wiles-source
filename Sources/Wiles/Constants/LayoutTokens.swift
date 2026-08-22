import CoreGraphics
import Foundation

public enum LayoutTokens {
    // Sidebar
    public static let sidebarMinWidth: CGFloat = 180.0
    public static let sidebarIdealWidth: CGFloat = 200.0
    public static let sidebarMaxWidth: CGFloat = 260.0
    public static let sidebarTrafficLightInset: CGFloat = 12.0
    public static let sidebarDoubleClickZoneHeight: CGFloat = sidebarTrafficLightInset
    public static let sidebarWidthSaveDebounceMs: Int = 400
    public static let sidebarCollapsedWidth: CGFloat = 48.0
    public static let sidebarPeekCollapseDelayMs: Int = 250
    /// Minimum leading inset for the header row when there's no sidebar pane to its left reserving
    /// room for the repositioned traffic-light window buttons (see `TrafficLightRepositioner`).
    public static let headerTrafficLightsSafeLeadingInset: CGFloat = 40.0
    public static let scrollbarReservedThickness: CGFloat = 15.0
    public static let contentTranslucencyDarkenOffset: Double = 0.20
    public static let thumbnailMinimumIconSize: CGFloat = 48.0

    // Content Area
    public static let contentMinWidth: CGFloat = 400.0
    public static let windowMinWidth: CGFloat = 650.0
    public static let windowMinHeight: CGFloat = 450.0
    public static let diskUsageSidebarMinWidth: CGFloat = 240.0
    public static let previewSidebarMinWidth: CGFloat = 200.0
    public static let terminalDrawerHeight: CGFloat = 200.0

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
    public static let gridCardPadding: CGFloat = 6.0
    public static let gridCardVStackSpacing: CGFloat = 6.0
    /// `cardWidth` minus the card's horizontal padding (`gridCardPadding`) on both sides.
    public static let gridCardLabelHorizontalInset: CGFloat = gridCardPadding * 2
    public static let gridCardLabelMinFontSize: Double = 8.0
    public static let gridCardLabelMaxFontSize: Double = 12.0
    public static let gridCardLabelFontScaleMultiplier: Double = 0.22

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

    // HTTP Share Sheet
    public static let httpShareSheetWidth: CGFloat = 400.0
    public static let httpShareSheetHeight: CGFloat = 320.0

    // Archive Inspection Sheet
    public static let archiveInspectionSheetWidth: CGFloat = 450.0
    public static let archiveInspectionSheetHeight: CGFloat = 400.0

    // Feedback Sheet (bug report / feature request)
    public static let feedbackSheetWidth: CGFloat = 460.0
    public static let feedbackDescriptionFieldHeight: CGFloat = 160.0

    // Lazy Loading
    public static let lazyLoadingBatchSize: Int = 100
    public static let paginationThreshold: Int = 500
    public static let thumbnailPrefetchItemThreshold: Int = 500

    // Recursive Search
    public static let recursiveSearchResultLimit: Int = 2000
    public static let recursiveSearchBatchSize: Int = 40

    // Modal Scaffold (standard header/content/footer skeleton, see ModalScaffoldView)
    public static let modalHeaderIconSize: CGFloat = 36.0
    public static let modalHeaderIconSizeLarge: CGFloat = 64.0
    public static let modalSymbolIconScale: CGFloat = 0.5
    public static let modalHeaderHorizontalPadding: CGFloat = 20.0
    public static let modalHeaderVerticalPadding: CGFloat = 14.0
    public static let modalFooterHorizontalPadding: CGFloat = 20.0
    public static let modalFooterVerticalPadding: CGFloat = 12.0
    public static let modalTitleFontSize: CGFloat = 16.0
    public static let modalSubtitleFontSize: CGFloat = 12.0

    // Auto Organization Sheet
    public static let autoOrganizationSheetWidth: CGFloat = 600.0
    public static let autoOrganizationSheetHeight: CGFloat = 500.0

    // File Properties Sheet
    public static let filePropertiesSheetWidth: CGFloat = 400.0
    public static let filePropertiesSheetHeight: CGFloat = 500.0

    /// Connect To Server Sheet
    public static let connectToServerContentWidth: CGFloat = 320.0

    // Empty Directory View
    public static let emptyStateIconFontSize: CGFloat = 48.0
    public static let emptyStateTitleFontSize: CGFloat = 15.0
    public static let emptyStateBodyFontSize: CGFloat = 12.0
    public static let emptyStateNoticeMaxWidth: CGFloat = 320.0

    // iCloud Status Badge
    public static let iCloudStatusBadgeProgressScale: Double = 0.5
    public static let iCloudStatusBadgeSize: CGFloat = 14.0
    public static let iCloudStatusDownloadIconFontSize: CGFloat = 11.0
    public static let iCloudStatusUploadIconFontSize: CGFloat = 10.0
}
