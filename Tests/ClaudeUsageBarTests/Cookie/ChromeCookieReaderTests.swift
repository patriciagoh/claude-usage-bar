import Foundation
import CommonCrypto
import SQLite3
import Testing
@testable import ClaudeUsageBar

// SQLITE_TRANSIENT is a C macro not importable in Swift; this is the equivalent.
private let SQLITE_TRANSIENT_SWIFT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

@Suite("ChromeCookieReader", .serialized)
struct ChromeCookieReaderTests {

    private let testKey = Data(repeating: 0x01, count: 16)
    private let testCookieValue = "test_session_token_abc123"
    private let cookieName: String = ClaudeAPIEndpoint.cookieName

    @Test func read_returnsDecryptedCookieValue() throws {
        let dbURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_cookies_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: dbURL) }
        try createFixtureDB(at: dbURL, key: testKey, cookieValue: testCookieValue)

        let reader = ChromeCookieReader(
            dbURL: dbURL,
            keyProvider: { [testKey] in testKey }
        )
        let result = try reader.read()
        #expect(result == testCookieValue)
    }

    @Test func read_throws_cookieNotFound_whenNoCookieForHost() throws {
        let otherDB = FileManager.default.temporaryDirectory
            .appendingPathComponent("other_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: otherDB) }
        try createFixtureDB(at: otherDB, key: testKey, cookieValue: "irrelevant", host: "example.com")

        let reader = ChromeCookieReader(
            dbURL: otherDB,
            keyProvider: { [testKey] in testKey }
        )
        #expect(throws: PollerError.cookieNotFound) {
            try reader.read()
        }
    }

    // MARK: - Helpers

    private func encrypt(_ value: String, key: Data) throws -> Data {
        let pt = value.data(using: .utf8)!
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        let outputCapacity = pt.count + kCCBlockSizeAES128
        var out = Data(count: outputCapacity)
        var outSize = 0
        let status: CCCryptorStatus = out.withUnsafeMutableBytes { outPtr in
            pt.withUnsafeBytes { ptPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding),
                                keyPtr.baseAddress, kCCKeySizeAES128,
                                ivPtr.baseAddress,
                                ptPtr.baseAddress, pt.count,
                                outPtr.baseAddress, outputCapacity, &outSize)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw PollerError.cookieDecryptionFailed }
        return Data([0x76, 0x31, 0x30]) + out.prefix(outSize)
    }

    private func createFixtureDB(at url: URL, key: Data, cookieValue: String, host: String = "claude.ai") throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw PollerError.cookieNotFound
        }
        defer { sqlite3_close(db) }

        sqlite3_exec(db,
            """
            CREATE TABLE cookies (
                host_key TEXT,
                name TEXT,
                encrypted_value BLOB
            );
            """,
            nil, nil, nil)

        let encrypted = try encrypt(cookieValue, key: key)
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db,
            "INSERT INTO cookies (host_key, name, encrypted_value) VALUES (?, ?, ?)",
            -1, &stmt, nil)
        sqlite3_bind_text(stmt, 1, host, -1, SQLITE_TRANSIENT_SWIFT)
        sqlite3_bind_text(stmt, 2, cookieName, -1, SQLITE_TRANSIENT_SWIFT)
        encrypted.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, 3, ptr.baseAddress, Int32(encrypted.count), SQLITE_TRANSIENT_SWIFT)
        }
        sqlite3_step(stmt)
        sqlite3_finalize(stmt)
    }
}
