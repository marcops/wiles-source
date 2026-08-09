import Foundation
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case jpeg
    case png
    case heic
    case tiff

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG (.jpg)"
        case .png: return "PNG (.png)"
        case .heic: return "HEIC (.heic)"
        case .tiff: return "TIFF (.tiff)"
        }
    }

    public var utType: UTType {
        switch self {
        case .jpeg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .tiff: return .tiff
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
}
