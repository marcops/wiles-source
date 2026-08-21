import Foundation

/// Parses a ZIP file's central directory directly from raw bytes so entry names can be
/// decoded as UTF-8 without going through `/usr/bin/unzip`'s locale-dependent (and, on this
/// system, broken) text conversion.
enum ZIPCentralDirectoryReader {
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectoryFileHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectoryMinSize = 22
    private static let centralDirectoryFileHeaderMinSize = 46
    /// Maximum ZIP file comment length (per the format's 16-bit comment-length field), bounding
    /// how far back from the end of the file we search for the end-of-central-directory record.
    private static let maxZipCommentLength = 65536

    static func readEntryNames(from data: Data) -> [String] {
        guard let centralDirectoryOffset = findCentralDirectoryOffset(in: data) else { return [] }

        var names: [String] = []
        var offset = centralDirectoryOffset
        while offset + centralDirectoryFileHeaderMinSize <= data.count,
              readUInt32(data, at: offset) == centralDirectoryFileHeaderSignature {
            let nameLength = Int(readUInt16(data, at: offset + 28))
            let extraLength = Int(readUInt16(data, at: offset + 30))
            let commentLength = Int(readUInt16(data, at: offset + 32))

            let nameStart = offset + centralDirectoryFileHeaderMinSize
            guard nameStart + nameLength <= data.count else { break }
            let nameBytes = data.subdata(in: nameStart ..< (nameStart + nameLength))
            if let name = String(data: nameBytes, encoding: .utf8) {
                names.append(name)
            }

            offset = nameStart + nameLength + extraLength + commentLength
        }
        return names
    }

    private static func findCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= endOfCentralDirectoryMinSize else { return nil }
        let searchStart = max(0, data.count - endOfCentralDirectoryMinSize - maxZipCommentLength)
        var position = data.count - endOfCentralDirectoryMinSize
        while position >= searchStart {
            if readUInt32(data, at: position) == endOfCentralDirectorySignature {
                return Int(readUInt32(data, at: position + 16))
            }
            position -= 1
        }
        return nil
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16 {
        let start = data.startIndex + offset
        return UInt16(data[start]) | (UInt16(data[start + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        return UInt32(data[start])
            | (UInt32(data[start + 1]) << 8)
            | (UInt32(data[start + 2]) << 16)
            | (UInt32(data[start + 3]) << 24)
    }
}
