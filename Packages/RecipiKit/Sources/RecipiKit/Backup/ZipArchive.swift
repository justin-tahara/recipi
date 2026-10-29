import Compression
import Foundation

// iOS has no public zip API, so backups use this small writer and reader.
// The writer stores files without compression (photos are already JPEG, and
// recipe JSON is small). The reader handles stored and deflated entries,
// which covers archives recipi writes and ones re-zipped by Finder or other
// tools. Zip64, encryption and split archives are not supported and fail
// with a clear error.

public enum ZipError: Error, Equatable, LocalizedError {
    case notAZipArchive
    case corrupt
    case unsupportedCompression(method: UInt16)
    case unsupportedFeature(String)
    case checksumMismatch(entry: String)
    case invalidEntryName(String)
    case duplicateEntry(String)
    case archiveTooLarge

    public var errorDescription: String? {
        switch self {
        case .notAZipArchive:
            "That file isn't a zip archive."
        case .corrupt:
            "The zip archive is damaged."
        case .unsupportedCompression(let method):
            "The zip archive uses a compression method recipi can't read (method \(method)). Zip it again without compression or with standard (deflate) compression."
        case .unsupportedFeature(let feature):
            "The zip archive uses \(feature), which recipi can't read."
        case .checksumMismatch(let entry):
            "\(entry) in the zip archive is damaged."
        case .invalidEntryName(let name):
            "“\(name)” can't be used as a file name in a zip archive."
        case .duplicateEntry(let name):
            "The zip archive already has a file named \(name)."
        case .archiveTooLarge:
            "The archive is too large for a zip file without Zip64."
        }
    }
}

// MARK: - Writer

/// Builds a zip archive in memory, one stored (uncompressed) file at a time.
public struct ZipWriter {
    private var body = Data()
    private var centralDirectory = Data()
    private var names = Set<String>()
    private let time: UInt16
    private let date: UInt16

    /// `modificationDate` is written as every entry's date.
    public init(modificationDate: Date = .now) {
        let stamp = Self.dosDateTime(modificationDate)
        time = stamp.time
        date = stamp.date
    }

    public mutating func addFile(named name: String, contents: Data) throws {
        guard !name.isEmpty, !name.hasPrefix("/"), !name.contains("\\") else {
            throw ZipError.invalidEntryName(name)
        }
        guard !names.contains(name) else { throw ZipError.duplicateEntry(name) }
        let nameBytes = Data(name.utf8)
        guard nameBytes.count <= Int(UInt16.max) else { throw ZipError.invalidEntryName(name) }

        let offset = body.count
        let end = offset + ZipLayout.localHeaderSize + nameBytes.count + contents.count
        guard names.count + 1 < Int(UInt16.max), end < Int(UInt32.max) else {
            throw ZipError.archiveTooLarge
        }
        names.insert(name)
        let crc = CRC32.checksum(contents)
        let size = UInt32(contents.count)

        body.append32(ZipLayout.localHeaderSignature)
        body.append16(ZipLayout.versionNeeded)
        body.append16(ZipLayout.utf8NamesFlag)
        body.append16(ZipLayout.storedMethod)
        body.append16(time)
        body.append16(date)
        body.append32(crc)
        body.append32(size) // compressed
        body.append32(size) // uncompressed
        body.append16(UInt16(nameBytes.count))
        body.append16(0) // extra field length
        body.append(nameBytes)
        body.append(contents)

        centralDirectory.append32(ZipLayout.centralHeaderSignature)
        centralDirectory.append16(ZipLayout.versionMadeBy)
        centralDirectory.append16(ZipLayout.versionNeeded)
        centralDirectory.append16(ZipLayout.utf8NamesFlag)
        centralDirectory.append16(ZipLayout.storedMethod)
        centralDirectory.append16(time)
        centralDirectory.append16(date)
        centralDirectory.append32(crc)
        centralDirectory.append32(size)
        centralDirectory.append32(size)
        centralDirectory.append16(UInt16(nameBytes.count))
        centralDirectory.append16(0) // extra field length
        centralDirectory.append16(0) // comment length
        centralDirectory.append16(0) // disk number
        centralDirectory.append16(0) // internal attributes
        centralDirectory.append32(ZipLayout.regularFileAttributes)
        centralDirectory.append32(UInt32(offset))
        centralDirectory.append(nameBytes)
    }

