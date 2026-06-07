import Foundation

struct BrowserCookieReader: CookieReader {

    private let readers: [CookieReader]

    /// Production initializer: only reads what the user explicitly stored.
    /// Browser readers (Chrome/Safari) are opt-in via the first-run setup window —
    /// they are never invoked without an explicit user action.
    init() {
        readers = [KeychainManualCookieReader()]
    }

    /// Testable initializer with injected Chrome and Safari readers.
    /// Used by tests and by the setup window after the user opts in.
    init(chrome: CookieReader, safari: CookieReader) {
        readers = [chrome, safari]
    }

    func read() throws -> String {
        for reader in readers {
            if let value = try? reader.read() { return value }
        }
        throw PollerError.cookieNotFound
    }
}
