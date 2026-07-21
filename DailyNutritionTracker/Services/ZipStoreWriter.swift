import Foundation

/// Minimal ZIP writer using STORE (no compression). Enough for OOXML `.xlsx` packages.
enum ZipStoreWriter {
    static func write(entries: [(path: String, data: Data)], to url: URL) throws {
        var localParts = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0

        for entry in entries {
            let nameData = Data(entry.path.utf8)
            let crc = crc32(entry.data)
            let size = UInt32(entry.data.count)

            var local = Data()
            local.appendUInt32(0x04034b50) // local file header signature
            local.appendUInt16(20) // version needed to extract
            local.appendUInt16(0) // general purpose bit flag
            local.appendUInt16(0) // compression method = STORE
            local.appendUInt16(0) // last mod file time
            local.appendUInt16(0) // last mod file date
            local.appendUInt32(crc)
            local.appendUInt32(size) // compressed size
            local.appendUInt32(size) // uncompressed size
            local.appendUInt16(UInt16(nameData.count))
            local.appendUInt16(0) // extra field length
            local.append(nameData)
            local.append(entry.data)

            let localOffset = offset
            localParts.append(local)
            offset += UInt32(local.count)

            var central = Data()
            central.appendUInt32(0x02014b50) // central file header signature
            central.appendUInt16(20) // version made by
            central.appendUInt16(20) // version needed
            central.appendUInt16(0) // flags
            central.appendUInt16(0) // method STORE
            central.appendUInt16(0) // time
            central.appendUInt16(0) // date
            central.appendUInt32(crc)
            central.appendUInt32(size)
            central.appendUInt32(size)
            central.appendUInt16(UInt16(nameData.count))
            central.appendUInt16(0) // extra
            central.appendUInt16(0) // comment
            central.appendUInt16(0) // disk number start
            central.appendUInt16(0) // internal file attributes
            central.appendUInt32(0) // external file attributes
            central.appendUInt32(localOffset)
            central.append(nameData)
            centralDirectory.append(central)
        }

        let centralOffset = offset
        let centralSize = UInt32(centralDirectory.count)

        var end = Data()
        end.appendUInt32(0x06054b50) // end of central directory signature
        end.appendUInt16(0) // number of this disk
        end.appendUInt16(0) // disk where central directory starts
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt16(UInt16(entries.count))
        end.appendUInt32(centralSize)
        end.appendUInt32(centralOffset)
        end.appendUInt16(0) // comment length

        var archive = Data()
        archive.reserveCapacity(localParts.count + centralDirectory.count + end.count)
        archive.append(localParts)
        archive.append(centralDirectory)
        archive.append(end)
        try archive.write(to: url, options: .atomic)
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ crcTable[index]
        }
        return crc ^ 0xffff_ffff
    }

    private static let crcTable: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                if c & 1 != 0 {
                    c = 0xedb8_8320 ^ (c >> 1)
                } else {
                    c >>= 1
                }
            }
            return c
        }
    }()
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }

    mutating func appendUInt32(_ value: UInt32) {
        var little = value.littleEndian
        Swift.withUnsafeBytes(of: &little) { append(contentsOf: $0) }
    }
}
