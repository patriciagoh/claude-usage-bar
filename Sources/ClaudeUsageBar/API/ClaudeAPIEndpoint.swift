import Foundation

enum ClaudeAPIEndpoint {
    static let cookieName = "sessionKey"

    // Built from the org ID discovered at runtime. Returns nil until org ID is known.
    // Note: this uses an unofficial, undocumented claude.ai endpoint that may change without notice.
    static var usageURL: URL? {
        guard let id = OrgIDStore.orgID else { return nil }
        return URL(string: "https://claude.ai/api/organizations/\(id)/usage")
    }
}
