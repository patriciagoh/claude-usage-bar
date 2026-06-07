import Foundation

enum SetupState {
    case idle
    case connecting
    case success(percentageUsed: Double)
    case failure(String)
}

@MainActor
final class SetupViewModel {

    var selectedSource: CookieSource = .keychain
    var pastedCookie: String = ""
    private(set) var state: SetupState = .idle {
        didSet { onStateChange?(state) }
    }
    /// The org ID discovered during the last successful `connect()` call.
    private(set) var discoveredOrgID: String?

    var onStateChange: ((SetupState) -> Void)?

    var canConnect: Bool {
        switch selectedSource {
        case .keychain: return !pastedCookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .chrome, .safari: return true
        }
    }

    private let discoveryClient: OrgDiscovering
    private let apiClient: APIFetching

    init(discoveryClient: OrgDiscovering = OrgDiscoveryClient(),
         apiClient: APIFetching = ClaudeAPIClient()) {
        self.discoveryClient = discoveryClient
        self.apiClient = apiClient
    }

    func connect() async {
        state = .connecting
        var wroteToPersistentStores = false
        do {
            let cookie = try readCookie()
            // Perform all async work before writing to shared stores.
            let orgID = try await discoveryClient.discoverOrgID(sessionCookie: cookie)
            let usage = try await apiClient.fetch(sessionCookie: cookie)
            // All awaits done — write to shared stores and update state atomically
            // (no suspension points below, so no concurrent writes can interleave).
            wroteToPersistentStores = true
            discoveredOrgID = orgID
            OrgIDStore.orgID = orgID
            try KeychainManualCookieReader.save(cookie)
            CookieSourceStore.set(selectedSource)
            state = .success(percentageUsed: usage.weekly.percentageUsed)
        } catch {
            // Only invalidate the org ID if we successfully wrote it during this
            // connect() call — avoids clearing an org ID set by a prior successful
            // setup when connect() fails early (e.g. during cookie reading).
            if wroteToPersistentStores {
                OrgIDStore.invalidate()
            }
            state = .failure(message(for: error))
        }
    }

    private func readCookie() throws -> String {
        switch selectedSource {
        case .keychain:
            let v = pastedCookie.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !v.isEmpty else { throw PollerError.cookieNotFound }
            return v
        case .chrome:
            return try ChromeCookieReader().read()
        case .safari:
            return try SafariCookieReader().read()
        }
    }

    private func message(for error: Error) -> String {
        guard let pe = error as? PollerError else {
            return "Unexpected error. Please try again."
        }
        switch pe {
        case .cookieNotFound:
            return "Session cookie not found. Make sure you're logged into claude.ai."
        case .cookieExpired:
            return "Session expired. Please log into claude.ai first."
        case .networkError:
            return "Network error. Check your connection and try again."
        case .parsingFailed:
            return "Couldn't read your account data. The API may have changed."
        default:
            return "Setup failed. Please try again."
        }
    }
}
