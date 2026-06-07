import Foundation

final class UsagePoller {

    static let defaultInterval: TimeInterval = 5 * 60  // 5 minutes

    var onData: ((UsageData) -> Void)?
    var onError: ((Error) -> Void)?

    private let cookieReader: CookieReader
    private let apiClient: APIFetching
    private let orgDiscovery: OrgDiscovering
    private var timer: Timer?
    private var fetchTask: Task<Void, Never>?

    init(
        cookieReader: CookieReader = BrowserCookieReader(),
        apiClient: APIFetching = ClaudeAPIClient(),
        orgDiscovery: OrgDiscovering = OrgDiscoveryClient()
    ) {
        self.cookieReader = cookieReader
        self.apiClient = apiClient
        self.orgDiscovery = orgDiscovery
    }

    func start() {
        refreshNow()
        timer = Timer.scheduledTimer(
            withTimeInterval: Self.defaultInterval,
            repeats: true
        ) { [weak self] _ in
            self?.refreshNow()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        fetchTask?.cancel()
        fetchTask = nil
    }

    func refreshNow() {
        guard fetchTask == nil || fetchTask!.isCancelled else { return }
        fetchTask = Task { [weak self] in
            defer { self?.fetchTask = nil }
            guard let self else { return }
            do {
                let cookie = try cookieReader.read()
                if OrgIDStore.orgID == nil {
                    let id = try await orgDiscovery.discoverOrgID(sessionCookie: cookie)
                    OrgIDStore.orgID = id
                }
                let data = try await apiClient.fetch(sessionCookie: cookie)
                await MainActor.run { self.onData?(data) }
            } catch PollerError.cookieExpired {
                OrgIDStore.invalidate()
                await MainActor.run { self.onError?(PollerError.cookieExpired) }
            } catch {
                await MainActor.run { self.onError?(error) }
            }
        }
    }
}
