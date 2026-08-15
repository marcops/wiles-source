import Foundation
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case heic
    case tiff

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .jpeg: "JPEG (.jpg)"
        case .png: "PNG (.png)"
        case .heic: "HEIC (.heic)"
        case .tiff: "TIFF (.tiff)"
        }
    }

    public var utType: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        case .heic: .heic
        case .tiff: .tiff
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        case .heic: "heic"
        case .tiff: "tiff"
        }
    }
}
