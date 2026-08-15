import Foundation
@testable import Wiles

/// `ZIPCentralDirectoryReader` hand-parses a ZIP file's central directory directly from raw bytes
/// (see the doc comment on the type itself). It only exposes entry names via
/// `readEntryNames(from:)`, so these tests build the central-directory-and-End-Of-Central-Directory
/// byte layout it expects entirely in-memory (no `/usr/bin/zip` or on-disk fixture needed) and
/// verify the byte-level parsing: valid entries, a truncated/corrupt buffer, an empty archive, and a
/// known entry name round-tripped exactly.
@MainActor
public struct ZIPCentralDirectoryReaderTests {
    public static func run() {
        testValidMultiEntryArchive()
        testSingleKnownEntryNameRoundTrips()
        testEmptyArchiveReturnsNoEntries()
        testTruncatedBufferDoesNotCrashAndReturnsPartialResults()
        testGarbageBufferWithNoEOCDSignatureReturnsNoEntries()
        testBufferShorterThanEOCDReturnsNoEntries()
    }

    // MARK: - Byte layout helpers

    private static let centralDirectoryFileHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50

    private static func writeUInt16LE(_ value: UInt16, into data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
    }

    private static func writeUInt32LE(_ value: UInt32, into data: inout Data) {
        data.append(UInt8(value & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 24) & 0xFF))
    }

    /// Builds one 46-byte central directory file header (rule: reader only reads signature at
    /// offset 0, nameLength/extraLength/commentLength at offsets 28/30/32, and the name bytes
    /// starting at offset 46 - every other field is filler since the reader never touches it).
    private static func makeCentralDirectoryRecord(name: String, crc32: UInt32 = 0, uncompressedSize: UInt32 = 0) -> Data {
        var record = Data()
        writeUInt32LE(centralDirectoryFileHeaderSignature, into: &record) // 0: signature
        writeUInt16LE(0, into: &record) // 4: version made by
        writeUInt16LE(0, into: &record) // 6: version needed
        writeUInt16LE(0, into: &record) // 8: flags
        writeUInt16LE(0, into: &record) // 10: compression method
        writeUInt16LE(0, into: &record) // 12: mod time
        writeUInt16LE(0, into: &record) // 14: mod date
        writeUInt32LE(crc32, into: &record) // 16: crc32
        writeUInt32LE(uncompressedSize, into: &record) // 20: compressed size
        writeUInt32LE(uncompressedSize, into: &record) // 24: uncompressed size
        let nameBytes = Data(name.utf8)
        writeUInt16LE(UInt16(nameBytes.count), into: &record) // 28: name length
        writeUInt16LE(0, into: &record) // 30: extra length
        writeUInt16LE(0, into: &record) // 32: comment length
        writeUInt16LE(0, into: &record) // 34: disk number start
        writeUInt16LE(0, into: &record) // 36: internal attrs
        writeUInt32LE(0, into: &record) // 38: external attrs
        writeUInt32LE(0, into: &record) // 42: local header offset
        record.append(nameBytes) // 46: name
        return record
    }

    private static func makeEndOfCentralDirectory(entryCount: UInt16, centralDirectorySize: UInt32, centralDirectoryOffset: UInt32) -> Data {
        var eocd = Data()
        writeUInt32LE(endOfCentralDirectorySignature, into: &eocd) // 0: signature
        writeUInt16LE(0, into: &eocd) // 4: disk number
        writeUInt16LE(0, into: &eocd) // 6: disk with cd
        writeUInt16LE(entryCount, into: &eocd) // 8: total entries this disk
        writeUInt16LE(entryCount, into: &eocd) // 10: total entries
        writeUInt32LE(centralDirectorySize, into: &eocd) // 12: cd size
        writeUInt32LE(centralDirectoryOffset, into: &eocd) // 16: cd offset
        writeUInt16LE(0, into: &eocd) // 20: comment length
        return eocd
    }

    /// Lays the central directory records directly at the start of the buffer (offset 0), followed
    /// immediately by the EOCD record pointing back at offset 0 - the minimal valid archive shape
    /// this reader needs (it never reads local file headers, only the central directory).
    private static func makeZIPBuffer(entryNames: [String]) -> Data {
        var centralDirectory = Data()
        for name in entryNames {
            centralDirectory.append(makeCentralDirectoryRecord(name: name))
        }
        let eocd = makeEndOfCentralDirectory(
            entryCount: UInt16(entryNames.count),
            centralDirectorySize: UInt32(centralDirectory.count),
            centralDirectoryOffset: 0)
        return centralDirectory + eocd
    }

    // MARK: - Tests

    private static func testValidMultiEntryArchive() {
        let names = ["folder/", "folder/file.txt", "readme.md"]
        let buffer = makeZIPBuffer(entryNames: names)
        let result = ZIPCentralDirectoryReader.readEntryNames(from: buffer)
        report("Feature/ZIPCentralDirectoryReader", "POS: a valid 3-entry central directory yields exactly those 3 names in order", result: result == names)
    }

    private static func testSingleKnownEntryNameRoundTrips() {
        let knownName = "invoice-2026.pdf"
        let buffer = makeZIPBuffer(entryNames: [knownName])
        let result = ZIPCentralDirectoryReader.readEntryNames(from: buffer)
        report("Feature/ZIPCentralDirectoryReader", "POS: a single known entry name round-trips exactly through the byte layout", result: result == [knownName])
    }

    private static func testEmptyArchiveReturnsNoEntries() {
        // An archive with zero entries is just a bare EOCD record with cdOffset 0 - no central
        // directory record signature exists anywhere in the (tiny) buffer.
        let buffer = makeZIPBuffer(entryNames: [])
        let result = ZIPCentralDirectoryReader.readEntryNames(from: buffer)
        report("Feature/ZIPCentralDirectoryReader", "POS: an archive with zero entries returns an empty array, not a crash", result: result.isEmpty)
    }

    private static func testTruncatedBufferDoesNotCrashAndReturnsPartialResults() {
        let names = ["first.txt", "second-longer-name.txt"]
        let firstRecord = makeCentralDirectoryRecord(name: names[0])
        let secondRecordFull = makeCentralDirectoryRecord(name: names[1])

        // Cut the second record's 46-byte fixed header short (keep only its first 20 bytes) so the
        // loop's own bounds guard (`offset + centralDirectoryFileHeaderMinSize <= data.count`) fails
        // before it ever reads a nameLength/signature from truncated memory. A real EOCD still
        // follows, correctly pointing back at offset 0, so this exercises "corrupt/truncated central
        // directory data with an otherwise-valid EOCD" rather than "EOCD missing entirely".
        let secondRecordTruncatedHeader = secondRecordFull.prefix(20)
        let truncatedCentralDirectory = firstRecord + secondRecordTruncatedHeader
        let eocd = makeEndOfCentralDirectory(
            entryCount: 2,
            centralDirectorySize: UInt32(truncatedCentralDirectory.count),
            centralDirectoryOffset: 0)
        let truncatedBuffer = truncatedCentralDirectory + eocd

        let result = ZIPCentralDirectoryReader.readEntryNames(from: truncatedBuffer)
        report(
            "Feature/ZIPCentralDirectoryReader",
            "POS: a buffer whose second record header is cut short still returns the first entry cleanly, without crashing",
            result: result == [names[0]])
    }

    private static func testGarbageBufferWithNoEOCDSignatureReturnsNoEntries() {
        // Long enough to satisfy the minimum EOCD size but containing no real EOCD signature
        // anywhere - findCentralDirectoryOffset must fail closed, not scan out of bounds.
        let garbage = Data(repeating: 0x41, count: 128)
        let result = ZIPCentralDirectoryReader.readEntryNames(from: garbage)
        report("Feature/ZIPCentralDirectoryReader", "NEG: a garbage buffer with no EOCD signature anywhere returns an empty array", result: result.isEmpty)
    }

    private static func testBufferShorterThanEOCDReturnsNoEntries() {
        // Real EOCD record is 22 bytes minimum; anything shorter can never contain one.
        let tooShort = Data(repeating: 0x00, count: 10)
        let result = ZIPCentralDirectoryReader.readEntryNames(from: tooShort)
        report("Feature/ZIPCentralDirectoryReader", "NEG: a buffer shorter than the minimum EOCD size returns an empty array", result: result.isEmpty)
    }

    private static func report(_ category: String, _ name: String, result: Bool) {
        TestReporter.report(category, name, result: result)
    }
}
