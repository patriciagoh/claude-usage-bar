import Foundation
import Testing
@testable import ClaudeUsageBar

private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
private let fixedPeriod = UsageData.Period(percentageUsed: 0.5, resetDate: fixedDate)

private func makeData(pct: Double, fetchedAt: Date = fixedDate) -> UsageData {
    UsageData(
        session: nil,
        weekly: UsageData.Period(percentageUsed: pct, resetDate: fixedDate),
        fetchedAt: fetchedAt
    )
}

@Suite("UsageData")
struct UsageDataTests {

    @Test func isStale_falseWhenFetchedRecently() {
        let data = makeData(pct: 0.5, fetchedAt: Date())
        #expect(!data.isStale)
    }

    @Test func isStale_trueWhenFetchedOver15MinutesAgo() {
        let old = Date().addingTimeInterval(-16 * 60)
        let data = makeData(pct: 0.5, fetchedAt: old)
        #expect(data.isStale)
    }

    @Test func primary_returnsSession_whenAvailable() {
        let session = UsageData.Period(percentageUsed: 0.51, resetDate: fixedDate)
        let data = UsageData(session: session, weekly: fixedPeriod, fetchedAt: fixedDate)
        #expect(abs(data.primary.percentageUsed - 0.51) < 0.001)
    }

    @Test func primary_fallsBackToWeekly_whenNoSession() {
        let data = makeData(pct: 0.66)
        #expect(abs(data.primary.percentageUsed - 0.66) < 0.001)
    }

    @Test func equatable() {
        let a = makeData(pct: 0.5)
        let b = makeData(pct: 0.5)
        #expect(a == b)
    }
}

@Suite("PollerError")
struct PollerErrorTests {

    @Test func equality_bareCase() {
        #expect(PollerError.cookieNotFound == .cookieNotFound)
        #expect(PollerError.cookieDecryptionFailed == .cookieDecryptionFailed)
        #expect(PollerError.cookieExpired == .cookieExpired)
        #expect(PollerError.networkError == .networkError)
        #expect(PollerError.unexpectedResponse == .unexpectedResponse)
    }

    @Test func equality_parsingFailed_sameMessage() {
        #expect(PollerError.parsingFailed("bad json") == .parsingFailed("bad json"))
    }

    @Test func equality_parsingFailed_differentMessage() {
        #expect(PollerError.parsingFailed("foo") != .parsingFailed("bar"))
    }

    @Test func inequality_differentCases() {
        #expect(PollerError.cookieNotFound != .networkError)
    }
}
