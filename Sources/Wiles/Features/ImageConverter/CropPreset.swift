import Foundation

public enum CropPreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case square1x1
    case landscape16x9
    case portrait9x16
    case standard4x3

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return "No Crop (Full Image)"
        case .square1x1: return "1:1 Square"
        case .landscape16x9: return "16:9 Landscape"
        case .portrait9x16: return "9:16 Portrait"
        case .standard4x3: return "4:3 Standard"
        }
    }
}
