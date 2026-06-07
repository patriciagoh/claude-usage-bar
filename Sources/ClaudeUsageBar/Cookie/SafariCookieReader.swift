import Foundation

struct SafariCookieReader: CookieReader {

    private let fileURL: URL

    init() {
        self.fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Cookies/Cookies.binarycookies")
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func read() throws -> String {
        let data = try Data(contentsOf: fileURL)
        return try parse(data)
    }

    private func parse(_ data: Data) throws -> String {
        guard data.count > 8,
              Array(data.prefix(4)) == [0x63, 0x6F, 0x6F, 0x6B] else {
            throw PollerError.unexpectedResponse
        }

        var cursor = DataCursor(data: data, offset: 4)
        let pageCount = Int(cursor.readBE32())
        var pageSizes: [Int] = []
        for _ in 0..<pageCount { pageSizes.append(Int(cursor.readBE32())) }

        for pageSize in pageSizes {
            let pageStart = cursor.offset
            cursor.offset += pageSize
            guard pageStart + pageSize <= data.count, pageSize > 8 else { continue }
            guard Array(data[pageStart..<(pageStart + 4)]) == [0x00, 0x00, 0x01, 0x00] else { continue }

            var pc = DataCursor(data: data, offset: pageStart + 4)
            let cookieCount = Int(pc.readLE32())
            var cookieOffsets: [Int] = []
            for _ in 0..<cookieCount { cookieOffsets.append(pageStart + Int(pc.readLE32())) }

            for cookieStart in cookieOffsets {
                guard cookieStart + 48 <= data.count else { continue }
                var cc = DataCursor(data: data, offset: cookieStart)
                _ = cc.readLE32(); _ = cc.readLE32(); _ = cc.readLE32(); _ = cc.readLE32()
                let domainOff = cookieStart + Int(cc.readLE32())
                let nameOff   = cookieStart + Int(cc.readLE32())
                _ = cc.readLE32()
                let valueOff  = cookieStart + Int(cc.readLE32())

                func cstring(at i: Int) -> String? {
                    guard i < data.count else { return nil }
                    let slice = data[i...]
                    if let end = slice.firstIndex(of: 0) {
                        return String(data: data[i..<end], encoding: .utf8)
                    }
                    return String(data: slice, encoding: .utf8)
                }

                guard let domain = cstring(at: domainOff),
                      let name   = cstring(at: nameOff),
                      let value  = cstring(at: valueOff) else { continue }

                if domain.hasSuffix("claude.ai") && name == ClaudeAPIEndpoint.cookieName {
                    return value
                }
            }
        }
        throw PollerError.cookieNotFound
    }
}

private struct DataCursor {
    let data: Data
    var offset: Int

    mutating func readBE32() -> UInt32 {
        defer { offset += 4 }
        return UInt32(data[offset]) << 24 | UInt32(data[offset+1]) << 16
             | UInt32(data[offset+2]) << 8  | UInt32(data[offset+3])
    }

    mutating func readLE32() -> UInt32 {
        defer { offset += 4 }
        return UInt32(data[offset]) | UInt32(data[offset+1]) << 8
             | UInt32(data[offset+2]) << 16 | UInt32(data[offset+3]) << 24
    }
}
