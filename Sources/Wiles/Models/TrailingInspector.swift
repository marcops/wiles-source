import Foundation

/// Which panel fills the content view's trailing pane — one enum so preview and disk-usage can't both be on.
public enum TrailingInspector: String, CaseIterable, Sendable {
    case none
    case preview
    case diskUsage
}
