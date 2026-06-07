import Foundation

struct UsageData: Equatable {
    struct Period: Equatable {
        let percentageUsed: Double   // 0.0–1.0
        let resetDate: Date
    }

    let session: Period?   // current-session window; nil if API doesn't return it
    let weekly: Period     // seven-day rolling window
    let fetchedAt: Date

    /// The period shown in the menu-bar title: session if available, else weekly.
    var primary: Period { session ?? weekly }

    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 15 * 60
    }
}

enum PollerError: Error, Equatable {
    case cookieNotFound
    case cookieDecryptionFailed
    case cookieExpired
    case networkError
    case unexpectedResponse
    case notConfigured       // org ID not yet discovered
    case parsingFailed(String)

    static func == (lhs: PollerError, rhs: PollerError) -> Bool {
        switch (lhs, rhs) {
        case (.cookieNotFound, .cookieNotFound),
             (.cookieDecryptionFailed, .cookieDecryptionFailed),
             (.cookieExpired, .cookieExpired),
             (.networkError, .networkError),
             (.unexpectedResponse, .unexpectedResponse),
             (.notConfigured, .notConfigured):
            return true
        case (.parsingFailed(let a), .parsingFailed(let b)):
            return a == b
        default:
            return false
        }
    }
}
