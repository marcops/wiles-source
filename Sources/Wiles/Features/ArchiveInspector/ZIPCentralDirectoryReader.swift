import Foundation

/// Parses a ZIP file's central directory directly from raw bytes so entry names can be
/// decoded as UTF-8 without going through `/usr/bin/unzip`'s locale-dependent (and, on this
/// system, broken) text conversion.
enum ZIPCentralDirectoryReader {
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    private static let centralDirectoryFileHeaderSignature: UInt32 = 0x0201_4B50
    private static let zip64LocatorSignature: UInt32 = 0x0706_4B50
    private static let zip64EndOfCentralDirectorySignature: UInt32 = 0x0606_4B50
    private static let zip64LocatorSize = 20
    private static let endOfCentralDirectoryMinSize = 22
    private static let centralDirectoryFileHeaderMinSize = 46
    /// A 32-bit central-directory-offset field set to all-ones means the real value lives in the
    /// ZIP64 end-of-central-directory record (archive >4GB or >65535 entries).
    private static let zip64Marker: UInt32 = 0xFFFF_FFFF
    /// Maximum ZIP file comment length (per the format's 16-bit comment-length field), bounding
    /// how far back from the end of the file we search for the end-of-central-directory record.
    private static let maxZipCommentLength = 65536

    /// Hard cap on entry names materialized from one archive — a crafted (or just huge) central
    /// directory with millions of entries would otherwise grow `[String]` without bound (OOM).
    /// Aligned with `FileSystemService.recursiveSearchResultLimit`'s intent, but larger since an
    /// archive listing is text-only.
    static let maxEntryCount = 50000

    static func readEntryNames(from data: Data) -> [String] {
        guard let centralDirectoryOffset = findCentralDirectoryOffset(in: data) else { return [] }

        var names: [String] = []
        var offset = centralDirectoryOffset
        while names.count < maxEntryCount, hasCentralDirectoryHeader(in: data, at: offset) {
            let generalPurposeFlags = readUInt16(data, at: offset + 8)
            let nameLength = Int(readUInt16(data, at: offset + 28))
            let extraLength = Int(readUInt16(data, at: offset + 30))
            let commentLength = Int(readUInt16(data, at: offset + 32))

            let nameStart = offset + centralDirectoryFileHeaderMinSize
            guard nameStart + nameLength <= data.count else { break }
            let nameBytes = data.subdata(in: nameStart ..< (nameStart + nameLength))
            if let name = decodeEntryName(nameBytes, generalPurposeFlags: generalPurposeFlags) {
                names.append(name)
            }

            offset = nameStart + nameLength + extraLength + commentLength
        }
        return names
    }

    private static func hasCentralDirectoryHeader(in data: Data, at offset: Int) -> Bool {
        offset + centralDirectoryFileHeaderMinSize <= data.count
            && readUInt32(data, at: offset) == centralDirectoryFileHeaderSignature
    }

    /// General-purpose bit 11 means the name is UTF-8. When it isn't set, the name is in the
    /// archive creator's OEM/system codepage — historically CP437, or a Windows local codepage.
    /// Try UTF-8 first regardless (most modern archives), then CP437, then Latin-1 (never fails),
    /// so a Windows-made entry isn't silently dropped from the listing.
    private static let utf8FlagBit: UInt16 = 0x0800

    private static func decodeEntryName(_ bytes: Data, generalPurposeFlags: UInt16) -> String? {
        if let utf8 = String(data: bytes, encoding: .utf8) {
            return utf8
        }
        guard generalPurposeFlags & utf8FlagBit == 0 else { return nil }
        let cp437 = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.dosLatinUS.rawValue))
        if let oem = String(data: bytes, encoding: String.Encoding(rawValue: cp437)) {
            return oem
        }
        return String(data: bytes, encoding: .isoLatin1)
    }

    private static func findCentralDirectoryOffset(in data: Data) -> Int? {
        guard data.count >= endOfCentralDirectoryMinSize else { return nil }
        let searchStart = max(0, data.count - endOfCentralDirectoryMinSize - maxZipCommentLength)
        // Upper bound so the whole 22-byte EOCD record (not just its 4-byte signature) fits before EOF.
        let searchRange = (data.startIndex + searchStart) ..< (data.startIndex + data.count - endOfCentralDirectoryMinSize + 4)
        let signature = withUnsafeBytes(of: endOfCentralDirectorySignature.littleEndian) { Data($0) }
        guard let match = data.range(of: signature, options: .backwards, in: searchRange) else { return nil }
        let position = match.lowerBound - data.startIndex
        let offset32 = readUInt32(data, at: position + 16)
        guard offset32 == zip64Marker else { return Int(offset32) }
        return zip64CentralDirectoryOffset(in: data, eocdPosition: position)
    }

    /// Resolves the real central-directory offset via the ZIP64 locator (immediately before the
    /// regular EOCD) → ZIP64 EOCD record. Returns nil if either structure is missing or truncated.
    private static func zip64CentralDirectoryOffset(in data: Data, eocdPosition: Int) -> Int? {
        let locatorPosition = eocdPosition - zip64LocatorSize
        guard locatorPosition >= 0,
              readUInt32(data, at: locatorPosition) == zip64LocatorSignature else { return nil }

        let recordOffset = Int(readUInt64(data, at: locatorPosition + 8))
        // ZIP64 EOCD record: signature (4) + ... + central-directory offset at byte 48.
        guard recordOffset >= 0, recordOffset + 56 <= data.count,
              readUInt32(data, at: recordOffset) == zip64EndOfCentralDirectorySignature else { return nil }
        return Int(readUInt64(data, at: recordOffset + 48))
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

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        let lo = UInt64(readUInt32(data, at: offset))
        let hi = UInt64(readUInt32(data, at: offset + 4))
        return lo | (hi << 32)
    }
}
