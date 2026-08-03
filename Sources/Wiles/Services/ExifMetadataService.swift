import Foundation
import ImageIO

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

public protocol ExifMetadataServiceProtocol: Sendable {
    static func extractExif(from url: URL) -> ExifMetadata?
}

public final class ExifMetadataService: ExifMetadataServiceProtocol, Sendable {
    public static func extractExif(from url: URL) -> ExifMetadata? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }
        
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        
        let make = tiff?[kCGImagePropertyTIFFMake] as? String
        let model = tiff?[kCGImagePropertyTIFFModel] as? String
        let lens = exif?[kCGImagePropertyExifLensModel] as? String
        
        var isoStr: String? = nil
        if let isoArray = exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = isoArray.first {
            isoStr = "ISO \(first)"
        }
        
        var fnStr: String? = nil
        if let fn = exif?[kCGImagePropertyExifFNumber] as? Double {
            fnStr = String(format: "f/%.1f", fn)
        }
        
        var flStr: String? = nil
        if let fl = exif?[kCGImagePropertyExifFocalLength] as? Double {
            flStr = String(format: "%.1f mm", fl)
        }
        
        let dt = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        
        var gpsStr: String? = nil
        if let lat = gps?[kCGImagePropertyGPSLatitude] as? Double,
           let latRef = gps?[kCGImagePropertyGPSLatitudeRef] as? String,
           let lon = gps?[kCGImagePropertyGPSLongitude] as? Double,
           let lonRef = gps?[kCGImagePropertyGPSLongitudeRef] as? String {
            gpsStr = String(format: "%.4f° %@, %.4f° %@", lat, latRef, lon, lonRef)
        }
        
        if make == nil && model == nil && isoStr == nil && fnStr == nil && flStr == nil && dt == nil && gpsStr == nil {
            return nil
        }
        
        return ExifMetadata(
            cameraMake: make,
            cameraModel: model,
            lensModel: lens,
            iso: isoStr,
            aperture: fnStr,
            focalLength: flStr,
            dateTimeOriginal: dt,
            gpsCoordinates: gpsStr
        )
    }
}