    /// The finished archive.
    public func archive() throws -> Data {
        let directoryOffset = body.count
        guard directoryOffset + centralDirectory.count < Int(UInt32.max) else {
            throw ZipError.archiveTooLarge
        }
        var output = body
        output.append(centralDirectory)
        output.append32(ZipLayout.endOfCentralDirectorySignature)
        output.append16(0) // this disk
        output.append16(0) // disk with the central directory
        output.append16(UInt16(names.count))
        output.append16(UInt16(names.count))
        output.append32(UInt32(centralDirectory.count))
        output.append32(UInt32(directoryOffset))
        output.append16(0) // comment length
        return output
    }

    /// Zip stores local time in MS-DOS format, to two-second precision.
    static func dosDateTime(_ date: Date) -> (time: UInt16, date: UInt16) {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year: Int = parts.year ?? 1980
        guard year >= 1980 else { return (0, 0x21) } // 1 Jan 1980, midnight
        let hour: Int = parts.hour ?? 0
        let minute: Int = parts.minute ?? 0
        let second: Int = parts.second ?? 0
        let month: Int = parts.month ?? 1
        let day: Int = parts.day ?? 1
        let time: Int = (hour << 11) | (minute << 5) | (second / 2)
        let dayValue: Int = ((min(year, 2107) - 1980) << 9) | (month << 5) | day
        return (UInt16(truncatingIfNeeded: time), UInt16(truncatingIfNeeded: dayValue))
    }
}

// MARK: - Reader

/// Reads the files in a zip archive held in memory.
public struct ZipReader: Sendable {
    public struct Entry: Sendable, Equatable {
        public let name: String
        public let uncompressedSize: Int
        let compressedSize: Int
        let method: UInt16
        let flags: UInt16
        let crc32: UInt32
        let localHeaderOffset: Int

        public var isDirectory: Bool { name.hasSuffix("/") }
    }

    private let bytes: ByteReader
    /// Entries in the order the archive lists them.
    public let entries: [Entry]

    public init(data: Data) throws {
        let bytes = ByteReader(data)
        self.bytes = bytes
        self.entries = try Self.readCentralDirectory(bytes)
    }

    public func entry(named name: String) -> Entry? {
        entries.first { $0.name == name }
    }

    /// The contents of the file with this name, or nil if there is none.
    public func contents(named name: String) throws -> Data? {
        guard let entry = entry(named: name) else { return nil }
        return try contents(of: entry)
    }

    public func contents(of entry: Entry) throws -> Data {
        if entry.flags & 1 != 0 { throw ZipError.unsupportedFeature("encryption") }
        let signature = try bytes.uint32(at: entry.localHeaderOffset)
        guard signature == ZipLayout.localHeaderSignature else { throw ZipError.corrupt }
        let nameLength = Int(try bytes.uint16(at: entry.localHeaderOffset + 26))
        let extraLength = Int(try bytes.uint16(at: entry.localHeaderOffset + 28))
        let start = entry.localHeaderOffset + ZipLayout.localHeaderSize + nameLength + extraLength
        let stored = try bytes.slice(at: start, count: entry.compressedSize)

        let contents: Data
        switch entry.method {
        case ZipLayout.storedMethod:
            guard entry.compressedSize == entry.uncompressedSize else { throw ZipError.corrupt }
            contents = stored
        case ZipLayout.deflateMethod:
            contents = try Self.inflate(stored, expectedSize: entry.uncompressedSize)
        default:
            throw ZipError.unsupportedCompression(method: entry.method)
        }
        guard CRC32.checksum(contents) == entry.crc32 else {
            throw ZipError.checksumMismatch(entry: entry.name)
        }
        return contents
    }

