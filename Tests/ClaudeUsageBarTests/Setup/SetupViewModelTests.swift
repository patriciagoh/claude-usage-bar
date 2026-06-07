import Testing
import Foundation
@testable import ClaudeUsageBar

@MainActor
@Suite("SetupViewModel", .serialized, .tags(.orgIDShared))
struct SetupViewModelTests {

    @Test func canConnect_falseWhenKeychainSourceAndEmptyPaste() {
        let vm = SetupViewModel(discoveryClient: StubDiscovery(), apiClient: StubAPI())
        vm.selectedSource = .keychain
        vm.pastedCookie = ""
        #expect(vm.canConnect == false)
    }

    @Test func canConnect_trueWhenKeychainSourceAndNonEmptyPaste() {
        let vm = SetupViewModel(discoveryClient: StubDiscovery(), apiClient: StubAPI())
        vm.selectedSource = .keychain
        vm.pastedCookie = "some-cookie"
        #expect(vm.canConnect == true)
    }

    @Test func canConnect_trueForChromeSource() {
        let vm = SetupViewModel(discoveryClient: StubDiscovery(), apiClient: StubAPI())
        vm.selectedSource = .chrome
        #expect(vm.canConnect == true)
    }

    @Test func canConnect_falseWhenKeychainSourceAndWhitespacePaste() {
        let vm = SetupViewModel(discoveryClient: StubDiscovery(), apiClient: StubAPI())
        vm.selectedSource = .keychain
        vm.pastedCookie = "   "
        #expect(vm.canConnect == false)
    }

    @Test func canConnect_trueForSafariSource() {
        let vm = SetupViewModel(discoveryClient: StubDiscovery(), apiClient: StubAPI())
        vm.selectedSource = .safari
        #expect(vm.canConnect == true)
    }

    @Test func connect_setsSuccessState_andPersistsOrgID() async throws {
        let usageData = UsageData(
            session: nil,
            weekly: .init(percentageUsed: 0.42, resetDate: Date()),
            fetchedAt: Date()
        )
        let vm = SetupViewModel(
            discoveryClient: StubDiscovery(orgID: "org-xyz"),
            apiClient: StubAPI(data: usageData)
        )
        vm.selectedSource = .keychain
        vm.pastedCookie = "valid-cookie"

        await vm.connect()

        if case .success(let pct) = vm.state {
            #expect(abs(pct - 0.42) < 0.001)
        } else {
            Issue.record("Expected success state, got \(vm.state)")
        }
        // vm.discoveredOrgID mirrors what connect() wrote to OrgIDStore.orgID —
        // it's a @MainActor property so it's safe to read without racing against
        // other suites that also write to UserDefaults concurrently.
        #expect(vm.discoveredOrgID == "org-xyz")
        #expect(CookieSourceStore.source == .keychain)
    }

    @Test func connect_setsFailureState_onDiscoveryError() async throws {
        let vm = SetupViewModel(
            discoveryClient: FailDiscovery(),
            apiClient: StubAPI(data: UsageData(
                session: nil,
                weekly: .init(percentageUsed: 0, resetDate: Date()),
                fetchedAt: Date()
            ))
        )
        vm.selectedSource = .keychain
        vm.pastedCookie = "cookie"

        await vm.connect()

        if case .failure = vm.state { /* expected */ }
        else { Issue.record("Expected failure state, got \(vm.state)") }
    }
}

// MARK: - Test doubles

private struct StubDiscovery: OrgDiscovering {
    var orgID: String = "stub-org"
    func discoverOrgID(sessionCookie: String) async throws -> String { orgID }
}

private struct FailDiscovery: OrgDiscovering {
    func discoverOrgID(sessionCookie: String) async throws -> String {
        throw PollerError.networkError
    }
}

private struct StubAPI: APIFetching {
    var data: UsageData = UsageData(
        session: nil,
        weekly: .init(percentageUsed: 0, resetDate: Date()),
        fetchedAt: Date()
    )
    func fetch(sessionCookie: String) async throws -> UsageData { data }
}
