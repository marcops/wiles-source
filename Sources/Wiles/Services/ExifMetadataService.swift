import Foundation
import ImageIO

public enum ExifMetadataService: Sendable {
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
        let isoStr = formattedISO(from: exif)
        let fnStr = formattedAperture(from: exif)
        let flStr = formattedFocalLength(from: exif)
        let dt = exif?[kCGImagePropertyExifDateTimeOriginal] as? String
        let gpsStr = formattedGPS(from: gps)

        if isEmptyMetadata([make, model, isoStr, fnStr, flStr, dt, gpsStr]) {
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
            gpsCoordinates: gpsStr)
    }

    private static func isEmptyMetadata(_ fields: [String?]) -> Bool {
        fields.allSatisfy { $0 == nil }
    }

    private static func formattedISO(from exif: [CFString: Any]?) -> String? {
        guard let isoArray = exif?[kCGImagePropertyExifISOSpeedRatings] as? [Int], let first = isoArray.first else {
            return nil
        }
        return "ISO \(first)"
    }

    private static func formattedAperture(from exif: [CFString: Any]?) -> String? {
        guard let fn = exif?[kCGImagePropertyExifFNumber] as? Double else { return nil }
        return String(format: "f/%.1f", fn)
    }

    private static func formattedFocalLength(from exif: [CFString: Any]?) -> String? {
        guard let fl = exif?[kCGImagePropertyExifFocalLength] as? Double else { return nil }
        return String(format: "%.1f mm", fl)
    }

    private static func formattedGPS(from gps: [CFString: Any]?) -> String? {
        guard let lat = gps?[kCGImagePropertyGPSLatitude] as? Double,
              let latRef = gps?[kCGImagePropertyGPSLatitudeRef] as? String,
              let lon = gps?[kCGImagePropertyGPSLongitude] as? Double,
              let lonRef = gps?[kCGImagePropertyGPSLongitudeRef] as? String else {
            return nil
        }
        return String(format: "%.4f° %@, %.4f° %@", lat, latRef, lon, lonRef)
    }
}
