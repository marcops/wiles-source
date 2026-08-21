import Foundation

public enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case original
    case scale75
    case scale50
    case max1080p
    case max4K

    public var id: String {
        rawValue
    }

    public var l10nKey: L10n.Key {
        switch self {
        case .original: .resizePresetOriginal
        case .scale75: .resizePresetScale75
        case .scale50: .resizePresetScale50
        case .max1080p: .resizePresetMax1080p
        case .max4K: .resizePresetMax4K
        }
    }
}
