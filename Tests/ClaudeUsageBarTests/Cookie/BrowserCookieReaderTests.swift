import Testing
@testable import ClaudeUsageBar

@Suite("BrowserCookieReader")
struct BrowserCookieReaderTests {

    @Test func read_returnsChromeResultWhenChromeSucceeds() throws {
        let reader = BrowserCookieReader(
            chrome: SucceedingReader(value: "from_chrome"),
            safari: SucceedingReader(value: "from_safari")
        )
        #expect(try reader.read() == "from_chrome")
    }

    @Test func read_fallsBackToSafariWhenChromeFails() throws {
        let reader = BrowserCookieReader(
            chrome: FailingReader(),
            safari: SucceedingReader(value: "from_safari")
        )
        #expect(try reader.read() == "from_safari")
    }

    @Test func read_throws_cookieNotFound_whenBothFail() throws {
        let reader = BrowserCookieReader(
            chrome: FailingReader(),
            safari: FailingReader()
        )
        #expect(throws: PollerError.cookieNotFound) {
            try reader.read()
        }
    }
}

private struct SucceedingReader: CookieReader {
    let value: String
    func read() throws -> String { value }
}

private struct FailingReader: CookieReader {
    func read() throws -> String { throw PollerError.cookieNotFound }
}
