import Foundation

enum CookieSource: String {
    case chrome, safari, keychain
}

enum CookieSourceStore {
    private static let key = "com.patriciagoh.ClaudeUsageBar.cookieSource"

    static var source: CookieSource? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return CookieSource(rawValue: raw)
    }

    static func set(_ source: CookieSource) {
        UserDefaults.standard.set(source.rawValue, forKey: key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Returns the CookieReader matching the persisted source choice.
    /// Falls back to KeychainManualCookieReader if no choice has been saved.
    static func makeCookieReader() -> CookieReader {
        switch source {
        case .chrome:   return ChromeCookieReader()
        case .safari:   return SafariCookieReader()
        case .keychain, nil: return KeychainManualCookieReader()
        }
    }
}
