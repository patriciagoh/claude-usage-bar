import Foundation
import Testing
@testable import ClaudeUsageBar

@Suite("SafariCookieReader")
struct SafariCookieReaderTests {

    private let cookieName: String = ClaudeAPIEndpoint.cookieName
    private let testValue = "safari_session_token_xyz"

    @Test func read_returnsValueFromFixtureBinaryFile() throws {
        let data = try buildBinaryCookies(domain: "claude.ai", name: cookieName, value: testValue)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).binarycookies")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try data.write(to: fileURL)

        let reader = SafariCookieReader(fileURL: fileURL)
        let result = try reader.read()
        #expect(result == testValue)
    }

    @Test func read_throws_cookieNotFound_whenNoCookieForDomain() throws {
        let data = try buildBinaryCookies(domain: "example.com", name: cookieName, value: "irrelevant")
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).binarycookies")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try data.write(to: fileURL)

        let reader = SafariCookieReader(fileURL: fileURL)
        #expect(throws: PollerError.cookieNotFound) {
            try reader.read()
        }
    }

    // MARK: - Fixture builder
    // Builds a minimal valid .binarycookies file: one page, one cookie.
    //
    // File layout:  "cook"(4,magic) + pageCount(4,BE) + pageSize(4,BE) + page + endMarker(4)
    // Page layout:  pageMagic(4) + cookieCount(4,LE) + cookieOffset(4,LE) + cookie
    // Cookie layout (all LE unless noted):
    //   recordSize(4) + unk(4) + flags(4) + unk(4)
    //   + domainOff(4) + nameOff(4) + pathOff(4) + valueOff(4)
    //   + commentOff(4) + commentURLOff(4)
    //   + expires(8,f64) + creation(8,f64)
    //   + domain\0 + name\0 + path\0 + value\0
    // String offsets are relative to the start of the cookie record.
    private func buildBinaryCookies(domain: String, name: String, value: String) throws -> Data {
        let fixedHeader = 56  // 4*4 + 6*4 + 2*8

        let domainData = (domain + "\0").data(using: .utf8)!
        let nameData   = (name   + "\0").data(using: .utf8)!
        let pathData   = ("/"    + "\0").data(using: .utf8)!
        let valueData  = (value  + "\0").data(using: .utf8)!

        let domainOff = UInt32(fixedHeader)
        let nameOff   = domainOff + UInt32(domainData.count)
        let pathOff   = nameOff   + UInt32(nameData.count)
        let valueOff  = pathOff   + UInt32(pathData.count)
        let recordSize = valueOff + UInt32(valueData.count)

        var cookie = Data()
        func leU32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { cookie.append(contentsOf: $0) } }
        func leF64(_ v: Double) { withUnsafeBytes(of: v.bitPattern.littleEndian) { cookie.append(contentsOf: $0) } }
        leU32(recordSize); leU32(0); leU32(0); leU32(0)
        leU32(domainOff); leU32(nameOff); leU32(pathOff); leU32(valueOff)
        leU32(0); leU32(0)       // commentOff, commentURLOff
        leF64(700_000_000.0)     // expires
        leF64(680_000_000.0)     // creation
        cookie.append(contentsOf: domainData + nameData + pathData + valueData)

        // Page: pageMagic(4) + cookieCount(4,LE) + cookieOffset(4,LE) + cookie
        // cookie starts at byte 12 from page start (4+4+4)
        var page = Data([0x00, 0x00, 0x01, 0x00])
        func leU32p(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { page.append(contentsOf: $0) } }
        leU32p(1); leU32p(12)
        page.append(cookie)

        var result = Data([0x63, 0x6F, 0x6F, 0x6B])  // "cook"
        func beU32(_ v: UInt32) { withUnsafeBytes(of: v.bigEndian) { result.append(contentsOf: $0) } }
        beU32(1); beU32(UInt32(page.count))
        result.append(page)
        result.append(contentsOf: [0x07, 0x17, 0x20, 0x05])
        return result
    }
}
