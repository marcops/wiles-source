import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ListCellFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [URL: CGRect] = [:]
    static func reduce(value: inout [URL: CGRect], nextValue: () -> [URL: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}
