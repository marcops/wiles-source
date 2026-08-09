import Foundation

public struct ExifMetadata: Sendable, Equatable {
    public let cameraMake: String?
    public let cameraModel: String?
    public let lensModel: String?
    public let iso: String?
    public let aperture: String?
    public let focalLength: String?
    public let dateTimeOriginal: String?
    public let gpsCoordinates: String?
}