    private static func readCentralDirectory(_ bytes: ByteReader) throws -> [Entry] {
        let end = try findEndOfCentralDirectory(bytes)
        let thisDisk = try bytes.uint16(at: end + 4)
        let directoryDisk = try bytes.uint16(at: end + 6)
        let count = try bytes.uint16(at: end + 10)
        let directorySize = try bytes.uint32(at: end + 12)
        let directoryOffset = try bytes.uint32(at: end + 16)
        if count == UInt16.max || directorySize == UInt32.max || directoryOffset == UInt32.max {
            throw ZipError.unsupportedFeature("Zip64")
        }
        guard thisDisk == 0, directoryDisk == 0 else {
            throw ZipError.unsupportedFeature("multiple parts")
        }

        var entries: [Entry] = []
        entries.reserveCapacity(Int(count))
        var position = Int(directoryOffset)
        for _ in 0..<count {
            guard try bytes.uint32(at: position) == ZipLayout.centralHeaderSignature else {
                throw ZipError.corrupt
            }
            let flags = try bytes.uint16(at: position + 8)
            let method = try bytes.uint16(at: position + 10)
            let crc = try bytes.uint32(at: position + 16)
            let compressedSize = try bytes.uint32(at: position + 20)
            let uncompressedSize = try bytes.uint32(at: position + 24)
            let nameLength = Int(try bytes.uint16(at: position + 28))
            let extraLength = Int(try bytes.uint16(at: position + 30))
            let commentLength = Int(try bytes.uint16(at: position + 32))
            let localHeaderOffset = try bytes.uint32(at: position + 42)
            if compressedSize == UInt32.max || uncompressedSize == UInt32.max || localHeaderOffset == UInt32.max {
                throw ZipError.unsupportedFeature("Zip64")
            }
            let nameData = try bytes.slice(at: position + ZipLayout.centralHeaderSize, count: nameLength)
            // Names are UTF-8 when flag bit 11 is set, and in practice
            // usually UTF-8 or ASCII when it isn't.
            let name = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
                ?? ""
            entries.append(Entry(
                name: name,
                uncompressedSize: Int(uncompressedSize),
                compressedSize: Int(compressedSize),
                method: method,
                flags: flags,
                crc32: crc,
                localHeaderOffset: Int(localHeaderOffset)
            ))
            position += ZipLayout.centralHeaderSize + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// The end record sits at the very end, unless the archive has a
    /// comment (at most 65,535 bytes) after it.
    private static func findEndOfCentralDirectory(_ bytes: ByteReader) throws -> Int {
        let minimumSize = 22
        guard bytes.count >= minimumSize else { throw ZipError.notAZipArchive }
        let lastStart = bytes.count - minimumSize
        let firstStart = max(0, lastStart - Int(UInt16.max))
        for start in stride(from: lastStart, through: firstStart, by: -1) {
            if try bytes.uint32(at: start) == ZipLayout.endOfCentralDirectorySignature {
                return start
            }
        }
        throw ZipError.notAZipArchive
    }

    /// Raw DEFLATE, which is what Apple's Compression calls ZLIB.
    private static func inflate(_ input: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        guard !input.isEmpty else { throw ZipError.corrupt }
        var output = Data(count: expectedSize)
        let written = output.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) -> Int in
            input.withUnsafeBytes { (source: UnsafeRawBufferPointer) -> Int in
                guard let destinationBase = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceBase = source.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destinationBase, expectedSize,
                    sourceBase, input.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        guard written == expectedSize else { throw ZipError.corrupt }
        return output
    }
}

// MARK: - Layout

private enum ZipLayout {
    static let localHeaderSignature: UInt32 = 0x0403_4B50
    static let centralHeaderSignature: UInt32 = 0x0201_4B50
    static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50
    static let localHeaderSize = 30
    static let centralHeaderSize = 46
    static let versionNeeded: UInt16 = 20
    /// Made on Unix (3), zip spec 2.0, so tools honor the file mode below.
    static let versionMadeBy: UInt16 = 3 << 8 | 20
    static let utf8NamesFlag: UInt16 = 1 << 11
    static let storedMethod: UInt16 = 0
    static let deflateMethod: UInt16 = 8
    /// A regular file, readable by everyone (0o100644 in the high 16 bits).
    static let regularFileAttributes: UInt32 = 0o100644 << 16
}

/// Bounds-checked little-endian reads, so a damaged archive throws instead
/// of crashing.
private struct ByteReader: Sendable {
    let data: Data

    init(_ data: Data) {
        self.data = data
    }

    var count: Int { data.count }

    func uint16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset <= count - 2 else { throw ZipError.corrupt }
        let index = data.startIndex + offset
        return UInt16(data[index]) | UInt16(data[index + 1]) << 8
    }

    func uint32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset <= count - 4 else { throw ZipError.corrupt }
        let index = data.startIndex + offset
        return UInt32(data[index])
            | UInt32(data[index + 1]) << 8
            | UInt32(data[index + 2]) << 16
            | UInt32(data[index + 3]) << 24
    }

    func slice(at offset: Int, count length: Int) throws -> Data {
        guard offset >= 0, length >= 0, offset <= count - length else { throw ZipError.corrupt }
        let start = data.startIndex + offset
        return data.subdata(in: start..<(start + length))
    }
}

extension Data {
    fileprivate mutating func append16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
    }

    fileprivate mutating func append32(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 24))
    }
}
