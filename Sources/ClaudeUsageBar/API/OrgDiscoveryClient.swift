import Foundation

protocol OrgDiscovering {
    func discoverOrgID(sessionCookie: String) async throws -> String
}

struct OrgDiscoveryClient: OrgDiscovering {

    let session: URLSession

    private static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    init(session: URLSession = OrgDiscoveryClient.defaultSession) {
        self.session = session
    }

    func discoverOrgID(sessionCookie: String) async throws -> String {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw PollerError.unexpectedResponse
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(
            "\(ClaudeAPIEndpoint.cookieName)=\(sessionCookie)",
            forHTTPHeaderField: "Cookie"
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw PollerError.networkError
        }

        guard let http = response as? HTTPURLResponse else {
            throw PollerError.unexpectedResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw PollerError.cookieExpired
        }
        guard http.statusCode == 200 else {
            throw PollerError.unexpectedResponse
        }

        return try parseOrgID(from: data)
    }

    private func parseOrgID(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw PollerError.parsingFailed("org response is not valid JSON")
        }

        let candidates: [[String: Any]]
        if let array = json as? [[String: Any]] {
            candidates = array
        } else if let obj = json as? [String: Any],
                  let array = obj["organizations"] as? [[String: Any]] {
            candidates = array
        } else {
            throw PollerError.parsingFailed("unexpected org response shape")
        }

        guard let first = candidates.first else {
            throw PollerError.parsingFailed("org list is empty")
        }

        for key in ["uuid", "id", "organization_id"] {
            if let value = first[key] as? String, UUID(uuidString: value) != nil {
                return value
            }
        }

        throw PollerError.parsingFailed("no UUID found in org response")
    }
}
