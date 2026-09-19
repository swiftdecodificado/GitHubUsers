import Foundation
import GitHubAPI
@testable import GitHubUsers
import Testing

@MainActor struct RefreshRegressionTests {
    @Test func `detail refresh failure keeps fields and retry recovers`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .failure(.network), .success(detail)])
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await viewModel.onAppear()
        let rows = viewModel.infoRows
        let stats = viewModel.stats
        await viewModel.refreshAfterBackground()
        #expect(viewModel.state == .loaded(detail))
        #expect(viewModel.refreshError == .network)
        #expect(viewModel.infoRows == rows)
        #expect(viewModel.stats == stats)
        #expect(!viewModel.isLoadingFields)
        await viewModel.retry()
        #expect(viewModel.state == .loaded(detail))
        #expect(viewModel.refreshError == nil)
        #expect(await mock.requests.count == 3)
    }

    @Test func `loaded detail respects rate limit on every refresh entry point`() async throws {
        let detail = try Fixtures.detail()
        let error = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(details: [.success(detail), .failure(error)])
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await viewModel.onAppear()
        await viewModel.refreshAfterBackground()
        await viewModel.retry()
        await viewModel.refreshAfterBackground()
        #expect(viewModel.detail == detail)
        #expect(viewModel.refreshError == error)
        #expect(await mock.requests.count == 2)
    }

    @Test func `detail can retry after rate limit deadline`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [
            .success(detail),
            .failure(.rateLimited(resetAt: .distantPast)),
            .success(detail)
        ])
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await viewModel.onAppear()
        await viewModel.refreshAfterBackground()
        await viewModel.retry()
        #expect(viewModel.refreshError == nil)
        #expect(viewModel.detail == detail)
        #expect(await mock.requests.count == 3)
    }

    @Test func `cancelled refresh preserves detail and previous warning`() async throws {
        let detail = try Fixtures.detail()
        let mock = MockGitHubClient(details: [.success(detail), .failure(.network), .success(detail), .success(detail)])
        let viewModel = try UserDetailViewModel(user: Fixtures.users()[0], service: mock)
        await viewModel.onAppear()
        await viewModel.refreshAfterBackground()
        await mock.suspend()
        let task = Task { await viewModel.retry() }
        while await mock.requests.count < 3 {
            await Task.yield()
        }
        // Calls while a fetch is running cannot start competing requests.
        await viewModel.refreshAfterBackground()
        #expect(await mock.requests.count == 3)
        task.cancel()
        await mock.resume()
        await task.value
        #expect(viewModel.detail == detail)
        #expect(viewModel.refreshError == .network)
        await viewModel.retry()
        #expect(viewModel.refreshError == nil)
        #expect(await mock.requests.count == 4)
    }

    @Test func `list refresh rate limit cannot be bypassed by gestures or pagination`() async throws {
        let users = try Fixtures.users()
        let limit = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(pages: [.success(users), .failure(limit)])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await viewModel.refresh()
        await viewModel.refresh()
        await viewModel.refreshAfterBackground()
        await viewModel.retryPagination()
        #expect(await mock.requests.count == 2)
        #expect(viewModel.users == users)
        #expect(viewModel.refreshError == limit)
    }

    @Test func `pagination rate limit also blocks refresh`() async throws {
        let users = try Fixtures.users()
        let limit = GitHubAPIError.rateLimited(resetAt: .now.addingTimeInterval(300))
        let mock = MockGitHubClient(pages: [.success(users), .failure(limit)])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        await viewModel.retryPagination()
        await viewModel.refresh()
        await viewModel.refreshAfterBackground()
        #expect(await mock.requests.count == 2)
        #expect(viewModel.paginationError == limit)
    }

    @Test func `search suspends pagination until cleared`() async throws {
        let users = try Fixtures.users()
        let mock = MockGitHubClient(pages: [.success(users), .success([])])
        let viewModel = UsersListViewModel(service: mock)
        await viewModel.onAppear()
        viewModel.query = "mojo"
        await viewModel.retryPagination()
        #expect(await mock.requests.count == 1)
        viewModel.query = ""
        await viewModel.retryPagination()
        #expect(await mock.requests.count == 2)
        #expect(!viewModel.hasMore)
    }
}
