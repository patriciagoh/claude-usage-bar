import Testing
import Foundation
@testable import ClaudeUsageBar

private func makeData(pct: Double) -> UsageData {
    UsageData(
        session: nil,
        weekly: UsageData.Period(percentageUsed: pct, resetDate: Date()),
        fetchedAt: Date()
    )
}

@Suite("UsagePoller", .serialized, .tags(.orgIDShared))
struct UsagePollerTests {

    init() {
        // Pre-seed org ID so tests use the usage path, not discovery.
        OrgIDStore.orgID = "test-org-id"
    }

    @Test func refreshNow_callsOnData_withParsedUsage() async throws {
        let expected = makeData(pct: 0.73)
        let poller = UsagePoller(
            cookieReader: SucceedingReader(value: "cookie"),
            apiClient: SucceedingClient(data: expected),
            orgDiscovery: NoOpDiscovery()
        )

        let received: UsageData = try await withCheckedThrowingContinuation { continuation in
            poller.onData = { data in continuation.resume(returning: data) }
            poller.onError = { error in continuation.resume(throwing: error) }
            poller.refreshNow()
        }

        #expect(abs(received.weekly.percentageUsed - expected.weekly.percentageUsed) < 0.001)
    }

    @Test func refreshNow_callsOnError_whenCookieNotFound() async throws {
        let poller = UsagePoller(
            cookieReader: FailingReader(error: PollerError.cookieNotFound),
            apiClient: SucceedingClient(data: makeData(pct: 0)),
            orgDiscovery: NoOpDiscovery()
        )

        let error: Error = try await withCheckedThrowingContinuation { continuation in
            poller.onError = { error in continuation.resume(returning: error) }
            poller.onData = { _ in continuation.resume(throwing: PollerError.unexpectedResponse) }
            poller.refreshNow()
        }

        #expect(error as? PollerError == .cookieNotFound)
    }

    @Test func refreshNow_doesNotStartConcurrentFetch() async throws {
        var callCount = 0
        let slow = SlowClient {
            callCount += 1
            try await Task.sleep(nanoseconds: 100_000_000)
            return makeData(pct: 0.5)
        }
        let poller = UsagePoller(
            cookieReader: SucceedingReader(value: "c"),
            apiClient: slow,
            orgDiscovery: NoOpDiscovery()
        )

        poller.onData = { _ in }
        poller.onError = { _ in }
        poller.refreshNow()
        poller.refreshNow()  // should be dropped

        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(callCount == 1)
    }

    @Test func refreshNow_discoversOrgID_whenMissing() async throws {
        OrgIDStore.orgID = nil
        let expected = makeData(pct: 0.5)
        let discovery = SucceedingDiscovery(id: "discovered-org-id")
        let poller = UsagePoller(
            cookieReader: SucceedingReader(value: "cookie"),
            apiClient: SucceedingClient(data: expected),
            orgDiscovery: discovery
        )

        let _: UsageData = try await withCheckedThrowingContinuation { continuation in
            poller.onData = { data in continuation.resume(returning: data) }
            poller.onError = { error in continuation.resume(throwing: error) }
            poller.refreshNow()
        }

        #expect(OrgIDStore.orgID == "discovered-org-id")
    }

    @Test func refreshNow_skipsDiscovery_whenOrgIDAlreadyCached() async throws {
        OrgIDStore.orgID = "cached-id"
        var discoveryCalled = false
        let discovery = SpyDiscovery { discoveryCalled = true; return "new-id" }
        let poller = UsagePoller(
            cookieReader: SucceedingReader(value: "cookie"),
            apiClient: SucceedingClient(data: makeData(pct: 0)),
            orgDiscovery: discovery
        )

        let _: UsageData = try await withCheckedThrowingContinuation { continuation in
            poller.onData = { data in continuation.resume(returning: data) }
            poller.onError = { error in continuation.resume(throwing: error) }
            poller.refreshNow()
        }

        #expect(!discoveryCalled)
        #expect(OrgIDStore.orgID == "cached-id")
    }
}

// MARK: - Test doubles

private struct SucceedingReader: CookieReader {
    let value: String
    func read() throws -> String { value }
}

private struct FailingReader: CookieReader {
    let error: Error
    func read() throws -> String { throw error }
}

private struct SucceedingClient: APIFetching {
    let data: UsageData
    func fetch(sessionCookie: String) async throws -> UsageData { data }
}

private struct SlowClient: APIFetching {
    let block: () async throws -> UsageData
    func fetch(sessionCookie: String) async throws -> UsageData { try await block() }
}

private struct NoOpDiscovery: OrgDiscovering {
    func discoverOrgID(sessionCookie: String) async throws -> String {
        throw PollerError.unexpectedResponse
    }
}

private struct SucceedingDiscovery: OrgDiscovering {
    let id: String
    func discoverOrgID(sessionCookie: String) async throws -> String { id }
}

private struct SpyDiscovery: OrgDiscovering {
    let block: () throws -> String
    func discoverOrgID(sessionCookie: String) async throws -> String { try block() }
}
