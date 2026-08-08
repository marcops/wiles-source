import Foundation

public enum IconSizeToken {
    public static let minSize: Double = 36.0
    public static let maxSize: Double = 128.0
    public static let defaultSize: Double = 54.0
    public static let step: Double = 8.0
    /// Icon size change applied per accumulated Cmd/Ctrl + scroll-wheel step (finer-grained
    /// than the keyboard shortcut's `step`).
    public static let scrollWheelStep: Double = 4.0
}
