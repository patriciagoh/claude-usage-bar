import Testing
import Foundation
@testable import ClaudeUsageBar

// Serialized at the parent level so both child suites share MockURLProtocol safely.
@Suite("API Tests", .serialized, .tags(.orgIDShared))
struct APITests {

    // MARK: - ClaudeAPIClient

    @Suite("ClaudeAPIClient")
    struct ClaudeAPIClientTests {

        init() {
            OrgIDStore.orgID = "test-org-id"
        }

        @Test("parses valid 200 response into UsageData")
        func test_fetch_parsesValidResponse() async throws {
            let json = #"{"seven_day": {"utilization": 73.0, "resets_at": "2026-06-09T09:00:00.000000+00:00"}}"#
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(json.utf8))
            }
            let result = try await makeAPIClient().fetch(sessionCookie: "test-cookie")
            #expect(abs(result.weekly.percentageUsed - 0.73) < 0.001)
            let cal = Calendar(identifier: .iso8601)
            #expect(cal.component(.year, from: result.weekly.resetDate) == 2026)
        }

        @Test("throws cookieExpired on 401")
        func test_fetch_throws_cookieExpired_on401() async throws {
            MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 401), Data()) }
            await #expect(throws: PollerError.cookieExpired) {
                try await makeAPIClient().fetch(sessionCookie: "expired-cookie")
            }
        }

        @Test("throws cookieExpired on 403")
        func test_fetch_throws_cookieExpired_on403() async throws {
            MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 403), Data()) }
            await #expect(throws: PollerError.cookieExpired) {
                try await makeAPIClient().fetch(sessionCookie: "test-cookie")
            }
        }

        @Test("throws parsingFailed on bad JSON")
        func test_fetch_throws_parsingFailed_onBadJSON() async throws {
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data("not json".utf8))
            }
            do {
                _ = try await makeAPIClient().fetch(sessionCookie: "test-cookie")
                Issue.record("Expected parsingFailed error but fetch succeeded")
            } catch PollerError.parsingFailed {
                // expected
            } catch {
                Issue.record("Expected PollerError.parsingFailed but got \(error)")
            }
        }

        @Test("throws networkError when URLSession throws")
        func test_fetch_throws_networkError_onURLError() async throws {
            MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
            await #expect(throws: PollerError.networkError) {
                try await makeAPIClient().fetch(sessionCookie: "test-cookie")
            }
        }
    }

    // MARK: - OrgDiscoveryClient

    @Suite("OrgDiscoveryClient")
    struct OrgDiscoveryClientTests {

        @Test("parses uuid field from top-level array")
        func test_discover_parsesUUIDField() async throws {
            let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(#"[{"uuid": "\#(uuid)", "name": "My Org"}]"#.utf8))
            }
            let id = try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            #expect(id == uuid)
        }

        @Test("parses id field when uuid absent")
        func test_discover_parsesIDField() async throws {
            let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(#"[{"id": "\#(uuid)", "name": "My Org"}]"#.utf8))
            }
            let id = try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            #expect(id == uuid)
        }

        @Test("parses from organizations wrapper object")
        func test_discover_parsesWrappedObject() async throws {
            let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(#"{"organizations": [{"uuid": "\#(uuid)"}]}"#.utf8))
            }
            let id = try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            #expect(id == uuid)
        }

        @Test("skips non-UUID strings and finds real UUID")
        func test_discover_skipsNonUUIDStrings() async throws {
            let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(#"[{"id": "not-a-uuid", "uuid": "\#(uuid)"}]"#.utf8))
            }
            let id = try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            #expect(id == uuid)
        }

        @Test("throws cookieExpired on 401")
        func test_discover_throws_cookieExpired_on401() async throws {
            MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 401), Data()) }
            await #expect(throws: PollerError.cookieExpired) {
                try await makeDiscoveryClient().discoverOrgID(sessionCookie: "bad")
            }
        }

        @Test("throws cookieExpired on 403")
        func test_discover_throws_cookieExpired_on403() async throws {
            MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 403), Data()) }
            await #expect(throws: PollerError.cookieExpired) {
                try await makeDiscoveryClient().discoverOrgID(sessionCookie: "bad")
            }
        }

        @Test("throws unexpectedResponse on non-200 status")
        func test_discover_throws_unexpectedResponse_on500() async throws {
            MockURLProtocol.requestHandler = { _ in (makeResponse(statusCode: 500), Data()) }
            await #expect(throws: PollerError.unexpectedResponse) {
                try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            }
        }

        @Test("throws parsingFailed when no UUID found in response")
        func test_discover_throws_parsingFailed_whenNoUUID() async throws {
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data(#"[{"name": "Org", "slug": "my-org"}]"#.utf8))
            }
            await #expect(throws: PollerError.self) {
                try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            }
        }

        @Test("throws parsingFailed on empty array")
        func test_discover_throws_parsingFailed_onEmptyArray() async throws {
            MockURLProtocol.requestHandler = { _ in
                (makeResponse(statusCode: 200), Data("[]".utf8))
            }
            await #expect(throws: PollerError.self) {
                try await makeDiscoveryClient().discoverOrgID(sessionCookie: "cookie")
            }
        }

        @Test("sends session cookie in request header")
        func test_discover_sendsCookieHeader() async throws {
            var capturedRequest: URLRequest?
            MockURLProtocol.requestHandler = { req in
                capturedRequest = req
                let uuid = "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
                return (makeResponse(statusCode: 200), Data(#"[{"uuid": "\#(uuid)"}]"#.utf8))
            }
            _ = try await makeDiscoveryClient().discoverOrgID(sessionCookie: "my-cookie")
            #expect(capturedRequest?.value(forHTTPHeaderField: "Cookie") == "sessionKey=my-cookie")
        }
    }
}

// MARK: - Shared helpers

private func makeAPIClient() -> ClaudeAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return ClaudeAPIClient(session: URLSession(configuration: config))
}

private func makeDiscoveryClient() -> OrgDiscoveryClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return OrgDiscoveryClient(session: URLSession(configuration: config))
}

private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://claude.ai")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}
