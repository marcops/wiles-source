import SwiftUI

/// Captures each Grid card's rendered name-label width, keyed by item URL — see
/// `SelectionStore.gridLabelWidths`.
struct LabelWidthKey: PreferenceKey {
    static let defaultValue: [URL: CGFloat] = [:]
    static func reduce(value: inout [URL: CGFloat], nextValue: () -> [URL: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
