import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

@MainActor struct LifecycleTests {
    @Test func `returning from background refreshes loaded pages and preserves search`() async throws {
        let first = try Fixtures.users()
        let second = first.map { GitHubUser(
            id: $0.id + 30,
            login: "next\($0.id)",
            avatarURL: $0.avatarURL,
            htmlURL: $0.htmlURL
        ) }
        let mock = MockGitHubClient(pages: [.success(first), .success(second), .success(first), .success(second)])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await viewModel.retryPagination()
        viewModel.query = "mojo"
        await viewModel.refreshAfterBackground()
        #expect(viewModel.users == first + second)
        #expect(viewModel.query == "mojo")
        #expect(await mock.requests == [.users(since: 0), .users(since: 30), .users(since: 0), .users(since: 30)])
    }

    @Test func `background refresh failure keeps list`() async throws {
        let first = try Fixtures.users()
        let viewModel = UsersListViewModel(service: MockGitHubClient(pages: [.success(first), .failure(.network)]))
        await viewModel.onAppear()
        await viewModel.refreshAfterBackground()
        #expect(viewModel.users == first)
        #expect(viewModel.refreshError == .network)
    }

    @Test func `detail return from background bypasses cache`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .success(detail)])
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await viewModel.onAppear()
        await viewModel.onAppear()
        #expect(await mock.requests.count == 1)
        await viewModel.refreshAfterBackground()
        #expect(viewModel.detail == detail)
    }
}
