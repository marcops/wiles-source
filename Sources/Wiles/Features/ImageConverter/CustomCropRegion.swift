import Foundation

public struct CustomCropRegion: Sendable {
    public var normX: Double
    public var normY: Double
    public var normW: Double
    public var normH: Double

    public init(normX: Double = 0.0, normY: Double = 0.0, normW: Double = 1.0, normH: Double = 1.0) {
        self.normX = max(0, min(1, normX))
        self.normY = max(0, min(1, normY))
        self.normW = max(0.01, min(1 - normX, normW))
        self.normH = max(0.01, min(1 - normY, normH))
    }
}
