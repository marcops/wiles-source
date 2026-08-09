import Foundation

public enum ResizePreset: String, CaseIterable, Identifiable, Sendable {
    case original
    case scale75
    case scale50
    case max1080p
    case max4K

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .original: return "Original Size (100%)"
        case .scale75: return "75% Scale"
        case .scale50: return "50% Scale"
        case .max1080p: return "Max 1080p (1920x1080)"
        case .max4K: return "Max 4K (3840x2160)"
        }
    }
}
