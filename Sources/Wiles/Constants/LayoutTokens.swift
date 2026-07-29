import Foundation
import CoreGraphics

public enum LayoutTokens {
    // Sidebar
    public static let sidebarMinWidth: CGFloat = 140.0
    public static let sidebarIdealWidth: CGFloat = 180.0
    public static let sidebarMaxWidth: CGFloat = 260.0
    
    // Content Area
    public static let contentMinWidth: CGFloat = 400.0
    public static let windowMinWidth: CGFloat = 650.0
    public static let windowMinHeight: CGFloat = 450.0
    
    // Table Columns
    public static let columnSizeWidth: CGFloat = 90.0
    public static let columnDateWidth: CGFloat = 140.0
    public static let columnKindWidth: CGFloat = 90.0
    
    // Grid Cards
    public static let cardWidthOffset: CGFloat = 46.0
    public static let cardHeightOffset: CGFloat = 51.0
    public static let gridSpacing: CGFloat = 20.0
    public static let gridPadding: CGFloat = 20.0
    
    // List Icons
    public static let listIconMinSize: CGFloat = 16.0
    public static let listIconMaxSize: CGFloat = 40.0
    public static let listIconScaleMultiplier: CGFloat = 0.35
    
    // Maximum Recent Items
    public static let maxRecentItemsCount: Int = 5
    public static let maxFunctionLineCount: Int = 25
}
