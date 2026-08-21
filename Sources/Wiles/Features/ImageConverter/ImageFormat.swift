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

    public var l10nKey: L10n.Key {
        switch self {
        case .jpeg: .imageFormatJPEG
        case .png: .imageFormatPNG
        case .heic: .imageFormatHEIC
        case .tiff: .imageFormatTIFF
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
