import Foundation
import Security
import SQLite3

// SQLITE_TRANSIENT is a C macro (-1 cast to a function pointer) not importable in Swift.
// This reproduces the same effect: tell SQLite to copy the value immediately.
private let SQLITE_TRANSIENT_SWIFT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ChromeCookieReader: CookieReader {

    private let dbURL: URL
    private let keyProvider: () throws -> Data

    /// Production initializer for Google Chrome (Default profile).
    init() {
        self.init(
            dbPath: "Library/Application Support/Google/Chrome/Default/Cookies",
            keychainService: "Chrome Safe Storage",
            keychainAccount: "Chrome"
        )
    }

    /// Production initializer for any Chromium-based browser.
    init(dbPath: String, keychainService: String, keychainAccount: String) {
        self.dbURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(dbPath)
        let svc = keychainService
        let acct = keychainAccount
        self.keyProvider = { try ChromeCookieReader.keychainKey(service: svc, account: acct) }
    }

    /// Testable initializer — inject DB path and key provider.
    init(dbURL: URL, keyProvider: @escaping () throws -> Data) {
        self.dbURL = dbURL
        self.keyProvider = keyProvider
    }

    func read() throws -> String {
        let key = try keyProvider()

        // Copy the DB to a temp file — the browser holds a write lock while running.
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudeusagebar_cookies_\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        try FileManager.default.copyItem(at: dbURL, to: tempURL)

        let encrypted = try readEncryptedValue(from: tempURL)
        return try CookieDecryption.decrypt(encryptedValue: encrypted, key: key)
    }

    // MARK: - Private

    private func readEncryptedValue(from url: URL) throws -> Data {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw PollerError.cookieNotFound
        }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        let sql = "SELECT encrypted_value FROM cookies WHERE host_key LIKE ? AND name = ? LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw PollerError.cookieNotFound
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, "%claude.ai", -1, SQLITE_TRANSIENT_SWIFT)
        sqlite3_bind_text(stmt, 2, ClaudeAPIEndpoint.cookieName, -1, SQLITE_TRANSIENT_SWIFT)

        guard sqlite3_step(stmt) == SQLITE_ROW else {
            throw PollerError.cookieNotFound
        }

        let blobSize = sqlite3_column_bytes(stmt, 0)
        guard blobSize > 0, let blobPtr = sqlite3_column_blob(stmt, 0) else {
            throw PollerError.cookieNotFound
        }
        return Data(bytes: blobPtr, count: Int(blobSize))
    }

    private static func keychainKey(service: String, account: String) throws -> Data {
        var item: CFTypeRef?
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let passwordData = item as? Data,
              let password = String(data: passwordData, encoding: .utf8) else {
            throw PollerError.cookieDecryptionFailed
        }
        return try CookieDecryption.pbkdf2Key(password: password)
    }
}
