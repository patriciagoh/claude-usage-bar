import Foundation

protocol APIFetching {
    func fetch(sessionCookie: String) async throws -> UsageData
}

struct ClaudeAPIClient: APIFetching {
    let session: URLSession

    // Ephemeral session: no disk cache, no shared cookie storage, no authenticated
    // response persistence. Each request is isolated.
    private static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    init(session: URLSession = ClaudeAPIClient.defaultSession) {
        self.session = session
    }

    func fetch(sessionCookie: String) async throws -> UsageData {
        guard let url = ClaudeAPIEndpoint.usageURL else {
            throw PollerError.notConfigured
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // Never log sessionCookie — treat as opaque credential
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

        return try parse(data)
    }

    // ISO8601DateFormatter is expensive to allocate; reuse across calls.
    // Configured for the format claude.ai returns: "2026-06-11T18:00:00.830299+00:00"
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func parse(_ data: Data) throws -> UsageData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PollerError.parsingFailed("response is not a JSON object")
        }

        // Weekly / seven-day window (required)
        guard let sevenDay = json["seven_day"] as? [String: Any],
              let weeklyUtil = sevenDay["utilization"] as? Double,
              let weeklyResetStr = sevenDay["resets_at"] as? String,
              let weeklyReset = Self.iso8601.date(from: weeklyResetStr)
        else {
            throw PollerError.parsingFailed("missing seven_day data")
        }

        let weekly = UsageData.Period(
            percentageUsed: min(max(weeklyUtil / 100.0, 0), 1),
            resetDate: weeklyReset
        )

        // Current-session window (optional — parse whatever field the API returns).
        var sessionPeriod: UsageData.Period?
        for key in ["session", "current_session", "five_hour", "daily"] {
            if let d = json[key] as? [String: Any],
               let util = d["utilization"] as? Double,
               let resetStr = d["resets_at"] as? String,
               let reset = Self.iso8601.date(from: resetStr) {
                sessionPeriod = UsageData.Period(
                    percentageUsed: min(max(util / 100.0, 0), 1),
                    resetDate: reset
                )
                break
            }
        }

        return UsageData(session: sessionPeriod, weekly: weekly, fetchedAt: Date())
    }
}
