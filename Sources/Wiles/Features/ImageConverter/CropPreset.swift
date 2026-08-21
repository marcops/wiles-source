import Foundation

public enum CropPreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case square1x1
    case landscape16x9
    case portrait9x16
    case standard4x3

    public var id: String {
        rawValue
    }

    public var l10nKey: L10n.Key {
        switch self {
        case .none: .cropPresetNone
        case .square1x1: .cropPresetSquare1x1
        case .landscape16x9: .cropPresetLandscape16x9
        case .portrait9x16: .cropPresetPortrait9x16
        case .standard4x3: .cropPresetStandard4x3
        }
    }
}
